import 'package:flutter/foundation.dart';

class UserSession {
  UserSession._();

  static final ValueNotifier<String?> displayName = ValueNotifier<String?>(null);
}
