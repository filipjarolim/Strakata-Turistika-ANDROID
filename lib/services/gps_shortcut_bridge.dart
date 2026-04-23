import 'package:flutter/foundation.dart';

class GpsShortcutBridge {
  static final ValueNotifier<bool> startTracking = ValueNotifier<bool>(false);

  static void requestStartTracking() {
    startTracking.value = true;
  }

  static void consumeStartTracking() {
    startTracking.value = false;
  }
}
