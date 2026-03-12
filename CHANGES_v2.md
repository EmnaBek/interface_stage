# Latest Changes - Image Reading Fix v2

## What Was Updated

Your `MainActivity.kt` now has **two-level image extraction**:

### Level 1: TLV Parsing (for wrapped ICAO data)

If the device sends TLV-wrapped image data:

```
[0x7F61 wrapper]
  └── [0x5F2E BDB]
      └── [JPEG data]
```

The code will unwrap and extract just the JPEG.

### Level 2: Fallback (if TLV fails)

If TLV parsing returns null BUT you have face data:

- Try saving the raw data directly
- This handles cases where device sends raw JPEG instead of TLV-wrapped

## New Fallback Logic

```kotlin
val extractedImageBytes = decodeFaceImage(faceData)
if (extractedImageBytes != null) {
    faceImageUri = writeFaceToFile(extractedImageBytes)
} else {
    // Fallback: decodeFaceImage failed, try raw data
    faceImageUri = writeFaceToFile(faceData)
}
```

## How to Test

### Quick Test:

```bash
RUN_LOGCAT.bat
```

This script:

1. Shows device status
2. Clears old logs
3. Starts live log monitoring
4. You click READ CARD
5. Script shows the results

### Manual Test:

```bash
adb logcat -c
adb logcat -s TAKA_USB:V
# Then click READ CARD and watch the logs
```

## What You Should See (If Working)

```
D/TAKA_USB: Total face bytes received: 14320
D/TAKA_USB: Calling decodeFaceImage with 14320 bytes...
D/TAKA_USB: === decodeFaceImage START ===
D/TAKA_USB: [1] TLV tag: 0x7F61 len=14310
D/TAKA_USB: ✓ Found 0x7F61 (DG2 - Face Image)
D/TAKA_USB: Extracted image from TLV: 14200 bytes
D/TAKA_USB: writeFaceToFile returned: '/data/data/com.example.interface_stage/cache/face_1708698000000.jpg'
D/TAKA_USB: >>> writeFaceToFile: SUCCESS (JPEG) <<<
```

## What If You Don't See Image

### No face bytes (faceReceived=0)

- Device isn't sending image data
- Check: USB connection, card insertion, power

### TLV parsing fails (no 0x7F61)

- Device sends raw image
- Should see: "Fallback succeeded: saved raw data"

### File created but not displayed

- File was saved but Flutter can't access it
- Try: Clear app data → Settings → Apps → interface_stage → Storage → Clear Cache
- Restart app

### File not created at all

- Check: Storage space, file permissions
- Look for: "writeFaceToFile: SUCCESS" or "ERROR" messages

## Files Modified

- `/android/app/src/main/kotlin/com/example/interface_stage/MainActivity.kt`
  - Modified `readCard` method to add fallback
  - `decodeFaceImage()` already present with TLV parsing
  - `writeFaceToFile()` already present with verification

## Quick Recap

| What              | Where           | How                          |
| ----------------- | --------------- | ---------------------------- |
| **Installed APK** | Device          | flutter build & install      |
| **TLV Parser**    | MainActivity.kt | decodeFaceImage() method     |
| **Fallback**      | MainActivity.kt | Try raw data if TLV fails    |
| **File Saving**   | MainActivity.kt | writeFaceToFile() method     |
| **Testing**       | Console         | RUN_LOGCAT.bat or adb logcat |

## Next Step

Run `RUN_LOGCAT.bat` and read a card, then share what you see in the logs.
