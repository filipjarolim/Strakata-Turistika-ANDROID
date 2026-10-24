import 'package:flutter_test/flutter_test.dart';
import 'package:strakataturistikaandroidapp/utils/place_label.dart';
import 'package:strakataturistikaandroidapp/utils/published_standings.dart';
import 'package:strakataturistikaandroidapp/utils/season_year.dart';

void main() {
  test('evidenční číslo není název místa', () {
    expect(isHouseLikeLabel('ev. 16'), isTrue);
    expect(isHouseLikeLabel('16'), isTrue);
    expect(isHouseLikeLabel('č.p. 12'), isTrue);
    expect(isHouseLikeLabel('Benecko'), isFalse);
  });

  test('z adresy vezme obec a ze starého textu taky', () {
    expect(
      humanPlaceName(
        displayName: 'ev. 16, Benecko, okres Semily, Česko',
        address: const NominatimAddress(village: 'Benecko'),
      ),
      'Benecko',
    );
    expect(friendlyPlaceTitle('ev. 16, Horní Lánov, okres Trutnov, Česko'), 'Horní Lánov');
    expect(
      humanPlaceName(
        name: 'Sněžka',
        address: const NominatimAddress(peak: 'Sněžka', village: 'Pec pod Sněžkou'),
      ),
      'Sněžka',
    );
  });

  test('listopad patří do sezóny dalšího roku', () {
    expect(seasonEndingYear(DateTime(2025, 10, 31)), 2025);
    expect(seasonEndingYear(DateTime(2025, 11, 1)), 2026);
    expect(seasonEndingYear(DateTime(2026, 1, 18)), 2026);
    expect(seasonEndingYear(DateTime(2026, 11, 1)), 2027);
  });

  test('zveřejněné pořadí drží sloupec Pořadí i když má první méně bodů', () {
    final page = pagePublishedStandings(
      rows: const [
        PublishedStanding(name: 'Druhý', points: 500, rank: 2),
        PublishedStanding(name: 'První', points: 10, rank: 1),
      ],
      page: 1,
      limit: 10,
    );
    final names = (page['data'] as List).map((row) => row['displayName']).toList();
    expect(names, ['První', 'Druhý']);
  });
}
