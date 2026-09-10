import 'package:shared_preferences/shared_preferences.dart';

/// Režim GPS jako u turistických app (Komoot / AllTrails):
/// úspora vypíná přesný GNSS, když není potřeba.
enum GpsPowerMode {
  /// Výchozí pro celodenní výlet — méně vzorků, při stání BALANCED_POWER.
  saver,

  /// Hustší stopy (vrcholy, krátká trasa) — víc baterie.
  precise,
}

class GpsPowerModeStore {
  static final GpsPowerModeStore _instance = GpsPowerModeStore._internal();
  factory GpsPowerModeStore() => _instance;
  GpsPowerModeStore._internal();

  static const _key = 'gps_power_mode';

  GpsPowerMode mode = GpsPowerMode.saver;
  bool _loaded = false;

  Future<GpsPowerMode> load() async {
    if (_loaded) return mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      mode = prefs.getString(_key) == 'precise'
          ? GpsPowerMode.precise
          : GpsPowerMode.saver;
    } catch (_) {
      mode = GpsPowerMode.saver;
    }
    _loaded = true;
    return mode;
  }

  Future<void> setMode(GpsPowerMode value) async {
    mode = value;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        value == GpsPowerMode.precise ? 'precise' : 'saver',
      );
    } catch (_) {}
  }
}
