#include <jni.h>
#include <android/log.h>
#include <vector>
#include <cstring>
#include "openjpeg.h"

#define LOG_TAG "TAKA_USB_NDK"
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)
#define LOGD(...) __android_log_print(ANDROID_LOG_DEBUG, LOG_TAG, __VA_ARGS__)

// ---- Event handlers to see OpenJPEG messages in logcat ----
static void opj_error_callback(const char* msg, void*)   { LOGE("opj_error: %s",   msg ? msg : "(null)"); }
static void opj_warn_callback(const char* msg, void*)    { LOGD("opj_warn: %s",    msg ? msg : "(null)"); }
static void opj_info_callback(const char* msg, void*)    { LOGD("opj_info: %s",    msg ? msg : "(null)"); }

// ---- Memory stream for OpenJPEG (read-only) ----
typedef struct {
    const uint8_t* data;
    size_t size;
    size_t offset;
} mem_stream_t;

static OPJ_SIZE_T mem_read(void* p_buffer, OPJ_SIZE_T p_nb_bytes, void* p_user_data) {
    mem_stream_t* ms = (mem_stream_t*)p_user_data;
    const size_t remain = (ms->offset >= ms->size) ? 0 : (ms->size - ms->offset);
    OPJ_SIZE_T to_read = (p_nb_bytes > remain) ? (OPJ_SIZE_T)remain : p_nb_bytes;
    if (to_read > 0) {
        memcpy(p_buffer, ms->data + ms->offset, (size_t)to_read);
        ms->offset += (size_t)to_read;
    }
    return to_read;
}
static OPJ_OFF_T mem_skip(OPJ_OFF_T nb, void* p_user_data) {
    mem_stream_t* ms = (mem_stream_t*)p_user_data;
    // clamp
    long long want = (long long)ms->offset + (long long)nb;
    if (want < 0) want = 0;
    if ((size_t)want > ms->size) want = (long long)ms->size;
    size_t delta = (size_t)want - ms->offset;
    ms->offset = (size_t)want;
    return (OPJ_OFF_T)delta;
}
static OPJ_BOOL mem_seek(OPJ_OFF_T off, void* p_user_data) {
    mem_stream_t* ms = (mem_stream_t*)p_user_data;
    if (off < 0 || (size_t)off > ms->size) return OPJ_FALSE;
    ms->offset = (size_t)off;
    return OPJ_TRUE;
}
static void mem_free(void* p_user_data) {
    (void)p_user_data;
}

static opj_stream_t* create_memory_stream(mem_stream_t* ms) {
    opj_stream_t* stream = opj_stream_default_create(OPJ_TRUE /* is_read_stream */);
    if (!stream) return nullptr;

    // IMPORTANT: set user data + length first
    opj_stream_set_user_data(stream, ms, mem_free);
    opj_stream_set_user_data_length(stream, (OPJ_SIZE_T)ms->size);

    // Set callbacks
    opj_stream_set_read_function(stream, mem_read);
    opj_stream_set_skip_function(stream, mem_skip);
    opj_stream_set_seek_function(stream, mem_seek);

    // Reasonable internal read size (avoid pathological behavior)
    // opj_stream_set_default_read_size(stream, 4096);

    return stream;
}

// Small helpers to detect container
static bool looks_like_jp2(const uint8_t* p, size_t n) {
    if (n < 12) return false;
    // 00 00 00 0C 6A 50 20 20
    return p[4]==0x6A && p[5]==0x50 && p[6]==0x20 && p[7]==0x20;
}
static bool looks_like_j2k(const uint8_t* p, size_t n) {
    return n >= 2 && p[0]==0xFF && p[1]==0x4F;
}

