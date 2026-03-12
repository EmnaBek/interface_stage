package com.example.interface_stage.usb

const val TAG = "TAKA_USB"

// USB device settings
const val VENDOR_ID = 0xFFFF
const val EP_IN_ADDRESS = 0x81
const val EP_OUT_ADDRESS = 0x02
const val EP_BUFFER_SIZE = 256
const val EXTENDED_BUFFER_SIZE = 8192

// USB command codes
const val USB_CMD_GETVERSION = 0x00
const val USB_CMD_GETARCH = 0x01
const val USB_CMD_GETICAO = 0x02
const val USB_CMD_GETLOGS = 0x03
const val USB_CMD_GETFRAME_RAW = 0x04
const val USB_CMD_GETFRAME_MORPH = 0x05
const val USB_CMD_GETMINUTIAES_FMR = 0x06
const val USB_CMD_GETUNIQUEID = 0x07
