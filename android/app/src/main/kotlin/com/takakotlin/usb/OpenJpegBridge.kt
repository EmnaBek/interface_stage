package com.takakotlin.usb

object OpenJpegBridge {
    @JvmStatic
    external fun decode(data: ByteArray): DecodeResult
}
