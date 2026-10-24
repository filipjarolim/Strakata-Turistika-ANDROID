import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:strakataturistikaandroidapp/models/forms/form_config.dart';
import 'package:strakataturistikaandroidapp/models/forms/form_context.dart';
import 'package:strakataturistikaandroidapp/models/place_type_config.dart';
import 'package:strakataturistikaandroidapp/models/tracking_summary.dart';
import 'package:strakataturistikaandroidapp/models/visit_data.dart';
import 'package:strakataturistikaandroidapp/services/auth_service.dart';
import 'package:strakataturistikaandroidapp/services/scoring_config_service.dart';
import 'package:strakataturistikaandroidapp/utils/visit_submit.dart';
import 'package:strakataturistikaandroidapp/widgets/forms/form_field_validator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  User user({String id = 'user-1', String? dogName = 'Rex'}) {
    return User(
      id: id,
      email: 'walker@example.com',
      name: 'Walker',
      isOAuth: true,
      provider: 'google',
      providerAccountId: 'google-sub',
      dogName: dogName,
    );
  }

  ScoringConfig scoring({double minDistanceKm = 3}) {
    return ScoringConfig(
      id: 'scoring',
      pointsPerKm: 2,
      minDistanceKm: minDistanceKm,
      requireAtLeastOnePlace: false,
      placeTypePoints: const {'PEAK': 5},
      active: true,
      updatedAt: DateTime(2026, 1, 1),
    );
  }

  PlaceTypeConfig placeType(String name, int points) {
    final at = DateTime(2026, 1, 1);
    return PlaceTypeConfig(
      id: name,
      name: name,
      label: name,
      icon: Icons.place,
      points: points,
      color: const Color(0xFF4CAF50),
      order: 0,
      createdAt: at,
      updatedAt: at,
    );
  }

  TrackingSummary track({
    required double meters,
    int points = 2,
    Duration duration = const Duration(minutes: 40),
  }) {
    final start = DateTime(2026, 8, 8, 9);
    return TrackingSummary(
      isTracking: false,
      startTime: start,
      duration: duration,
      totalDistance: meters,
      averageSpeed: 1.2,
      maxSpeed: 1.8,
      totalElevationGain: 10,
      totalElevationLoss: 4,
      minAltitude: 200,
      maxAltitude: 220,
      trackPoints: List.generate(
        points,
        (i) => TrackPoint(
          latitude: 50 + i * 0.01,
          longitude: 14.4,
          timestamp: start.add(Duration(minutes: i * 10)),
          speed: 1.2,
          accuracy: 5,
        ),
      ),
    );
  }

  Place peak(String type) {
    return Place(
      id: 'p1',
      name: 'Boubín',
      type: type,
      photos: const [],
      createdAt: DateTime(2026, 8, 8),
    );
  }

  VisitData submit({
    required String slug,
    User? asUser,
    TrackingSummary? summary,
    Map<String, dynamic> extraData = const {},
    List<Place> places = const [],
    List<Map<String, dynamic>>? photos,
    VisitData? existingVisit,
    DateTime? visitDate,
    String? routeTitle = 'Výlet na Boubín',
    bool dogNotAllowed = false,
    ScoringConfig? scoringConfig,
    List<PlaceTypeConfig> placeTypes = const [],
  }) {
    return buildPendingVisit(
      slug: slug,
      user: asUser ?? user(),
      visitDate: visitDate ?? DateTime(2026, 8, 8, 9),
      routeTitle: routeTitle,
      routeDescription: 'les',
      dogNotAllowed: dogNotAllowed,
      extraData: extraData,
      places: places,
      summary: summary,
      scoring: scoringConfig ?? scoring(),
      placeTypes: placeTypes,
      photos: photos,
      existingVisit: existingVisit,
    );
  }

  group('přihlášení', () {
    test('e-mail a registrace v aplikaci neprojdou', () async {
      final signIn = await AuthService.signInWithCredentials('a@b.c', 'tajne');
      final signUp = await AuthService.signUpWithCredentials('a@b.c', 'tajne', 'A');
      expect(signIn.success, isFalse);
      expect(signIn.error, contains('Google'));
      expect(signUp.success, isFalse);
      expect(signUp.error, contains('Google'));
    });

    test('prázdné id není přihlášený uživatel', () {
      AuthService.updateCurrentUser(user(id: ''));
      expect(AuthService.isLoggedIn, isFalse);
      expect(
        () => ensureVisitCanBeSaved(
          slug: 'gps-tracking',
          user: AuthService.currentUser,
          summary: track(meters: 4000),
          newPhotoCount: 0,
          existingPhotoCount: 0,
        ),
        throwsA(predicate((e) => e.toString().contains('přihlásit'))),
      );
    });

    test('odhlášení smaže uloženou session i když Google plugin selže', () async {
      SharedPreferences.setMockInitialValues({
        'user_session': jsonEncode(user().toMap()),
      });
      AuthService.updateCurrentUser(user());
      expect(AuthService.isLoggedIn, isTrue);

      await AuthService.signOut();

      expect(AuthService.currentUser, isNull);
      expect(AuthService.isLoggedIn, isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('user_session'), isNull);
    });

    test('session uživatele přežije uložení a načtení včetně _id', () {
      final restored = User.fromMap(user().toMap());
      expect(restored.id, 'user-1');
      expect(restored.email, 'walker@example.com');
      expect(restored.dogName, 'Rex');

      final fromMongo = User.fromMap({
        '_id': 'abc123',
        'email': 'walker@example.com',
        'name': 'Walker',
      });
      expect(fromMongo.id, 'abc123');
      expect(fromMongo.provider, 'google');
    });
  });

  group('záznam po přihlášení', () {
    test('bez uživatele nejde uložit žádný typ', () {
      for (final slug in ['gps-tracking', 'gpx-upload', 'screenshot-upload']) {
        expect(
          () => ensureVisitCanBeSaved(
            slug: slug,
            user: null,
            summary: track(meters: 5000),
            newPhotoCount: 1,
            existingPhotoCount: 0,
          ),
          throwsA(predicate((e) => e.toString().contains('přihlásit'))),
        );
      }
    });

    test('GPS trasa nad minimem jde k revizi s body a uživatelem', () {
      final visit = submit(
        slug: 'gps-tracking',
        summary: track(meters: 4200),
        places: [peak('vrchol')],
        placeTypes: [placeType('vrchol', 4)],
        dogNotAllowed: true,
      );

      expect(visit.userId, 'user-1');
      expect(visit.user?['email'], 'walker@example.com');
      expect(visit.state, VisitState.PENDING_REVIEW);
      expect(visit.extraPoints['source'], 'gps_tracking');
      expect(visit.formSlug, 'gps-tracking');
      expect(visit.distanceKm, closeTo(4.2, 1e-9));
      expect(visit.points, closeTo(12.4, 1e-9));
      expect(visit.year, 2026);
      expect(visit.dogNotAllowed, 'true');
      expect(visit.dogName, 'Rex');
      expect(visit.route?['totalDistance'], 4200);
      expect(visit.routeLink, contains('50.0'));
      expect(visit.visitedPlaces, 'Boubín');
      expect(visit.durationMinutes, 40);
    });

    test('GPS pod minimem uloží km, ale body za vzdálenost jsou 0', () {
      final visit = submit(
        slug: 'gps-tracking',
        summary: track(meters: 2500),
      );
      expect(visit.distanceKm, closeTo(2.5, 1e-9));
      expect(visit.points, 0);
      expect(meetsStoredSource(visit, 'gps_tracking'), isTrue);
    });

    test('GPS a GPX bez dvou bodů se neuloží', () {
      for (final slug in ['gps-tracking', 'gpx-upload']) {
        expect(
          () => submit(slug: slug, summary: track(meters: 5000, points: 1)),
          throwsA(predicate((e) => e.toString().contains('GPS/GPX'))),
        );
        expect(
          () => submit(slug: slug),
          throwsA(predicate((e) => e.toString().contains('GPS/GPX'))),
        );
      }
    });

    test('GPX upload nese zdroj gpx a sezónu od listopadu', () {
      final visit = submit(
        slug: 'gpx-upload',
        summary: track(meters: 3000),
        visitDate: DateTime(2026, 11, 2),
        extraData: {'dog_name': 'Alík'},
      );
      expect(visit.extraPoints['source'], 'gpx_upload');
      expect(visit.formSlug, 'gpx-upload');
      expect(visit.year, 2027);
      expect(visit.dogName, 'Alík');
      expect(visit.points, closeTo(6, 1e-9));
    });

    test('screenshot s ručními km a fotkou jde k revizi', () {
      final visit = submit(
        slug: 'screenshot-upload',
        extraData: {'distanceKm': '5,5'},
        photos: [
          {'url': 'https://cdn.example/shot.jpg'},
        ],
      );
      expect(visit.extraPoints['source'], 'screenshot');
      expect(visit.formSlug, 'screenshot-upload');
      expect(visit.distanceKm, closeTo(5.5, 1e-9));
      expect(visit.points, closeTo(11, 1e-9));
      expect(visit.route, isNull);
      expect(visit.photos, hasLength(1));
    });

    test('screenshot bez dokladu se neuloží', () {
      expect(
        () => submit(
          slug: 'screenshot-upload',
          extraData: {'distance': '4'},
        ),
        throwsA(predicate((e) => e.toString().contains('screenshot'))),
      );
    });

    test('úprava screenshotu s už uloženou fotkou novou fotku nevyžaduje', () {
      final existing = VisitData(
        id: 'visit-9',
        points: 1,
        visitedPlaces: '',
        year: 2026,
        extraPoints: {'source': 'screenshot', 'note': 'keep'},
        photos: [
          {'url': 'https://cdn.example/old.jpg'},
        ],
        createdAt: DateTime(2026, 5, 1),
        distanceKm: 4,
      );

      final visit = submit(
        slug: 'screenshot-upload',
        extraData: {'distanceKm': 4},
        existingVisit: existing,
      );

      expect(visit.id, 'visit-9');
      expect(visit.photos, [
        {'url': 'https://cdn.example/old.jpg'},
      ]);
      expect(visit.extraPoints['note'], 'keep');
      expect(visit.extraPoints['source'], 'screenshot');
      expect(visit.createdAt, DateTime(2026, 5, 1));
      expect(visit.state, VisitState.PENDING_REVIEW);
    });

    test('neznámý typ místa vezme body z konfigurace a neblokuje uložení', () {
      final visit = submit(
        slug: 'gps-tracking',
        summary: track(meters: 3000),
        places: [peak('PEAK')],
      );
      expect(visit.points, closeTo(11, 1e-9));
    });
  });

  group('kroky formuláře před odesláním', () {
    test('GPX krok vyžaduje trasu, screenshot krok fotku', () {
      final form = FormContext();
      expect(
        validateFormField(
          form,
          FormFieldWidget(
            id: 'gpx',
            type: 'gpx_upload',
            label: 'GPX',
            order: 0,
            required: true,
          ),
        ),
        contains('dvěma body'),
      );
      form.setTrackingSummary(track(meters: 3000));
      expect(
        validateFormField(
          form,
          FormFieldWidget(
            id: 'gpx',
            type: 'gpx_upload',
            label: 'GPX',
            order: 0,
            required: true,
          ),
        ),
        isNull,
      );

      expect(
        validateFormField(
          form,
          FormFieldWidget(
            id: 'shot',
            type: 'image_upload',
            label: 'Screenshot',
            order: 1,
            required: true,
          ),
        ),
        contains('fotografii'),
      );
    });

    test('krok edit vyžaduje název a vyplněná místa', () {
      final form = FormContext();
      form.updateField('routeTitle', 'ab');
      expect(validateEditStep(form), contains('3 znaky'));
      form.updateField('routeTitle', 'Boubín');
      form.updatePlaces([
        Place(
          id: 'x',
          name: '  ',
          type: 'OTHER',
          photos: const [],
          createdAt: DateTime(2026, 8, 8),
        ),
      ]);
      expect(validateEditStep(form), contains('název'));
    });
  });
}

bool meetsStoredSource(VisitData visit, String source) {
  return visit.extraPoints['source'] == source;
}
