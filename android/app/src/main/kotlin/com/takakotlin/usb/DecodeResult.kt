package com.takakotlin.usb

data class DecodeResult(
    var width: Int = 0,
    var height: Int = 0,
    var rgba: ByteArray? = null,
    var error: String? = null,
)
