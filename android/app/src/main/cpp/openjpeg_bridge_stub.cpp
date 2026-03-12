#include <jni.h>

extern "C"
JNIEXPORT jobject JNICALL
Java_com_takakotlin_usb_OpenJpegBridge_decode(JNIEnv* env, jclass, jbyteArray) {
    jclass cls = env->FindClass("com/takakotlin/usb/DecodeResult");
    jmethodID ctor = env->GetMethodID(cls, "<init>", "()V");
    jobject out = env->NewObject(cls, ctor);

    jfieldID fError = env->GetFieldID(cls, "error", "Ljava/lang/String;");
    env->SetObjectField(out, fError, env->NewStringUTF("OpenJPEG not available in this build"));

    return out;
}
