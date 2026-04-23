import 'package:flutter/foundation.dart';

class OfflineUiBridge {
  static final ValueNotifier<bool> openManager = ValueNotifier<bool>(false);

  static void requestOpenManager() {
    // Force notifier change even if previous request was not consumed yet.
    openManager.value = false;
    openManager.value = true;
  }

  static void consumeOpenManager() {
    openManager.value = false;
  }
}


