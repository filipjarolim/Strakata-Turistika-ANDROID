import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_colors.dart';
import '../config/season_theme.dart';

/// Persists light-mode seasonal appearance + launcher icon preference.
class AppearancePreferencesService extends ChangeNotifier {
  AppearancePreferencesService._();
  static final AppearancePreferencesService instance =
      AppearancePreferencesService._();

  static const _seasonKey = 'appearance_season';
  static const _followCalendarKey = 'appearance_follow_calendar';
  static const _iconKey = 'appearance_app_icon';
  static const _channel = MethodChannel('app_icon_channel');

  bool _loaded = false;
  bool followCalendar = true;
  AppSeason season = AppSeason.calendarDefault();
  AppIconVariant iconVariant = AppIconVariant.classic;

  SeasonPalette get palette => SeasonPalette.forSeason(season);

  Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      followCalendar = prefs.getBool(_followCalendarKey) ?? true;
      if (followCalendar) {
        season = AppSeason.calendarDefault();
      } else {
        season = AppSeason.fromId(prefs.getString(_seasonKey));
      }
      iconVariant = AppIconVariant.fromId(prefs.getString(_iconKey));
    } catch (e) {
      print('⚠️ Appearance prefs load failed: $e');
      season = AppSeason.calendarDefault();
      iconVariant = AppIconVariant.classic;
      followCalendar = true;
    }
    AppColors.applyPalette(palette);
    _loaded = true;
    notifyListeners();
  }

  Future<void> setFollowCalendar(bool value) async {
    followCalendar = value;
    if (value) {
      season = AppSeason.calendarDefault();
      AppColors.applyPalette(palette);
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_followCalendarKey, value);
      if (value) {
        await prefs.setString(_seasonKey, season.id);
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<void> setSeason(AppSeason value) async {
    followCalendar = false;
    season = value;
    AppColors.applyPalette(palette);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_followCalendarKey, false);
      await prefs.setString(_seasonKey, value.id);
    } catch (_) {}
    notifyListeners();
  }

  Future<String?> setIconVariant(AppIconVariant value) async {
    final previous = iconVariant;
    iconVariant = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_iconKey, value.id);
    } catch (_) {}
    notifyListeners();

    try {
      final result = await _channel.invokeMethod<String>('setIcon', {
        'icon': value.id,
        'androidAlias': value.androidAliasSuffix,
        'iosName': value.iosAlternateName,
      });
      return result;
    } on PlatformException catch (e) {
      print('⚠️ App icon switch failed: ${e.message}');
      iconVariant = previous;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_iconKey, previous.id);
      } catch (_) {}
      notifyListeners();
      return e.message ?? 'Nepodařilo se změnit ikonu';
    } catch (e) {
      print('⚠️ App icon switch failed: $e');
      return e.toString();
    }
  }
}
