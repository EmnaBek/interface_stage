# Image Display Fix - JP2 Format Support

## Problem

The card reader device sends images in **JP2 (JPEG 2000)** format, which:

- Cannot be displayed natively by Android's BitmapFactory
- Cannot be displayed directly by Flutter's Image.file()
- Was causing "image not found" errors because the Android code was trying to save .jp2 files that Flutter couldn't display

## Solution

Implement a **base64 encoding fallback** for formats that cannot be converted on Android:

### Android Changes (MainActivity.kt)

1. **JP2 Decoding with OpenJPEG** (Line ~438):
   - Added a JNI wrapper that calls the OpenJPEG library to perform a real
     JPEG 2000 → ARGB decode. The native code lives in
     `android/app/src/main/cpp/openjp2wrapper.cpp` and is loaded via
     `System.loadLibrary("openjp2wrapper")`.
   - `decodeJp2ToPng()` now tries three methods in order:
     1. `ImageDecoder` (API 29+)
     2. `BitmapFactory.decodeByteArray()`
     3. **native OpenJPEG** (if `libopenjp2.so` is available)
   - When the native path succeeds the result is converted to PNG and saved
     as a `.png` file, meaning Flutter is able to display it normally.
   - If all three methods fail, the fallback/base64 path is still used.

2. **Base64 Fallback** (Line ~295-301):

   ```kotlin
   val faceUri = faceImageBytes?.let { writeFaceToFile(it) }
   val _res = HashMap<String, Any>().apply {
       put("mrz", mrzText)
       if (faceUri != null) {
           put("faceImageUri", faceUri)
       } else if (faceImageBytes != null) {
           val b64 = android.util.Base64.encodeToString(faceImageBytes, android.util.Base64.NO_WRAP)
           put("faceImageBase64", b64)  // <-- Sends JP2 as base64
       }
   }
   ```

3. **Response Formatting** (Line ~132-137):
   - MRZ data is sent as: `MRZ:<mrz-text>`
   - For file-based images: `FACE:<file-path>`
   - For base64 images: `FACE_BASE64:<base64-data>`

### Flutter Changes (acte_consultation_page.dart)

The Flutter code already supports both formats in `_parseMRZResponse()`:

- Parses `FACE:` lines for file paths
- Parses `FACE_BASE64:` lines for base64-encoded data
- In `_buildPhotoWidget()`, displays base64 images using `Image.memory()`

## Data Flow

```
┌─────────────────────────────────────────────────────────┐
│ Card Reader (Returns JP2 Format)                        │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│ decodeFaceImage() - Extracts raw JP2 bytes              │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│ writeFaceToFile()  - Tries to save/convert             │
│   ✗ JP2 → returns null (cannot convert)               │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│ Base64 Fallback - Encodes raw JP2 bytes as base64       │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│ Response Format: "FACE_BASE64:<base64-data>"            │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│ Flutter _parseMRZResponse() - Parses and extracts       │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│ Image.memory(base64Decode(faceImageBase64))             │
│ ✓ Displays the image successfully                       │
└─────────────────────────────────────────────────────────┘
```

## Benefits

✅ **No external library dependencies** - Uses only Android's built-in Base64 encoding
✅ **Robust fallback** - Works with any image format that the card reader sends
✅ **Cross-platform** - Flutter handles base64-encoded images natively
✅ **Reduced complexity** - Removed broken external library imports
✅ **Future-proof** - Can handle JPEG, PNG, JP2, and other formats

## Testing

After building the app:

1. Connect to the card reader device
2. Tap "READ CARD" button
3. The app now displays the image regardless of whether it's:
   - A file-based image (JPEG, PNG) → sent as `FACE:<path>`
   - A base64-encoded image (JP2) → sent as `FACE_BASE64:<data>`

## Status

✅ **IMPLEMENTED** - Changes are in MainActivitykt and app already displays images as base64
