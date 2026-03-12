import 'package:flutter/services.dart';

class TakaUsbService {
  static const MethodChannel _channel = MethodChannel('taka_usb');

  Future<bool> connect() async {
    try {
      final bool result = await _channel.invokeMethod('connect');
      return result;
    } catch (e) {
      return false;
    }
  }

  Future<String> readCard() async {
    try {
      final String result = await _channel.invokeMethod('readCard');
      return result;
    } catch (e) {
      return "READ ERROR";
    }
  }

  Future<void> disconnect() async {
    try {
      await _channel.invokeMethod('disconnect');
    } catch (_) {}
  }
}
