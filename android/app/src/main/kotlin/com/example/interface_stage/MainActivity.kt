package com.example.interface_stage

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.*
import android.os.Build
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlin.concurrent.thread
import java.io.ByteArrayOutputStream
import com.example.interface_stage.usb.*
import com.takakotlin.usb.OpenJpegBridge

class MainActivity: FlutterActivity() {    companion object {
        init {
            // Prefer the CMake-built bridge when available; fall back to prebuilt wrapper.
            try {
                System.loadLibrary("openjpeg_bridge")
            } catch (_: UnsatisfiedLinkError) {
                System.loadLibrary("openjp2wrapper")
            }
        }
    }
    private val CHANNEL = "taka_usb"
    private val ACTION_USB_PERMISSION = "com.example.interface_stage.USB_PERMISSION"
    private val TAG = "TAKA_USB"

    private var usbManager: UsbManager? = null
    private var device: UsbDevice? = null
    private var connection: UsbDeviceConnection? = null
    @Volatile private var permissionGranted = false

    private var permissionIntent: PendingIntent? = null

    // Named BroadcastReceiver
    private val usbReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            Log.d("TAKA_USB", "usbReceiver onReceive, action=${intent?.action} extras=${intent?.extras}")
            if (intent?.action == ACTION_USB_PERMISSION) {
                val dev: UsbDevice? = intent.getParcelableExtra(UsbManager.EXTRA_DEVICE)
                permissionGranted = intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false)
                Log.d("TAKA_USB", "raw permissionExtra=${intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false)}")
                if (permissionGranted) {
                    Log.d("TAKA_USB", "Permission granted for device ${dev?.deviceName}")
                    connection = usbManager!!.openDevice(dev)
                } else {
                    Log.d("TAKA_USB", "Permission denied for device ${dev?.deviceName}")
                }
                Log.d("TAKA_USB", "usbManager.hasPermission? ${usbManager?.hasPermission(dev)}")
            }
        }
    }

    // Decode MRZ: strip leading garbage bytes, keep only valid MRZ characters.
    // Valid MRZ chars: A-Z, 0-9, '<', and a few special chars defined by ICAO 9303.
    private fun decodeMRZ(data: ByteArray): String = try {
        val raw = String(data, Charsets.UTF_8).substringBefore('\u0000')
        // Find the first position that looks like the start of a valid MRZ field.
        // MRZ lines consist exclusively of A-Z, 0-9 and '<'.
        // We look for the first run of valid chars long enough to be MRZ (>=5).
        val mrzRegex = Regex("[A-Z0-9<]{5,}")
        val match = mrzRegex.find(raw)
        if (match != null) {
            // Return from that match start to end of string, keeping only valid MRZ chars
            raw.substring(match.range.first)
                .filter { it in 'A'..'Z' || it in '0'..'9' || it == '<' || it == ' ' || it == '\n' }
                .trim()
        } else {
            raw.trim()
        }
    } catch (_: Exception) {
        ""
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        usbManager = getSystemService(Context.USB_SERVICE) as UsbManager

        val piFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            PendingIntent.FLAG_IMMUTABLE
        } else {
            0
        }
        permissionIntent = PendingIntent.getBroadcast(
            this,
            0,
            Intent(ACTION_USB_PERMISSION),
            piFlags
        )

        val filter = IntentFilter(ACTION_USB_PERMISSION)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(usbReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(usbReceiver, filter)
        }

        // --- debug: attempt to decode a hard‑coded JP2 blob using the new native path ---
        // replace the base64 string with a real JP2 sample to verify that openjpeg is hooked up
        val sampleBase64 = "<PUT_REAL_JP2_BASE64_HERE>"
        try {
            if (sampleBase64.isNotEmpty()) {
                val sampleBytes = android.util.Base64.decode(sampleBase64, android.util.Base64.DEFAULT)
                val png = decodeJp2ToPng(sampleBytes)
                if (png != null) {
                    val outFile = java.io.File(cacheDir, "sample.png")
                    outFile.outputStream().use { it.write(png) }
                    Log.d(TAG, "sample JP2 decoded -> ${outFile.absolutePath}")
                } else {
                    Log.w(TAG, "sample JP2 decode returned null")
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "error decoding sample JP2", e)
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->

                when (call.method) {

                    "connect" -> {
                        val deviceList = usbManager!!.deviceList
                        if (deviceList.isEmpty()) {
                            Log.d("TAKA_USB", "connect: no USB devices")
                            result.success(false)
                            return@setMethodCallHandler
                        }

                        // log all devices for debugging
                        for ((key, dev) in deviceList) {
                            Log.d("TAKA_USB", "found device key=$key name=${dev.deviceName} vendor=${dev.vendorId} prod=${dev.productId} class=${dev.deviceClass}")
                        }

                        // try to pick device with a bulk IN/OUT endpoint if possible
                        device = deviceList.values.firstOrNull { dev ->
                            var hasBulk = false
                            for (i in 0 until dev.interfaceCount) {
                                val intf = dev.getInterface(i)
                                for (j in 0 until intf.endpointCount) {
                                    val ep = intf.getEndpoint(j)
                                    if (ep.type == UsbConstants.USB_ENDPOINT_XFER_BULK) {
                                        hasBulk = true
                                    }
                                }
                            }
                            hasBulk
                        } ?: deviceList.values.first()

                        Log.d("TAKA_USB", "selected device ${device?.deviceName} vendor=${device?.vendorId} prod=${device?.productId}")
                        permissionGranted = false

                        usbManager!!.requestPermission(device, permissionIntent)
                        Log.d("TAKA_USB", "requested permission; hasPermission=${usbManager!!.hasPermission(device)}")
                        result.success(true)
                    }

                    "readCard" -> thread {
                        try {
                            val res = scanDevice(this@MainActivity)
                            if (res == null) {
                                result.success("ERROR: scanDevice returned null")
                            } else {
                                val mrz = res["mrz"] as? String ?: ""
                                val face = res["faceImageUri"] as? String
                                val faceBase64 = res["faceImageBase64"] as? String
                                val sb = StringBuilder()
                                sb.append("MRZ:$mrz\n")
                                if (!face.isNullOrEmpty()) {
                                    sb.append("FACE:$face\n")
                                }
                                if (!faceBase64.isNullOrEmpty()) {
                                    sb.append("FACE_BASE64:$faceBase64\n")
                                }
                                result.success(sb.toString())
                            }
                        } catch (t: Throwable) {
                            Log.e(TAG, "readCard: scanDevice threw", t)
                            result.success("ERROR: exception during scanDevice: ${t.message}")
                        }
                    }

                    "disconnect" -> {
                        connection?.close()
                        connection = null
                        permissionGranted = false
                        result.success(true)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun scanDevice(context: Context): Map<String, Any>? {
        val usbManager = context.getSystemService(Context.USB_SERVICE) as UsbManager

        // 0) Sanity: does this phone support USB host?
        val pm = context.packageManager
        if (!pm.hasSystemFeature(android.content.pm.PackageManager.FEATURE_USB_HOST)) {
            Log.e(TAG, "USB host not supported on this device")
            return null
        }

        // 1) List everything we see
        if (usbManager.deviceList.isEmpty()) {
            Log.e(TAG, "No USB devices detected. Check OTG adapter/cable and power.")
            return null
        }
        for ((_, d) in usbManager.deviceList) {
            Log.d(
                TAG,
                "Found USB device: name=${d.deviceName}, manufacturer=${d.manufacturerName}, " +
                        "product=${d.productName}, vendorId=0x${String.format("%04X", d.vendorId)}, " +
                        "productId=0x${String.format("%04X", d.productId)}"
            )
        }

        // 2) Try to find by VENDOR_ID first; fallback to first device
        val target: UsbDevice? =
            usbManager.deviceList.values.find { it.vendorId == VENDOR_ID }
                ?: usbManager.deviceList.values.firstOrNull()

        if (target == null) {
            Log.e(TAG, "Device not found (after scanning list)")
            return null
        }

        // 3) Permission flow
        if (!usbManager.hasPermission(target)) {
            val action = "com.example.interface_stage.USB_PERMISSION"
            val pi = PendingIntent.getBroadcast(
                context, 0, Intent(action),
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) PendingIntent.FLAG_IMMUTABLE else 0
            )
            runCatching { usbManager.requestPermission(target, pi) }
            Log.e(TAG, "Requested USB permission; ask the user to tap Read again after granting.")
            return null
        }

        // 4) Open and locate endpoints
        val connection = usbManager.openDevice(target) ?: run {
            Log.e(TAG, "Unable to open device")
            return null
        }

        var epIn: UsbEndpoint? = null
        var epOut: UsbEndpoint? = null
        var claimedInterface: UsbInterface? = null

        try {
            fun scanInterface(intf: UsbInterface): Boolean {
                var foundIn: UsbEndpoint? = null
                var foundOut: UsbEndpoint? = null
                for (i in 0 until intf.endpointCount) {
                    val ep = intf.getEndpoint(i)
                    val addr = ep.address and 0xFF
                    if (ep.direction == UsbConstants.USB_DIR_IN && addr == EP_IN_ADDRESS) foundIn = ep
                    if (ep.direction == UsbConstants.USB_DIR_OUT && addr == EP_OUT_ADDRESS) foundOut = ep
                }
                if (foundIn != null && foundOut != null) {
                    if (connection.claimInterface(intf, true)) {
                        epIn = foundIn
                        epOut = foundOut
                        claimedInterface = intf
                        return true
                    }
                }
                return false
            }

            run {
                for (i in 0 until target.interfaceCount) {
                    if (scanInterface(target.getInterface(i))) break
                }
            }

            if (epIn == null || epOut == null || claimedInterface == null) {
                Log.e(
                    TAG,
                    "Endpoints not found (expected IN=0x${String.format("%02X", EP_IN_ADDRESS)} " +
                            "OUT=0x${String.format("%02X", EP_OUT_ADDRESS)}). Check your endpoint addresses."
                )
                return null
            }

            // 5) Exchange data
            val mrzResponse = try {
                sendIcaoCommand(connection, epIn!!, epOut!!, 0)
            } catch (t: Throwable) {
                Log.w(TAG, "sendIcaoCommand(0) failed: ${t.message}")
                ByteArray(0)
            }

            val faceResponse = try {
                sendIcaoCommand(connection, epIn!!, epOut!!, 1)
            } catch (t: Throwable) {
                Log.w(TAG, "sendIcaoCommand(1) failed: ${t.message}")
                ByteArray(0)
            }

            val mrzText = decodeMRZ(mrzResponse)
            if (mrzText.isBlank()) {
                Log.w(TAG, "scanDevice: MRZ appears empty — proceeding to extract face image anyway")
            }

            val parsed = try {
                parseData(mrzText)
            } catch (t: Throwable) {
                Log.w(TAG, "parseData failed on MRZ: ${t.message}")
                emptyMap<String, Any?>()
            }

            Log.d(TAG, "scanDevice: faceResponse size=${faceResponse.size}")
            
            val faceImageBytes = decodeFaceImage(faceResponse)
            
            Log.d(TAG, "scanDevice: after decodeFaceImage, faceImageBytes=${faceImageBytes?.size ?: "null"}")

            val previewLen = minOf(128, faceResponse.size)
            val sb = StringBuilder(previewLen * 3)
            for (i in 0 until previewLen) {
                sb.append(String.format("%02X ", faceResponse[i]))
            }
            Log.d(TAG, "scanDevice: faceResponse first ${previewLen} bytes: $sb")
            
            val faceUri = faceImageBytes?.let { writeFaceToFile(it) }
            
            Log.d(TAG, "scanDevice: after writeFaceToFile, faceUri=$faceUri")

            val _res = HashMap<String, Any>().apply {
                put("mrz", mrzText)
                if (faceUri != null) {
                    Log.d(TAG, "scanDevice: returning faceImageUri=$faceUri")
                    put("faceImageUri", faceUri)
                } else if (faceImageBytes != null) {
                    val b64 = android.util.Base64.encodeToString(faceImageBytes, android.util.Base64.NO_WRAP)
                    Log.d(TAG, "scanDevice: returning faceImageBase64 length=${b64.length}")
                    put("faceImageBase64", b64)
                } else {
                    Log.d(TAG, "scanDevice: NO IMAGE DATA - both faceUri and faceImageBytes are null")
                }
            }
            return _res
        } finally {
            runCatching {
                claimedInterface?.let { connection.releaseInterface(it) }
            }
            runCatching { connection.close() }
        }
    }

    private fun sendIcaoCommand(connection: UsbDeviceConnection, epIn: UsbEndpoint, epOut: UsbEndpoint, index: Int): ByteArray {
        val command = byteArrayOf(USB_CMD_GETICAO.toByte(), index.toByte())

        // Retry up to 3 times — the card sometimes needs a moment after being placed
        repeat(3) { attempt ->
            try {
                connection.bulkTransfer(epOut, command, command.size, 1000)
            } catch (t: Throwable) {
                Log.w(TAG, "sendIcaoCommand[$index] attempt=$attempt: bulkTransfer out failed: ${t.message}")
                return@repeat
            }

            val buffer = ByteArray(EP_BUFFER_SIZE)
            val baos = ByteArrayOutputStream()

            while (true) {
                val n = connection.bulkTransfer(epIn, buffer, buffer.size, 2000)
                if (n <= 0) break
                baos.write(buffer, 0, n)
                if (n < EP_BUFFER_SIZE) break
            }

            val result = baos.toByteArray()
            if (result.isNotEmpty()) {
                Log.d(TAG, "sendIcaoCommand[$index] attempt=$attempt: got ${result.size} bytes")
                return result
            }

            Log.w(TAG, "sendIcaoCommand[$index] attempt=$attempt: empty response, retrying in 500ms...")
            Thread.sleep(500)
        }

        Log.e(TAG, "sendIcaoCommand[$index]: all attempts returned empty")
        return ByteArray(0)
    }

    override fun onDestroy() {
        super.onDestroy()
        unregisterReceiver(usbReceiver)
    }

    private fun parseData(line: String): Map<String, Any?> {
        var input = line
        val parsedData = mutableMapOf<String, Any?>(
            "mrz" to line,
            "countryCode" to null,
            "cardId" to null,
            "gender" to null,
            "deliveryDate" to null,
            "uniqueId" to null,
            "lastName" to null,
            "firstName" to null,
            "date_naissance" to null
        )

        try {
            var rev = input.reversed()
            rev = rev.replace(Regex("^<+"), "")
            var firstName = rev.substring(0, rev.indexOf("<<"))
            rev = rev.replaceFirst(firstName, "")
            rev = rev.replaceFirst(Regex("^<<+"), "")
            var lastName = rev.substring(0, rev.indexOfFirst { it.isDigit() })
            rev = rev.replaceFirst(lastName, "")
            rev = if (rev.length > 1) rev.substring(1, rev.length) else ""
            val nextPos = if (rev.indexOf('<') != 0) rev.indexOf('<') else rev.indexOf('N')
            var uniqueId = if (nextPos > 0) rev.substring(0, nextPos) else ""
            rev = rev.replaceFirst(uniqueId, "")
            rev = if (rev.length > 1) rev.substring(1, rev.length) else ""
            var cc_date = try { rev.substring(0, rev.indexOf('<')) } catch (_: Exception) { "" }

            parsedData["firstName"] = firstName.reversed().replace("<", " ")
            parsedData["lastName"] = lastName.reversed()
            parsedData["uniqueId"] = uniqueId.reversed().replace("<", "").replace("<", "")

            rev = rev.replaceFirst(cc_date, "")

            if (cc_date.contains("NEB")) {
                cc_date = cc_date.replace("NEB", "")
                parsedData["countryCode"] = "BEN"
            } else if (cc_date.contains("EB")) {
                cc_date = cc_date.replace("EB", "")
                parsedData["countryCode"] = "BEN"
            }

            try {
                cc_date = cc_date.reversed()
                parsedData["date_naissance"] = cc_date.substring(0, 6)
            } catch (_: Exception) {
                parsedData["date_naissance"] = null
            }

            if (cc_date.contains("M")) {
                parsedData["gender"] = "M"
            } else if (cc_date.contains("F")) {
                parsedData["gender"] = "F"
            }

            if ((parsedData["date_naissance"] as? String)?.contains("M") == true ||
                (parsedData["date_naissance"] as? String)?.contains("F") == true
            ) {
                parsedData["date_naissance"] = null
                val gender = parsedData["gender"] as? String ?: ""
                if (cc_date.length > 1) cc_date = cc_date.substring(1, cc_date.length)
                cc_date = cc_date.reversed()
            } else {
                if (cc_date.length > 6) cc_date = cc_date.substring(6, cc_date.length)
                cc_date = cc_date.reversed()
            }

            cc_date = cc_date.reversed()
            val gender = parsedData["gender"] as? String ?: ""
            if (cc_date.indexOf(gender) >= 0) cc_date = cc_date.substring(cc_date.indexOf(gender) + 1)
            val date = if (cc_date.length >= 6) cc_date.substring(0, 6) else ""
            parsedData["date_naissance"] = extractDate(parsedData["date_naissance"] as? String)
            parsedData["deliveryDate"] = date

            rev = rev.replace(Regex("^<+"), "")
            val cardNumber = try { rev.substring(1, rev.indexOf('<')) } catch (_: Exception) { "" }
            parsedData["cardId"] = cardNumber.reversed().replace(Regex("[A-Za-z]+"), "")
        } catch (e: Exception) {
            Log.e(TAG, "parseData error: ${e.message}")
        }

        return parsedData
    }

    private fun extractDate(dateString: String?): String {
        if (dateString != null) {
            if (dateString.length >= 6) {
                val yearSuffix = dateString.substring(0, 2).toIntOrNull() ?: return "Indisponible"
                val year = if (yearSuffix < 50) 2000 + yearSuffix else 1900 + yearSuffix
                val month = dateString.substring(2, 4).toIntOrNull() ?: return "Indisponible"
                val day = dateString.substring(4, 6).toIntOrNull() ?: return "Indisponible"
                val str = "$day-$month-$year"
                return str
            }
        }
        return "Indisponible"
    }

    private fun decodeJp2ToPng(jp2Bytes: ByteArray): ByteArray? {
        return try {
            Log.d(TAG, "decodeJp2ToPng: attempting to decode ${jp2Bytes.size} bytes")

            // Method 1: Try Android's ImageDecoder (API 29+)
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.Q) {
                try {
                    val source = android.graphics.ImageDecoder.createSource(java.nio.ByteBuffer.wrap(jp2Bytes))
                    val bmp = android.graphics.ImageDecoder.decodeBitmap(source)
                    if (bmp != null) {
                        Log.d(TAG, "decodeJp2ToPng: ImageDecoder succeeded")
                        val pngStream = java.io.ByteArrayOutputStream()
                        bmp.compress(android.graphics.Bitmap.CompressFormat.PNG, 100, pngStream)
                        bmp.recycle()
                        return pngStream.toByteArray()
                    }
                } catch (e: Exception) {
                    Log.d(TAG, "decodeJp2ToPng: ImageDecoder failed: ${e.message}")
                }
            }

            // Method 2: Try BitmapFactory
            try {
                val bmp = android.graphics.BitmapFactory.decodeByteArray(jp2Bytes, 0, jp2Bytes.size)
                if (bmp != null) {
                    Log.d(TAG, "decodeJp2ToPng: BitmapFactory succeeded")
                    val pngStream = java.io.ByteArrayOutputStream()
                    bmp.compress(android.graphics.Bitmap.CompressFormat.PNG, 100, pngStream)
                    bmp.recycle()
                    return pngStream.toByteArray()
                }
            } catch (e: Exception) {
                Log.d(TAG, "decodeJp2ToPng: BitmapFactory failed: ${e.message}")
            }

            // Method 3: call native OpenJPEG decoder via JNI
            try {
                val decoded = OpenJpegBridge.decode(jp2Bytes)
                if (decoded.error != null) {
                    Log.w(TAG, "decodeJp2ToPng: native openjpeg returned error=${decoded.error}")
                } else if (decoded.width > 0 && decoded.height > 0 && decoded.rgba != null) {
                    val rgba = decoded.rgba!!
                    val width = decoded.width
                    val height = decoded.height
                    if (rgba.size >= width * height * 4) {
                        Log.d(TAG, "decodeJp2ToPng: native openjpeg decoded ${width}x${height}")
                        val pixels = IntArray(width * height)
                        for (i in 0 until (width * height)) {
                            val o = i * 4
                            val r = rgba[o].toInt() and 0xFF
                            val g = rgba[o + 1].toInt() and 0xFF
                            val b = rgba[o + 2].toInt() and 0xFF
                            val a = rgba[o + 3].toInt() and 0xFF
                            pixels[i] = (a shl 24) or (r shl 16) or (g shl 8) or b
                        }
                        val bmp = android.graphics.Bitmap.createBitmap(pixels, width, height, android.graphics.Bitmap.Config.ARGB_8888)
                        val pngStream = java.io.ByteArrayOutputStream()
                        bmp.compress(android.graphics.Bitmap.CompressFormat.PNG, 100, pngStream)
                        bmp.recycle()
                        return pngStream.toByteArray()
                    }
                    Log.w(TAG, "decodeJp2ToPng: native openjpeg returned rgba too small (${rgba.size}) for ${width}x${height}")
                }
            } catch (e: Exception) {
                Log.w(TAG, "decodeJp2ToPng: native openjpeg failed: ${e.message}")
            }

            Log.w(TAG, "decodeJp2ToPng: All decoding methods failed. JP2 format may not be supported by this device.")
            null
        } catch (t: Throwable) {
            Log.e(TAG, "decodeJp2ToPng: Exception: ${t.message}", t)
            null
        }
    }

    private fun writeFaceToFile(imageBytes: ByteArray): String? {
        try {
            val t0 = System.currentTimeMillis()
            Log.d(TAG, ">>> writeFaceToFile START (${imageBytes.size} bytes) <<<")

            if (imageBytes.isEmpty()) {
                Log.w(TAG, "imageBytes is empty, returning null")
                return null
            }

            // Fast JPEG path
            if (imageBytes.size >= 2 && imageBytes[0] == 0xFF.toByte() && imageBytes[1] == 0xD8.toByte()) {
                val file = java.io.File(cacheDir, "face_${System.currentTimeMillis()}.jpg")
                file.outputStream().use { it.write(imageBytes) }
                Log.d(TAG, "writeFaceToFile: wrote JPEG ${file.absolutePath} in ${System.currentTimeMillis()-t0}ms")
                return file.absolutePath
            }

            // Detect JP2 / J2K signatures
            val isJp2 = looksLikeJp2(imageBytes, 0)
            val isJ2k = looksLikeJ2k(imageBytes, 0)
            if (isJp2 || isJ2k) {
                Log.d(TAG, "writeFaceToFile: detected JP2/J2K (isJp2=$isJp2 isJ2k=$isJ2k)")

                // Try to convert to PNG first
                val pngBytes = decodeJp2ToPng(imageBytes)
                if (pngBytes != null && pngBytes.isNotEmpty()) {
                    val outFile = java.io.File(cacheDir, "face_${System.currentTimeMillis()}.png")
                    java.io.FileOutputStream(outFile).use { out ->
                        out.write(pngBytes)
                    }
                    Log.d(TAG, "writeFaceToFile: converted JP2/J2K to PNG ${outFile.absolutePath}")
                    return outFile.absolutePath
                }

                // If conversion fails, return null to trigger base64 fallback in Flutter
                Log.d(TAG, "writeFaceToFile: Could not convert JP2/J2K to PNG, returning null for base64 fallback")
                return null
            }

            // Last resort: try generic decode via BitmapFactory
            try {
                val bmp = android.graphics.BitmapFactory.decodeByteArray(imageBytes, 0, imageBytes.size)
                if (bmp != null) {
                    val outFile = java.io.File(cacheDir, "face_${System.currentTimeMillis()}.png")
                    java.io.FileOutputStream(outFile).use { out ->
                        if (!bmp.compress(android.graphics.Bitmap.CompressFormat.PNG, 100, out)) {
                            Log.e(TAG, "writeFaceToFile: Bitmap.compress returned false on generic decode")
                            bmp.recycle()
                            return null
                        }
                    }
                    bmp.recycle()
                    Log.d(TAG, "writeFaceToFile: decoded generic image to PNG ${outFile.absolutePath}")
                    return outFile.absolutePath
                }
            } catch (t: Throwable) {
                Log.e(TAG, "writeFaceToFile: generic decode error: ${t.message}", t)
            }

            // If nothing decoded, write raw bytes as .bin for inspection
            val fallback = java.io.File(cacheDir, "face_${System.currentTimeMillis()}.bin")
            try {
                fallback.outputStream().use { it.write(imageBytes) }
                Log.d(TAG, "writeFaceToFile: wrote fallback raw bytes to ${fallback.absolutePath}")
                return fallback.absolutePath
            } catch (e: Exception) {
                Log.e(TAG, "writeFaceToFile: failed to write fallback file: ${e.message}", e)
                return null
            }
        } catch (t: Throwable) {
            Log.e(TAG, ">>> writeFaceToFile EXCEPTION: ${t.message} <<<", t)
            return null
        }
    }

    // ============== UPDATED: TLV-AWARE ICAO DG2 FACE IMAGE DECODER ==============

    private fun decodeFaceImage(data: ByteArray): ByteArray? {
        // 0) Fast sanity
        if (data.isEmpty()) {
            Log.e(TAG, "decodeFaceImage: empty input")
            return null
        }
        
        Log.d(TAG, "decodeFaceImage: input size=${data.size}, first20Bytes=${hexPreview(data, 0, 20)}")

        // 1) Fast path: device already returned a bare image
        when {
            looksLikeJpeg(data, 0) -> {
                Log.d(TAG, "decodeFaceImage: bare JPEG detected, returning ${data.size} bytes")
                return data
            }
            looksLikeJp2(data, 0) -> {
                Log.d(TAG, "decodeFaceImage: bare JP2 detected, returning ${data.size} bytes")
                return data
            }
            looksLikeJ2k(data, 0) -> {
                Log.d(TAG, "decodeFaceImage: bare J2K detected, returning ${data.size} bytes")
                return data
            }
        }

        // 2) Parse TLV: unwrap optional outer 0x75 (LDS DataGroup) before finding 7F61
        val top = TlvCursor(data, 0, data.size)
        var searchSlice: Slice = Slice(0, data.size)
        var bigtValueSlice: Slice? = null

        while (top.hasRemaining()) {
            val tlv = top.next() ?: break
            Log.d(TAG, "decodeFaceImage: found TLV tag=${String.format("0x%02X", tlv.tag)} value_size=${tlv.value.length}")
            when (tlv.tag) {
                0x75 -> {
                    // Outer DG2 container (constructed)
                    searchSlice = tlv.value
                    Log.d(TAG, "decodeFaceImage: found outer 0x75 container")
                }
                0x7F61 -> {
                    bigtValueSlice = tlv.value
                    Log.d(TAG, "decodeFaceImage: found 7F61, value_size=${tlv.value.length}")
                    break
                }
                else -> { /* skip */ }
            }
        }

        // If 7F61 not found at top level, try inside 0x75 value
        if (bigtValueSlice == null && searchSlice.length > 0) {
            Log.d(TAG, "decodeFaceImage: 7F61 not at top level, searching inside 0x75 value...")
            val innerTop = TlvCursor(data, searchSlice.start, searchSlice.endExclusive)
            while (innerTop.hasRemaining()) {
                val tlv = innerTop.next() ?: break
                Log.d(TAG, "decodeFaceImage: inner search - found TLV tag=${String.format("0x%02X", tlv.tag)}")
                if (tlv.tag == 0x7F61) {
                    bigtValueSlice = tlv.value
                    Log.d(TAG, "decodeFaceImage: found 7F61 inside 0x75, value_size=${tlv.value.length}")
                    break
                }
            }
        }

        if (bigtValueSlice == null) {
            Log.e(TAG, "decodeFaceImage: DG2_TLV_INVALID (7F61 not found). First16=${hexPreview(data, 0, 16)}")
            return null
        }

        // 3) Recursively find 5F2E (BDB — Biometric Data Block) inside 7F61.
        //    Some readers use 7F2E instead of 5F2E — try both.
        //    If neither found, fall back to scanning the entire 7F61 value.
        var bdbSlice: Slice? = findTagRecursive(
            buf = data,
            start = bigtValueSlice.start,
            end = bigtValueSlice.endExclusive,
            targetTag = 0x5F2E
        )
        if (bdbSlice == null) {
            Log.w(TAG, "decodeFaceImage: 5F2E not found, trying 7F2E...")
            bdbSlice = findTagRecursive(
                buf = data,
                start = bigtValueSlice.start,
                end = bigtValueSlice.endExclusive,
                targetTag = 0x7F2E
            )
        }
        if (bdbSlice == null) {
            Log.w(TAG, "decodeFaceImage: No BDB tag found — scanning entire 7F61 value for image signature")
            bdbSlice = bigtValueSlice
        } else {
            Log.d(TAG, "decodeFaceImage: found BDB slice, size=${bdbSlice.length}")
        }

        // 4) Locate embedded image inside the BDB (prefer JP2 > J2K > JPEG)
        val bdbStart = bdbSlice.start
        val bdbEnd   = bdbSlice.endExclusive

        val jp2Sig  = byteArrayOf(0x00, 0x00, 0x00, 0x0C, 0x6A, 0x50, 0x20, 0x20) // .... jP  
        val jpegSoI = byteArrayOf(0xFF.toByte(), 0xD8.toByte())
        val j2kSoc  = byteArrayOf(0xFF.toByte(), 0x4F.toByte())

        val jp2Off = indexOf(data, bdbStart, bdbEnd, jp2Sig)
        val j2kOff = indexOf(data, bdbStart, bdbEnd, j2kSoc)
        val jpgOff = indexOf(data, bdbStart, bdbEnd, jpegSoI)
        
        Log.d(TAG, "decodeFaceImage: image signature search - jp2Off=$jp2Off, j2kOff=$j2kOff, jpgOff=$jpgOff")

        val (imgType, imgOffset) = when {
            jp2Off >= 0 -> "JP2"  to jp2Off
            j2kOff >= 0 -> "J2K"  to j2kOff
            jpgOff >= 0 -> "JPEG" to jpgOff
            else -> {
                Log.e(TAG, "decodeFaceImage: IMAGE_FORMAT_UNSUPPORTED within BDB. BDB first32=${hexPreview(data, bdbStart, 32)}")
                return null
            }
        }

        val imageBytes = data.copyOfRange(imgOffset, bdbEnd)
        Log.d(TAG, "decodeFaceImage: image=$imgType offset=${imgOffset - bdbStart} size=${imageBytes.size}, imgFirst16=${hexPreview(imageBytes, 0, 16)}")

        return imageBytes
    }

    // ============== TLV HELPERS ==============

    private fun findTagRecursive(buf: ByteArray, start: Int, end: Int, targetTag: Int, depth: Int = 0): Slice? {
        if (depth > 8) return null // guard against infinite recursion
        val cur = TlvCursor(buf, start, end)
        while (cur.hasRemaining()) {
            val tlv = cur.next() ?: break
            if (tlv.tag == targetTag) {
                Log.d(TAG, "findTagRecursive: Found 0x${String.format("%04X", targetTag)} at depth=$depth")
                return tlv.value
            }
            // Recurse into any constructed container (multi-byte tags or common constructed singles)
            if (tlv.value.length > 2) {
                val nested = findTagRecursive(buf, tlv.value.start, tlv.value.endExclusive, targetTag, depth + 1)
                if (nested != null) return nested
            }
        }
        return null
    }

    private fun indexOf(hay: ByteArray, start: Int, end: Int, needle: ByteArray): Int {
        if (needle.isEmpty()) return start
        if (needle.size > end - start) return -1
        val lastStart = end - needle.size
        var i = start
        while (i <= lastStart) {
            var match = true
            for (j in needle.indices) {
                if (hay[i + j] != needle[j]) {
                    match = false
                    break
                }
            }
            if (match) return i
            i++
        }
        return -1
    }

    private fun looksLikeJpeg(buf: ByteArray, off: Int): Boolean =
        off + 1 < buf.size && buf[off] == 0xFF.toByte() && buf[off + 1] == 0xD8.toByte()

    private fun looksLikeJp2(buf: ByteArray, off: Int): Boolean =
        off + 7 < buf.size && buf[off + 4] == 0x6A.toByte() && buf[off + 5] == 0x50.toByte() &&
        buf[off + 6] == 0x20.toByte() && buf[off + 7] == 0x20.toByte()

    private fun looksLikeJ2k(buf: ByteArray, off: Int): Boolean =
        off + 1 < buf.size && buf[off] == 0xFF.toByte() && buf[off + 1] == 0x4F.toByte()

    private fun hexPreview(buf: ByteArray, off: Int, len: Int): String {
        if (off >= buf.size) return ""
        val end = (off + len).coerceAtMost(buf.size)
        val sb = StringBuilder((end - off) * 3)
        for (i in off until end) sb.append(String.format("%02X ", buf[i]))
        return sb.toString().trimEnd()
    }

    private data class Slice(val start: Int, val length: Int) {
        val endExclusive: Int get() = start + length
    }

    private data class Tlv(val tag: Int, val value: Slice)

    private inner class TlvCursor(private val buf: ByteArray, var pos: Int, private val end: Int) {
        fun hasRemaining(): Boolean = pos < end

        fun next(): Tlv? {
            if (!hasRemaining()) return null

            val tagRes = readTag(buf, pos, end) ?: return null
            val (tag, tagLenBytes) = tagRes
            var cursor = pos + tagLenBytes

            val lenRes = readLen(buf, cursor, end) ?: return null
            val (len, lenLenBytes) = lenRes
            cursor += lenLenBytes

            if (len < 0 || cursor + len > end) {
                Log.e(TAG, "TLV parse error: length=$len exceeds remaining=${end - cursor}")
                return null
            }

            val valueSlice = Slice(cursor, len)
            pos = cursor + len

            return Tlv(tag, valueSlice)
        }
    }

    private fun readTag(buf: ByteArray, off: Int, end: Int): Pair<Int, Int>? {
        if (off >= end) return null
        val b0 = buf[off].toInt() and 0xFF

        return when (b0) {
            0x7F -> {
                if (off + 1 >= end) null
                else {
                    val b1 = buf[off + 1].toInt() and 0xFF
                    val tag = (b0 shl 8) or b1
                    Pair(tag, 2)
                }
            }
            0x5F -> {
                if (off + 1 >= end) null
                else {
                    val b1 = buf[off + 1].toInt() and 0xFF
                    val tag = (b0 shl 8) or b1
                    Pair(tag, 2)
                }
            }
            else -> Pair(b0, 1)
        }
    }

    private fun readLen(buf: ByteArray, off: Int, end: Int): Pair<Int, Int>? {
        if (off >= end) return null
        val b = buf[off].toInt() and 0xFF

        return when {
            b < 0x80 -> Pair(b, 1)
            b == 0x81 -> {
                if (off + 1 >= end) null else Pair(buf[off + 1].toInt() and 0xFF, 2)
            }
            b == 0x82 -> {
                if (off + 2 >= end) null else {
                    val hi = buf[off + 1].toInt() and 0xFF
                    val lo = buf[off + 2].toInt() and 0xFF
                    Pair((hi shl 8) or lo, 3)
                }
            }
            b == 0x83 -> {
                if (off + 3 >= end) null else {
                    val b1 = buf[off + 1].toInt() and 0xFF
                    val b2 = buf[off + 2].toInt() and 0xFF
                    val b3 = buf[off + 3].toInt() and 0xFF
                    val len = (b1 shl 16) or (b2 shl 8) or b3
                    Pair(len, 4)
                }
            }
            b == 0x84 -> {
                if (off + 4 >= end) null else {
                    val b1 = buf[off + 1].toInt() and 0xFF
                    val b2 = buf[off + 2].toInt() and 0xFF
                    val b3 = buf[off + 3].toInt() and 0xFF
                    val b4 = buf[off + 4].toInt() and 0xFF
                    val len = (b1 shl 24) or (b2 shl 16) or (b3 shl 8) or b4
                    Pair(len, 5)
                }
            }
            else -> {
                Log.e(TAG, "Unsupported BER length form: 0x${String.format("%02X", b)}")
                null
            }
        }
    }
}
