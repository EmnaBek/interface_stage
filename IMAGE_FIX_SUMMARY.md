# Image Reading Fix - Summary

## Problem

The application was not displaying the image while reading ID cards through the USB card reader.

## Root Causes Identified

1. **Missing TLV Parsing**: Image data is wrapped in ICAO DG2 TLV (Tag-Length-Value) structures that need to be unwrapped
2. **No BDB Extraction**: The Biometric Data Block (BDB) containing the actual image wasn't being extracted from the TLV wrapper
3. **Silent Failures**: The `writeFaceToFile()` function could fail without proper error reporting
4. **Insufficient Logging**: Insufficient diagnostic information to track where images were being lost
5. **Missing Length Forms**: TLV parser didn't support 0x83/0x84 length forms used for larger structures

## Changes Made

### 1. **Android (MainActivity.kt) - TLV Parsing for ICAO DG2**

**New Method**: `decodeFaceImage()` and TLV utilities

**What it does**:

- Unwraps ICAO DG2 TLV structures (tag 0x7F61)
- Finds and extracts Biometric Data Block (tag 0x5F2E)
- Searches for actual image signature (JPEG/JP2/J2K) inside the BDB
- Returns the extracted raw image bytes

```kotlin
// The image is structured as:
Data Group 2 (0x7F61)
  └── Biometric Data Block (0x5F2E)
      └── Actual Image (JPEG/JP2/J2K)

// This method unwraps all three layers to get the raw image
```

### 2. **Android (MainActivity.kt) - Enhanced TLV Parser**

**New Classes**: `TlvCursor`, `Tlv`, `Slice`

**Features**:

- Supports BER-TLV parsing with 1, 2, 3, and 4-byte tags (0x7F, 0x5F formats)
- Supports length forms 0x81, 0x82, 0x83, 0x84 (up to 4-byte lengths)
- Recursive searching for nested tags
- Extensive logging of all parsing steps

### 3. **Android (MainActivity.kt) - Updated readCard Flow**

**Before**:

```kotlin
val faceData = faceBaos.toByteArray()
faceImageUri = writeFaceToFile(faceData)  // Raw data, still wrapped in TLV
```

**After**:

```kotlin
val faceData = faceBaos.toByteArray()
val extractedImageBytes = decodeFaceImage(faceData)  // Unwrap TLV first!
if (extractedImageBytes != null) {
    faceImageUri = writeFaceToFile(extractedImageBytes)
}
```

### 4. **Android (MainActivity.kt) - File Validation & Logging**

**Location**: `writeFaceToFile()` method

**Changes**:

- Added cache directory permission checks
- File verification after writing (existence + size match + readability)
- Returns null if verification fails (prevents invalid paths)
- Comprehensive logging of all file operations

## How the Image Data is Structured

The device sends data like this:

```
[TLV 0x7F61]*           <- Data Group 2 (Face Image DG)
  ├─ TLV header (tag, length)
  └─ [TLV 0x5F2E]*     ← Biometric Data Block
      ├─ TLV header (tag, length)
      ├─ [FF D8 ...]   ← JPEG data starts here
      ├─ ... JPEG content ...
      └─ [D9]          ← JPEG data ends here
```

**Before fix**: App tried to save the entire TLV-wrapped data as JPEG (would fail)
**After fix**: App extracts just the JPEG part and saves it correctly

## Diagnostic Information Now Available

The enhanced logging will show:

### Face Data Reception:

```
Total face bytes received: 15243
Face data first 16 bytes: 7F 61 82 3B 8D ...
Face image format check: isJpeg=false, isPng=false, isValid=false
```

### TLV Parsing:

```
=== decodeFaceImage START ===
Input: 15243 bytes
[1] TLV tag: 0x7F61 len=15237 @ offset=2
✓ Found 0x7F61 (DG2 - Face Image) len=15237
[2] Inner TLV tag: 0x5F2E len=15230
✓ Found BDB @ offset=..., len=15230
```

### Image Extraction:

```
Searching for image signatures in BDB...
  JPEG search: FOUND @ 250
✓ SUCCESS - Extracted JPEG image
  Image size: 14987 bytes
```

## How to Debug

Run this command while reading a card:

```bash
adb logcat -s TAKA_USB:V
```

Look for these key indicators:

✓ **Success indicators**:

- "Found 0x7F61 (DG2 - Face Image)"
- "Found BDB @ offset"
- "Extracted JPEG/JP2/J2K image"
- "writeFaceToFile: SUCCESS"

