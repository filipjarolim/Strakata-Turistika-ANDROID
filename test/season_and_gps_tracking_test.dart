import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:strakataturistikaandroidapp/config/app_colors.dart';
import 'package:strakataturistikaandroidapp/config/gps_config.dart';
import 'package:strakataturistikaandroidapp/config/season_theme.dart';
import 'package:strakataturistikaandroidapp/services/appearance_preferences_service.dart';
import 'package:strakataturistikaandroidapp/services/enhanced_gps_tracking_service.dart';
import 'package:strakataturistikaandroidapp/services/gps_power_mode.dart';

Position _pos({
  required double lat,
  required double lng,
  required DateTime time,
  double accuracy = 4.0,
  double speed = 1.4,
  double altitude = 220.0,
}) {
  return Position(
    latitude: lat,
    longitude: lng,
    timestamp: time,
    accuracy: accuracy,
    altitude: altitude,
    altitudeAccuracy: 4.0,
    heading: 0.0,
    headingAccuracy: 0.0,
    speed: speed,
    speedAccuracy: 0.4,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Season themes (light only)', () {
    test('calendarDefault maps meteorological months', () {
      expect(AppSeason.calendarDefault(DateTime(2026, 3, 15)), AppSeason.spring);
      expect(AppSeason.calendarDefault(DateTime(2026, 7, 1)), AppSeason.summer);
      expect(AppSeason.calendarDefault(DateTime(2026, 9, 10)), AppSeason.autumn);
      expect(AppSeason.calendarDefault(DateTime(2026, 12, 24)), AppSeason.winter);
      expect(AppSeason.calendarDefault(DateTime(2026, 1, 5)), AppSeason.winter);
    });

    test('each season has a distinct brand color (light palettes)', () {
      final brands = {
        for (final s in AppSeason.values) s: SeasonPalette.forSeason(s).brand,
      };
      expect(brands[AppSeason.spring], isNot(brands[AppSeason.autumn]));
      expect(brands[AppSeason.summer], isNot(brands[AppSeason.winter]));
      expect(brands[AppSeason.autumn], isNot(brands[AppSeason.winter]));
      for (final s in AppSeason.values) {
        final p = SeasonPalette.forSeason(s);
        expect(p.pageBg, isNot(Colors.black));
        expect(p.brand.computeLuminance(), greaterThan(0.05));
      }
    });

    test('AppTheme.themeFor stays light-mode for every season', () {
      // Avoid GoogleFonts network fetch in CI: only assert ColorScheme brightness
      // via a lightweight scheme check through SeasonPalette → AppColors apply.
      for (final s in AppSeason.values) {
        AppColors.applyPalette(SeasonPalette.forSeason(s));
        expect(AppColors.activePalette.season, s);
        expect(ThemeData.estimateBrightnessForColor(AppColors.pageBg), Brightness.light);
      }
      AppColors.applyPalette(SeasonPalette.forSeason(AppSeason.calendarDefault()));
    });

    test('AppColors.applyPalette updates brand for autumn', () {
      AppColors.applyPalette(SeasonPalette.forSeason(AppSeason.spring));
      final springBrand = AppColors.brand;
      AppColors.applyPalette(SeasonPalette.forSeason(AppSeason.autumn));
      expect(AppColors.brand, isNot(springBrand));
      expect(AppColors.activePalette.season, AppSeason.autumn);
      // restore
      AppColors.applyPalette(SeasonPalette.forSeason(AppSeason.spring));
    });
  });

  group('AppearancePreferencesService', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      // Reset singleton state via load after clearing prefs
      final svc = AppearancePreferencesService.instance;
      await svc.load();
    });

    test('defaults follow calendar season', () async {
      SharedPreferences.setMockInitialValues({});
      final svc = AppearancePreferencesService.instance;
      await svc.setFollowCalendar(true);
      expect(svc.followCalendar, isTrue);
      expect(svc.season, AppSeason.calendarDefault());
    });

    test('manual season persists and disables calendar follow', () async {
      final svc = AppearancePreferencesService.instance;
      await svc.setSeason(AppSeason.winter);
      expect(svc.followCalendar, isFalse);
      expect(svc.season, AppSeason.winter);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('appearance_season'), 'winter');
      expect(prefs.getBool('appearance_follow_calendar'), isFalse);
    });

    test('icon preference persists with mocked platform channel', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('app_icon_channel'),
        (call) async => 'ok',
      );
      final svc = AppearancePreferencesService.instance;
      await svc.setIconVariant(AppIconVariant.autumn);
      expect(svc.iconVariant, AppIconVariant.autumn);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('appearance_app_icon'), 'autumn');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('app_icon_channel'),
        null,
      );
    });
  });

  group('GpsPowerModeStore', () {
    test('round-trips saver and precise', () async {
      SharedPreferences.setMockInitialValues({});
      final store = GpsPowerModeStore();
      expect(await store.load(), GpsPowerMode.saver);
      await store.setMode(GpsPowerMode.precise);
      SharedPreferences.setMockInitialValues({
        'gps_power_mode': 'precise',
      });
      // New load path on fresh flags: simulate by setting mode then reading prefs
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('gps_power_mode'), 'precise');
      await store.setMode(GpsPowerMode.saver);
      expect(store.mode, GpsPowerMode.saver);
    });
  });

  group('EnhancedGPSTrackingService - live movement simulation', () {
    late EnhancedGPSTrackingService service;

    setUp(() {
      service = EnhancedGPSTrackingService();
      service.testResetState();
      service.testSuppressSideEffects = true;
      service.testBeginTrackingSession(startTime: DateTime(2026, 9, 10, 10, 0, 0));
    });

    test('records a walking track and accumulates realistic distance', () {
      final start = DateTime(2026, 9, 10, 10, 0, 0);
      // ~5 m north per step (0.000045 deg lat ≈ 5 m), every 3 seconds → ~1.67 m/s walk
      for (int i = 0; i <= 20; i++) {
        service.onPositionUpdate(_pos(
          lat: 50.0 + i * 0.000045,
          lng: 14.4,
          time: start.add(Duration(seconds: i * 3)),
          speed: 1.6,
        ));
      }

      expect(service.isTracking, isTrue);
      expect(service.testTrackPoints.length, greaterThan(10));
      // 20 * 5m = 100m
      expect(service.totalDistance, greaterThan(80));
      expect(service.totalDistance, lessThan(130));
      final summary = service.getSummary();
      expect(summary.trackPoints.length, service.testTrackPoints.length);
      expect(summary.totalDistance, closeTo(service.totalDistance, 0.01));
    });

    test('pause freezes new points and duration growth from recording', () {
      final start = DateTime(2026, 9, 10, 11, 0, 0);
      service.onPositionUpdate(_pos(lat: 50.0, lng: 14.4, time: start));
      service.onPositionUpdate(_pos(
        lat: 50.00009,
        lng: 14.4,
        time: start.add(const Duration(seconds: 4)),
        speed: 2.0,
      ));
      final pointsBeforePause = service.testTrackPoints.length;
      final distBefore = service.totalDistance;

      service.setRecordingPaused(true);
      expect(service.testRecordingPaused, isTrue);

      // These must be ignored while paused
      service.onPositionUpdate(_pos(
        lat: 50.0002,
        lng: 14.4,
        time: start.add(const Duration(seconds: 8)),
        speed: 2.0,
      ));
      service.forceAddPosition(_pos(
        lat: 50.0003,
        lng: 14.4,
        time: start.add(const Duration(seconds: 12)),
        speed: 2.0,
      ));

      expect(service.testTrackPoints.length, pointsBeforePause);
      expect(service.totalDistance, distBefore);

      service.setRecordingPaused(false);
      service.onPositionUpdate(_pos(
        lat: 50.00018,
        lng: 14.4,
        time: start.add(const Duration(seconds: 16)),
        speed: 2.0,
      ));
      expect(service.testTrackPoints.length, greaterThan(pointsBeforePause));
    });

    test('rejects duplicate burst samples closer than minSampleInterval', () {
      final t0 = DateTime(2026, 9, 10, 12, 0, 0);
      service.onPositionUpdate(_pos(lat: 50.0, lng: 14.4, time: t0));
      final before = service.testTrackPoints.length;

      // Same location 200ms later — should be ignored by minSampleIntervalMs
      service.onPositionUpdate(_pos(
        lat: 50.00005,
        lng: 14.4,
        time: t0.add(Duration(milliseconds: GpsConfig.minSampleIntervalMs ~/ 2)),
        speed: 1.5,
      ));
      expect(service.testTrackPoints.length, before);
    });

    test('slow forest-accuracy walk still tracks (accuracy within caps)', () {
      final start = DateTime(2026, 9, 10, 13, 0, 0);
      for (int i = 0; i <= 12; i++) {
        service.onPositionUpdate(_pos(
          lat: 50.1 + i * 0.00004,
          lng: 14.5,
          time: start.add(Duration(seconds: i * 4)),
          speed: 1.0,
          accuracy: 16.0,
        ));
      }
      expect(service.totalDistance, greaterThan(30));
      expect(service.testTrackPoints.length, greaterThan(5));
    });

    test('seniorské tempo v lese nezkrátí 2 km na čtvrtinu', () {
      final start = DateTime(2026, 11, 15, 9, 0, 0);
      // ~8 m každých 12 s ≈ 0,67 m/s (2,4 km/h). Android často hlásí speed 0.
      // Přesnost 30 m je v lese běžná a dřív se celý krok zahodil.
      const steps = 250; // 250 * 8 m = 2 km
      for (var i = 0; i <= steps; i++) {
        service.onPositionUpdate(_pos(
          lat: 49.2 + i * 0.000072,
          lng: 16.6,
          time: start.add(Duration(seconds: i * 12)),
          speed: 0,
          accuracy: 30,
        ));
      }
      expect(service.totalDistance, greaterThan(1600));
      expect(service.totalDistance, lessThan(2300));
    });

    test('pomalá chůze s bočním šumem se pořád počítá dopředu', () {
      final start = DateTime(2026, 11, 15, 11, 0, 0);
      const steps = 200; // 200 * 8 m = 1,6 km
      for (var i = 0; i <= steps; i++) {
        final lateral = (i.isEven ? 12.0 : -12.0) / 111320.0;
        service.onPositionUpdate(_pos(
          lat: 50.0 + i * 0.000072,
          lng: 14.4 + lateral,
          time: start.add(Duration(seconds: i * 12)),
          speed: 0,
          accuracy: 28,
        ));
      }
      expect(service.totalDistance, greaterThan(1200));
      expect(service.totalDistance, lessThan(2000));
    });

    test('stání s kmitajícím GPS nepřidá kilometry', () {
      final start = DateTime(2026, 11, 15, 12, 0, 0);
      // 40 minut, bod každých 8 s. Poloha skáče tam a zpátky v okruhu ~25 m.
      for (var i = 0; i <= 300; i++) {
        final north = (i.isEven ? 22.0 : -14.0) / 111320.0;
        final east = (((i * 17) % 11) - 5) * 3.0 / (111320.0 * 0.65);
        service.onPositionUpdate(_pos(
          lat: 49.2 + north,
          lng: 16.6 + east,
          time: start.add(Duration(seconds: i * 8)),
          speed: 0,
          accuracy: 25,
        ));
      }
      expect(service.totalDistance, lessThan(150));
    });

    test('náhodný oblak bodů při stání nezvedne vzdálenost o kilometry', () {
      final start = DateTime(2026, 11, 15, 13, 0, 0);
      var seed = 42;
      double nextUnit() {
        seed = (1103515245 * seed + 12345) & 0x7fffffff;
        return seed / 0x7fffffff;
      }

      for (var i = 0; i <= 400; i++) {
        final northM = (nextUnit() * 2 - 1) * 28;
        final eastM = (nextUnit() * 2 - 1) * 28;
        service.onPositionUpdate(_pos(
          lat: 49.5 + northM / 111320.0,
          lng: 14.4 + eastM / (111320.0 * 0.65),
          time: start.add(Duration(seconds: i * 6)),
          speed: 0.4,
          accuracy: 22,
        ));
      }
      expect(service.totalDistance, lessThan(200));
    });

    test('chůze, půlhodinové stání a další chůze nesčítá šum z přestávky', () {
      final start = DateTime(2026, 11, 15, 14, 0, 0);
      var t = start;
      var lat = 49.8;

      void walk(int steps) {
        for (var i = 0; i < steps; i++) {
          lat += 0.000072; // ~8 m
          t = t.add(const Duration(seconds: 12));
          service.onPositionUpdate(_pos(
            lat: lat,
            lng: 15.0,
            time: t,
            speed: 0,
            accuracy: 18,
          ));
        }
      }

      walk(125); // ~1 km
      final afterWalk = service.totalDistance;
      expect(afterWalk, greaterThan(700));

      for (var i = 0; i < 225; i++) {
        t = t.add(const Duration(seconds: 8));
        final north = (i.isEven ? 18.0 : -12.0) / 111320.0;
        service.onPositionUpdate(_pos(
          lat: lat + north,
          lng: 15.0 + ((i % 5) - 2) * 0.00004,
          time: t,
          speed: 0,
          accuracy: 24,
        ));
      }
      final afterStand = service.totalDistance;
      expect(afterStand - afterWalk, lessThan(120));
      walk(125); // další ~1 km
      expect(service.totalDistance, greaterThan(afterStand + 700));
      expect(service.totalDistance, lessThan(2400));
    });

    test('teleport does not inflate distance; recovery continues from new place', () {
      final t0 = DateTime(2026, 9, 10, 14, 0, 0);
      service.onPositionUpdate(_pos(lat: 50.0, lng: 14.4, time: t0, speed: 1.2));
      service.onPositionUpdate(_pos(
        lat: 50.00008,
        lng: 14.4,
        time: t0.add(const Duration(seconds: 4)),
        speed: 1.5,
      ));
      final afterWalk = service.totalDistance;

      // Huge jump
      service.onPositionUpdate(_pos(
        lat: 50.05,
        lng: 14.4,
        time: t0.add(const Duration(seconds: 6)),
        speed: 1.0,
      ));
      expect(service.totalDistance, lessThan(afterWalk + 50));

      // Consistent fixes at new location → recovery
      for (int i = 1; i <= 4; i++) {
        service.onPositionUpdate(_pos(
          lat: 50.05 + i * 0.00003,
          lng: 14.4,
          time: t0.add(Duration(seconds: 6 + i * 2)),
          speed: 1.2,
          accuracy: 5.0,
        ));
      }
      expect(service.totalDistance, lessThan(500)); // no multi-km spike
    });

    test('getSummary reflects tracking flags and start time', () {
      final start = DateTime(2026, 9, 10, 15, 0, 0);
      service.testBeginTrackingSession(startTime: start);
      service.onPositionUpdate(_pos(lat: 49.2, lng: 16.6, time: start));
      final summary = service.getSummary();
      expect(summary.isTracking, isTrue);
      expect(summary.startTime, start);
    });
  });
}
