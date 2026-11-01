import 'package:flutter_test/flutter_test.dart';
import 'package:strakataturistikaandroidapp/models/leaderboard_entry.dart';

void main() {
  test('prázdné jméno účtu nesmí schovat jméno z výsledků', () {
    final entry = LeaderboardEntry.fromMap({
      'userId': 'u1',
      'displayName': 'Močkořovi',
      'user': {'name': ''},
      'totalPoints': 12,
      'visitsCount': 1,
    });

    expect(entry.userName, 'Močkořovi');
  });

  test('zástupné Neznámý ustoupí jménu z účtu', () {
    final entry = LeaderboardEntry.fromMap({
      'userId': 'u1',
      'displayName': 'Neznámý',
      'user': {'name': 'Močkořovi'},
      'totalPoints': 12,
      'visitsCount': 1,
    });

    expect(entry.userName, 'Močkořovi');
  });
}
