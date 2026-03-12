# DEBUG GUIDE - Image Not Showing Issue

## What Was Fixed

Your `MainActivity.kt` now includes **ICAO DG2 TLV parsing** which unwraps the image data that comes wrapped in encryption/structure layers from the USB device.

The issue was: Device sends `[TLV wrapper [JPEG data]]` but the app was trying to save the wrapper instead of extracting the JPEG.

## Quick Test Steps

### Step 1: Rebuild the App

```bash
flutter clean
flutter pub get
flutter run
```

### Step 2: Capture Logs During Card Read

Open a separate Command Prompt window and run:

```bash
adb logcat -s TAKA_USB:V
```

Then in your app, click **READ CARD**.

### Step 3: Review the Logs

Look for these messages (they indicate success):

```
D/TAKA_USB: read face chunk: 4096 bytes, total=12000
D/TAKA_USB: Total face bytes received: 12000
D/TAKA_USB: =================================== decodeFaceImage START ===
D/TAKA_USB: [1] TLV tag: 0x7F61 len=11990 @ offset=2
D/TAKA_USB: ✓ Found 0x7F61 (DG2 - Face Image) len=11990
D/TAKA_USB: ✓ Found BDB @ offset=..., len=11980
D/TAKA_USB: JPEG search: FOUND @ 250
D/TAKA_USB: ✓ SUCCESS - Extracted JPEG image
D/TAKA_USB: >>> writeFaceToFile: SUCCESS (JPEG) <<<
```

## If You Still Don't See the Image

### Scenario A: "Total face bytes received: 0"

**Problem**: Device is not sending face image data

**Solutions**:

1. Check that the USB card reader is properly connected to both:
   - The Android device (USB OTG adapter)
   - The actual ID card being inserted correctly
2. Try waiting longer before tapping READ CARD
3. Verify the card reader lights/indicators show it's active

### Scenario B: "DG2 (0x7F61) not found"

**Problem**: Data format is different than expected

**Solutions**:

1. Check the log line: `Input: XXXX bytes, first32: XX XX XX ...`
2. If it starts with `FF D8` → Device sends bare JPEG (that's fine, code handles it)
3. If it starts with something else → Device format might be different
4. Note the hex values and share them for diagnosis

### Scenario C: "BDB (0x5F2E) not found"

**Problem**: TLV structure is malformed

**Solutions**:

1. Check `Found 0x7F61` - if this appears, DG2 was found but BDB wasn't inside
2. The device might be using a different DG (Data Group)
3. May need to adjust the search parameters

### Scenario D: File created but image not displayed in app

**Problem**: File write succeeded but Flutter can't access it

**Solutions**:

1. Check Flutter console for errors about file access
2. The printout should show the file path - verify it exists:
   ```bash
   adb shell ls -la /cache
   ```
3. If file exists but app can't read it, it's a permission issue:
   - Clear app cache: Go to Settings → Apps → interface_stage → Storage → Clear Cache
   - Restart the app

## Manual Verification

To verify the file was created:

```bash
adb shell ls -la /data/data/com.example.interface_stage/cache/
```

You should see files like: `face_1708700000000.jpg`

To pull the image to your PC:

```bash
adb shell ls -la /data/data/com.example.interface_stage/cache/face_*.jpg
REM Note the exact filepath, then:
adb pull "/data/data/com.example.interface_stage/cache/face_XXXXX.jpg" C:\Temp\face.jpg
```

Then open `C:\Temp\face.jpg` to verify it's a valid image.

## Key Log Patterns to Look For

| Pattern                    | Meaning                             |
| -------------------------- | ----------------------------------- |
| `decodeFaceImage START`    | TLV parsing has started             |
| `[N] TLV tag: 0xXXXX`      | Found a TLV structure with this tag |
| `✓ Found 0x7F61`           | DG2 (Face) data group was found ✓   |
| `✓ Found BDB`              | Biometric Data Block extracted ✓    |
| `JPEG search: FOUND`       | Image signature found inside BDB ✓  |
| `✓ SUCCESS - Extracted`    | Image extracted and returned ✓      |
| `writeFaceToFile: SUCCESS` | Image file written to disk ✓        |
| `File exists: true`        | File can be accessed ✓              |
| `✗ DG2 not found`          | 0x7F61 tag not in data ✗            |
| `✗ BDB not found`          | 0x5F2E tag not in DG2 ✗             |
| `No image signature`       | No JPEG/JP2/J2K marker in BDB ✗     |

## Expected Flow

```
Card inserted
↓
READ CARD clicked
↓
USB communication: Send request (0x00, 0x01) for image
↓
Device responds with TLV-wrapped DG2 data
↓
decodeFaceImage() parses TLV
↓
Extracts JPEG bytes from inside BDB
↓
writeFaceToFile() saves to cache directory
↓
Flutter loads file from cache path
↓
Image displays in Widget
```

## Emergency Log Capture

If you want to save the entire log to a file for analysis:

```bash
adb logcat > c:\Temp\full_logs.txt
REM Read card now, wait 30 seconds
REM Press Ctrl+C to stop
```

Then share the logs file to diagnose the exact issue.

## Contact Info for Additional Help

When reporting issues, include:

1. The exact error message from logs (copy-paste the ✗ lines)
2. The `first32:` bytes from `decodeFaceImage START`
3. What the TLV tag names are (0xXXXX values shown in logs)
4. Whether face bytes are being received (0 or > 0)