✗ **Failure indicators**:

- "Total face bytes received: 0" → Device not sending image
- "7F61 not found" → Wrong data format
- "BDB (0x5F2E) not found" → Corrupted TLV
- "No image signature found" → Image data is corrupted

## What if it still doesn't work?

### 1. No face bytes received (faceReceived=0)

- Check that USB card reader is communicating properly
- Verify the card is being read (wait for longer timeout)

### 2. TLV parsing fails (0x7F61 not found)

- The device might be sending a different format
- Check if data starts with TLV marker or bare JPEG
- May need to adjust device communication protocol

### 3. Image file not created

- Check app permissions for file write
- Ensure device has sufficient storage
- Check logs for "writeFaceToFile" errors

### 4. Image file exists but not displayed

- Check Flutter logs for file access errors
- Verify the file path is being passed correctly to Flutter
- Check if Image.file() can read from cache directory

## Files Modified

- `/android/app/src/main/kotlin/com/example/interface_stage/MainActivity.kt`
  - Added `decodeFaceImage()` method
  - Added TLV parsing utilities (TlvCursor, Tlv, Slice)
  - Updated readCard face image handling
  - Enhanced file validation and logging

### 3. **Android (MainActivity.kt) - writeFaceToFile() Improvements**

**Location**: Line ~383-454

**Enhancements**:

- Added cache directory write permission checks
- Proper file verification after writing:
  - Confirms file exists
  - Confirms file size matches input
  - Confirms file is readable
- Better error messages with cache dir info
- Returns null if verification fails (prevents returning invalid paths)

```kotlin
// Now verifies:
- Cache directory exists and is writable
- File exists after write operation
- File size equals the bytes written
- File is readable by the app
- Detailed logging of all verification steps
```

### 4. **Flutter (acte_consultation_page.dart) - File Access Improvements**

**Location**: Line ~280

**Changes**:

- Created `_checkFileExists()` helper method with proper async handling
- Added detailed logging of:
  - File existence check results
  - File size for verified files
  - Exceptions during file access
- Cleaner error handling and reporting

```dart
// New helper method:
Future<bool> _checkFileExists(String filePath) async {
  try {
    final file = File(filePath);
    bool exists = await file.exists();
    if (exists) {
      final fileSize = await file.length();
      debugPrint('File size: $fileSize bytes');
    }
    return exists;
  } catch (e) {
    debugPrint('Error checking file existence: $e');
    return false;
  }
}
```

## Diagnostic Information Provided

The enhanced logging will now show:

1. **USB Device Communication**:
   - Face image bytes received
   - Image format detected (JPEG/PNG)
   - Whether transmission completed

2. **File Operations**:
   - Cache directory path and permissions
   - File creation success/failure
   - File size verification
   - Read/write permissions

3. **Flutter Side**:
   - File existence confirmation
   - File size information
   - Specific exceptions during access

## How to Debug the Image Issue

1. **Run the app in debug mode**
2. **Read a card** and check the console logs for:
   - Look for "Total face bytes received: X" - if 0, the device isn't sending image data
   - Look for "Face image format check" - confirms image format detection
   - Look for ">>> writeFaceToFile" logs - shows file writing details
   - Look for "File check" in Flutter logs - confirms Flutter can access the file

## Expected Log Output When Working

```
D/TAKA_USB: read face chunk: 4096 bytes, total=4096
D/TAKA_USB: Face data first 16 bytes: FF D8 FF E0...
D/TAKA_USB: Face image format check: isJpeg=true, isPng=false, isValid=true
D/TAKA_USB: >>> writeFaceToFile: START <<<
D/TAKA_USB:   ✓ JPEG detected
D/TAKA_USB:   File exists: true
D/TAKA_USB:   File size: 4096 bytes (expected: 4096)
D/TAKA_USB: >>> writeFaceToFile: SUCCESS (JPEG) <<<
```

## Next Steps If Image Still Missing

1. **Check logs for "Total face bytes received: 0"** - indicates device isn't sending image
   - Verify card reader is working properly
   - Check USB connection

2. **Check for "writeToFile" errors** - indicates file system issues
   - Verify app has WRITE_EXTERNAL_STORAGE permission (if targeting older Android)
   - Check device storage space

3. **Check Flutter logs for "File exists: false"** - indicates path issue
   - Verify the returned path is correct
   - Check file permissions

## Files Modified

- `/android/app/src/main/kotlin/com/example/interface_stage/MainActivity.kt`
- `/lib/features/caisse/acte_consultation_page.dart`
