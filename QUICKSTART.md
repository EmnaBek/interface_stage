# Quick Start - Testing the Image Fix

## TL;DR - Just Do This

### 1. Clean and rebuild (run from project root)

```bash
flutter clean
flutter pub get
flutter run
```

### 2. While app runs, open a separate terminal and run

```bash
adb logcat -s TAKA_USB:V
```

### 3. In the app, click "READ CARD"

### 4. Look in the terminal for these SUCCESS messages:

- `✓ Found 0x7F61 (DG2 - Face Image)`
- `✓ Found BDB`
- `✓ SUCCESS - Extracted JPEG image`
- `writeFaceToFile: SUCCESS`

If you see all 4 ✓ messages → **Image handling is working!**

---

## What Changed?

Your app now **unwraps ICAO card data**:

- Before: Tried to display wrapped TLV data (failed ✗)
- After: Extracts actual JPEG from inside TLV wrapper (works ✓)

---

## Why Image Still Might Not Show

1. **Device not sending image** → `Total face bytes received: 0`
   - Check USB card reader is connected
   - Try inserting card again

2. **Image format different** → `DG2 (0x7F61) not found`
   - Device might use bare JPEG (code handles this)
   - Or different structure (would need new code)

3. **Image file created but Flutter can't read it** → File exists but UI blank
   - Try: Settings → Apps → interface_stage → Storage → Clear Cache
   - Restart app

---

## Debug More Deeply

See `DEBUG_GUIDE.md` in this folder for detailed troubleshooting.

---

## Files Changed

Only modified: `/android/app/src/main/kotlin/com/example/interface_stage/MainActivity.kt`

- Added TLV parsing methods
- Added image extraction logic
- Enhanced logging throughout
