import 'dart:async';
import 'dart:io';

import 'package:quick_actions/quick_actions.dart';

enum AppShortcutAction {
  startTracking('start_tracking'),
  openMap('open_map'),
  openOffline('open_offline');

  const AppShortcutAction(this.type);
  final String type;

  static AppShortcutAction? fromType(String? type) {
    for (final action in AppShortcutAction.values) {
      if (action.type == type) return action;
    }
    return null;
  }
}

class AppShortcutsService {
  AppShortcutsService._();
  static final AppShortcutsService _instance = AppShortcutsService._();
  factory AppShortcutsService() => _instance;

  final QuickActions _quickActions = const QuickActions();
  final StreamController<AppShortcutAction> _actionsController =
      StreamController<AppShortcutAction>.broadcast();

  AppShortcutAction? _pendingAction;
  bool _initialized = false;

  Stream<AppShortcutAction> get actions => _actionsController.stream;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    await _quickActions.initialize((String type) {
      final action = AppShortcutAction.fromType(type);
      if (action == null) return;
      _pendingAction = action;
      _actionsController.add(action);
    });

    await _quickActions.setShortcutItems(<ShortcutItem>[
      ShortcutItem(
        type: 'start_tracking',
        localizedTitle: Platform.isIOS ? 'Start Tracking' : 'Spustit sledovani',
        icon: Platform.isIOS ? 'location' : null,
      ),
      ShortcutItem(
        type: 'open_map',
        localizedTitle: Platform.isIOS ? 'Map' : 'Mapa',
        icon: Platform.isIOS ? 'location.fill' : null,
      ),
      ShortcutItem(
        type: 'open_offline',
        localizedTitle: Platform.isIOS ? 'Offline Maps' : 'Offline mapy',
        icon: Platform.isIOS ? 'map' : null,
      ),
    ]);
  }

  AppShortcutAction? consumePendingAction() {
    final action = _pendingAction;
    _pendingAction = null;
    return action;
  }
}