extern "C"
JNIEXPORT jobject JNICALL
Java_com_takakotlin_usb_OpenJpegBridge_decode(JNIEnv* env, jclass, jbyteArray jdata) {
    LOGD("JNI decode: start");
    // Prepare DecodeResult object
    jclass cls = env->FindClass("com/takakotlin/usb/DecodeResult");
    jmethodID ctor = env->GetMethodID(cls, "<init>", "()V");
    jobject out = env->NewObject(cls, ctor);

    jfieldID f_width  = env->GetFieldID(cls, "width",  "I");
    jfieldID f_height = env->GetFieldID(cls, "height", "I");
    jfieldID f_rgba   = env->GetFieldID(cls, "rgba",   "[B");
    jfieldID f_error  = env->GetFieldID(cls, "error",  "Ljava/lang/String;");

    // Copy input
    jsize len = env->GetArrayLength(jdata);
    std::vector<uint8_t> buf((size_t)len);
    env->GetByteArrayRegion(jdata, 0, len, reinterpret_cast<jbyte*>(buf.data()));
    LOGD("JNI decode: input size=%d", (int)buf.size());

    // Decide codec
    opj_codec_t* codec = nullptr;
    if (looks_like_jp2(buf.data(), buf.size())) {
        LOGD("JNI decode: format=JP2");
        codec = opj_create_decompress(OPJ_CODEC_JP2);
    } else if (looks_like_j2k(buf.data(), buf.size())) {
        LOGD("JNI decode: format=J2K");
        codec = opj_create_decompress(OPJ_CODEC_J2K);
    } else {
        LOGE("JNI decode: Unsupported format");
        env->SetObjectField(out, f_error, env->NewStringUTF("Unsupported format (not JP2/J2K)"));
        return out;
    }

    // Hook up event manager
    opj_set_error_handler  (codec, opj_error_callback,  nullptr);
    opj_set_warning_handler(codec, opj_warn_callback,   nullptr);
    opj_set_info_handler   (codec, opj_info_callback,   nullptr);

    opj_dparameters_t params;
    opj_set_default_decoder_parameters(&params);
    LOGD("JNI decode: setup decoder");
    if (!opj_setup_decoder(codec, &params)) {
        LOGE("JNI decode: opj_setup_decoder failed");
        env->SetObjectField(out, f_error, env->NewStringUTF("opj_setup_decoder failed"));
        opj_destroy_codec(codec);
        return out;
    }

    mem_stream_t ms{ buf.data(), buf.size(), 0 };
    LOGD("JNI decode: create stream");
    opj_stream_t* stream = create_memory_stream(&ms);
    if (!stream) {
        LOGE("JNI decode: create_memory_stream failed");
        env->SetObjectField(out, f_error, env->NewStringUTF("create_memory_stream failed"));
        opj_destroy_codec(codec);
        return out;
    }

    LOGD("JNI decode: read header");
    opj_image_t* image = nullptr;
    if (!opj_read_header(stream, codec, &image)) {
        LOGE("JNI decode: opj_read_header failed");
        env->SetObjectField(out, f_error, env->NewStringUTF("opj_read_header failed"));
        opj_stream_destroy(stream);
        opj_destroy_codec(codec);
        return out;
    }

    if (!opj_set_decode_area(codec, image, image->x0, image->y0, image->x1, image->y1)) {
        LOGE("JNI decode: opj_set_decode_area failed");
        env->SetObjectField(out, f_error, env->NewStringUTF("opj_set_decode_area failed"));
        opj_image_destroy(image); opj_stream_destroy(stream); opj_destroy_codec(codec);
        return out;
    }

    LOGD("JNI decode: decode");
    if (!opj_decode(codec, stream, image)) {
        LOGE("JNI decode: opj_decode failed");
        env->SetObjectField(out, f_error, env->NewStringUTF("opj_decode failed"));
        opj_image_destroy(image);
        opj_stream_destroy(stream);
        opj_destroy_codec(codec);
        return out;
    }

    // LOGD("JNI decode: end decompress");
    // if (!opj_end_decompress(codec, stream)) {
    //     LOGD("JNI decode: opj_end_decompress returned false (continuing)");
    // }

    int w = (int)(image->x1 - image->x0);
    int h = (int)(image->y1 - image->y0);
    LOGD("JNI decode: got image w=%d h=%d comps=%d", w, h, (int)image->numcomps);

    if (w <= 0 || h <= 0 || image->numcomps < 1) {
        LOGE("JNI decode: invalid image");
        env->SetObjectField(out, f_error, env->NewStringUTF("Invalid decoded image"));
        opj_image_destroy(image);
        opj_stream_destroy(stream);
        opj_destroy_codec(codec);
        return out;
    }
    LOGD("JNI decode: decode OK");

    // ---- NEW: safe interleave with subsampling handling ----
    auto to8 = [](int v, int prec)->uint8_t {
        if (prec <= 8) {
            int shift = 8 - prec;
            int s = (prec == 0) ? 0 : (v << shift);
            if (s < 0) s = 0; if (s > 255) s = 255;
            return (uint8_t)s;
        } else {
            int shift = prec - 8;
            int s = v >> shift;
            if (s < 0) s = 0; if (s > 255) s = 255;
            return (uint8_t)s;
        }
    };

    std::vector<uint8_t> rgba((size_t)w * (size_t)h * 4);

    // Grayscale expand if needed
    if (image->numcomps == 1) {
        const opj_image_comp_t& Y = image->comps[0];
        if (Y.w <= 0 || Y.h <= 0 || Y.dx <= 0 || Y.dy <= 0) {
            env->SetObjectField(out, f_error, env->NewStringUTF("Invalid component geometry (Y)"));
            opj_image_destroy(image); opj_stream_destroy(stream); opj_destroy_codec(codec);
            return out;
        }

        LOGD("JNI decode: compY w=%d h=%d dx=%d dy=%d", (int)Y.w, (int)Y.h, (int)Y.dx, (int)Y.dy);
        LOGD("JNI decode: interleave RGBA (grayscale)");

        for (int y = 0; y < h; ++y) {
            int yy = y / (int)Y.dy; if (yy >= (int)Y.h) yy = (int)Y.h - 1;
            for (int x = 0; x < w; ++x) {
                int xx = x / (int)Y.dx; if (xx >= (int)Y.w) xx = (int)Y.w - 1;
                int yi = yy * (int)Y.w + xx;

                uint8_t L = to8(Y.data[yi], Y.prec);
                size_t o = ((size_t)y * (size_t)w + (size_t)x) * 4;
                rgba[o + 0] = L; rgba[o + 1] = L; rgba[o + 2] = L; rgba[o + 3] = 255;
            }
        }
    } else {
        // Assume RGB (+ optional A). Components may be subsampled, so map with dx/dy.
        const opj_image_comp_t& rC = image->comps[0];
        const opj_image_comp_t& gC = image->comps[1];
        const opj_image_comp_t& bC = image->comps[2];
        bool hasA = image->numcomps >= 4;
        const opj_image_comp_t* aC = hasA ? &image->comps[3] : nullptr;

        auto okComp = [](const opj_image_comp_t& c){ return c.w > 0 && c.h > 0 && c.dx > 0 && c.dy > 0; };
        if (!okComp(rC) || !okComp(gC) || !okComp(bC) || (hasA && !okComp(*aC))) {
            env->SetObjectField(out, f_error, env->NewStringUTF("Invalid component geometry (RGB/A)"));
            opj_image_destroy(image); opj_stream_destroy(stream); opj_destroy_codec(codec);
            return out;
        }

        LOGD("JNI decode: comp0 w=%d h=%d dx=%d dy=%d, comp1 w=%d h=%d dx=%d dy=%d, comp2 w=%d h=%d dx=%d dy=%d",
            (int)rC.w, (int)rC.h, (int)rC.dx, (int)rC.dy,
            (int)gC.w, (int)gC.h, (int)gC.dx, (int)gC.dy,
            (int)bC.w, (int)bC.h, (int)bC.dx, (int)bC.dy);
        if (hasA) {
            LOGD("JNI decode: comp3 w=%d h=%d dx=%d dy=%d",
                (int)aC->w, (int)aC->h, (int)aC->dx, (int)aC->dy);
        }

        LOGD("JNI decode: interleave RGBA (RGB/A)");
        for (int y = 0; y < h; ++y) {
            int ry = y / (int)rC.dy; if (ry >= (int)rC.h) ry = (int)rC.h - 1;
            int gy = y / (int)gC.dy; if (gy >= (int)gC.h) gy = (int)gC.h - 1;
            int by = y / (int)bC.dy; if (by >= (int)bC.h) by = (int)bC.h - 1;
            int ay = 0;
            if (hasA) { ay = y / (int)aC->dy; if (ay >= (int)aC->h) ay = (int)aC->h - 1; }

            for (int x = 0; x < w; ++x) {
                int rx = x / (int)rC.dx; if (rx >= (int)rC.w) rx = (int)rC.w - 1;
                int gx = x / (int)gC.dx; if (gx >= (int)gC.w) gx = (int)gC.w - 1;
                int bx = x / (int)bC.dx; if (bx >= (int)bC.w) bx = (int)bC.w - 1;
                int ax = 0;
                if (hasA) { ax = x / (int)aC->dx; if (ax >= (int)aC->w) ax = (int)aC->w - 1; }

                int ri = ry * (int)rC.w + rx;
                int gi = gy * (int)gC.w + gx;
                int bi = by * (int)bC.w + bx;
                int ai = hasA ? (ay * (int)aC->w + ax) : 0;

                uint8_t R = to8(rC.data[ri], rC.prec);
                uint8_t G = to8(gC.data[gi], gC.prec);
                uint8_t B = to8(bC.data[bi], bC.prec);
                uint8_t A = hasA ? to8(aC->data[ai], aC->prec) : 255;

                size_t o = ((size_t)y * (size_t)w + (size_t)x) * 4;
                rgba[o + 0] = R; rgba[o + 1] = G; rgba[o + 2] = B; rgba[o + 3] = A;
            }
        }
    }
    // ---- END NEW ----

    LOGD("JNI decode: fill result object");
    env->SetIntField(out, f_width,  w);
    env->SetIntField(out, f_height, h);

    jbyteArray jrgba = env->NewByteArray((jsize)rgba.size());
    env->SetByteArrayRegion(jrgba, 0, (jsize)rgba.size(), reinterpret_cast<const jbyte*>(rgba.data()));
    env->SetObjectField(out, f_rgba, jrgba);

    opj_image_destroy(image);
    opj_stream_destroy(stream);
    opj_destroy_codec(codec);

    LOGD("JNI decode: done");
    return out;
}
