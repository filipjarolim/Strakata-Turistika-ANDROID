import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strakataturistikaandroidapp/models/place_type_config.dart';
import 'package:strakataturistikaandroidapp/models/tracking_summary.dart';
import 'package:strakataturistikaandroidapp/models/visit_data.dart';
import 'package:strakataturistikaandroidapp/services/auth_service.dart';
import 'package:strakataturistikaandroidapp/services/scoring_config_service.dart';
import 'package:strakataturistikaandroidapp/utils/theme_bonus.dart';
import 'package:strakataturistikaandroidapp/utils/visit_submit.dart';

void main() {
  const keywords = [
    'Božena / Němcová',
    'splav / myslivec / Viktorka',
    'babička / Barunka / kněžna',
  ];

  Place place(String name, {String type = 'PEAK', String description = ''}) {
    return Place(
      id: 'p1',
      name: name,
      type: type,
      photos: const [],
      description: description,
      createdAt: DateTime(2026, 11, 6),
    );
  }

  ThemeBonusResult bonus({
    List<Place> places = const [],
    String? routeDescription,
    List<String> completed = const [],
    bool ambiguous = false,
  }) {
    return computeVisitThemeBonus(
      monthlyThemeKeywords: keywords,
      places: places,
      routeDescription: routeDescription,
      completedThemeKeywords: completed,
      historyAmbiguous: ambiguous,
    );
  }

  test('půlnoc UTC 31. října je v Praze už listopad', () {
    final date = pragueDate(DateTime.utc(2026, 10, 31, 23, 30));
    expect(date.year, 2026);
    expect(date.month, 11);
    expect(date.day, 1);
  });

  test('krátké slovo sedí jen jako celé slovo', () {
    expect(textMatchesKeyword('místo x u lesa', 'x'), isTrue);
    expect(textMatchesKeyword('místo xa', 'x'), isFalse);
    expect(textMatchesKeyword('u babičky', 'babička'), isFalse);
    expect(textMatchesKeyword('rozcestí babička', 'babička'), isTrue);
  });

  test('první slovo z třetího řádku je 1. část za 1 bod', () {
    final result = bonus(places: [place('Rozcestí babička', type: 'TEMA3')]);
    expect(result.bonus, 1);
    expect(result.matchedKeywords, ['babička / barunka / kněžna']);
  });

  test('typ tématu bez slova v textu je 0', () {
    expect(bonus(places: [place('Kladno', type: 'TEMA3')]).bonus, 0);
  });

  test('lomítko bere kteroukoliv variantu a popis trasy taky', () {
    expect(bonus(places: [place('U splavu')]).bonus, 1);
    expect(bonus(routeDescription: 'zastávka Němcová').bonus, 1);
  });

  test('dvě nová slova jsou 2 body, všechna tři 5 a poslední 3', () {
    expect(
      bonus(places: [place('Statek', description: 'myslivec a babička')]).bonus,
      2,
    );
    expect(
      bonus(places: [place('Statek', description: 'božena myslivec babička')]).bonus,
      5,
    );
    final last = bonus(
      places: [place('Statek babička')],
      completed: [
        'božena / němcová',
        'splav / myslivec / viktorka',
      ],
    );
    expect(last.bonus, 3);
    expect(last.matchedKeywords, ['babička / barunka / kněžna']);
  });

  test('už zaplacené slovo a nejasná historie jsou 0', () {
    expect(
      bonus(
        places: [place('Rozcestí babička')],
        completed: ['babička / barunka / kněžna'],
      ).bonus,
      0,
    );
    expect(
      bonus(places: [place('Rozcestí babička')], ambiguous: true).bonus,
      0,
    );
  });

  test('odeslaný výlet má stejný součet jako web a slot tématu se nepřičte', () {
    final start = DateTime(2026, 11, 6, 9);
    final visit = buildPendingVisit(
      slug: 'gps-tracking',
      user: User(
        id: 'user-1',
        email: 'walker@example.com',
        name: 'Walker',
        isOAuth: true,
        provider: 'google',
        providerAccountId: 'sub',
      ),
      visitDate: start,
      routeTitle: 'Výlet',
      routeDescription: '',
      dogNotAllowed: false,
      extraData: const {},
      places: [place('Rozcestí babička', type: 'TEMA3')],
      summary: TrackingSummary(
        isTracking: false,
        startTime: start,
        duration: const Duration(minutes: 40),
        totalDistance: 4200,
        averageSpeed: 1,
        maxSpeed: 1,
        totalElevationGain: 0,
        totalElevationLoss: 0,
        minAltitude: 0,
        maxAltitude: 0,
        trackPoints: [
          TrackPoint(latitude: 50, longitude: 14, timestamp: start, speed: 1, accuracy: 5),
          TrackPoint(
            latitude: 50.02,
            longitude: 14.02,
            timestamp: start.add(const Duration(minutes: 40)),
            speed: 1,
            accuracy: 5,
          ),
        ],
      ),
      scoring: ScoringConfig(
        id: 's',
        pointsPerKm: 2,
        minDistanceKm: 3,
        requireAtLeastOnePlace: true,
        placeTypePoints: const {'TEMA3': 2, 'PEAK': 4},
        active: true,
        updatedAt: start,
      ),
      placeTypes: [
        PlaceTypeConfig(
          id: 'TEMA3',
          name: 'TEMA3',
          label: '3. část',
          icon: Icons.place,
          points: 2,
          color: const Color(0xFF4CAF50),
          order: 0,
          createdAt: start,
          updatedAt: start,
        ),
      ],
      photos: null,
      monthlyThemeKeywords: keywords,
    );

    // 4,2 km × 2 = 8,4 a první nové slovo = 1. Bod za typ TEMA3 se nepřičte.
    expect(visit.points, closeTo(9.4, 1e-9));
    expect(visit.extraPoints['themeScoring'], 'text-v1');
    expect(visit.extraPoints['themeBonusIncluded'], 1);
    expect(visit.extraPoints.containsKey('themeBonus'), isFalse);
  });
}
