// Integrační test skutečného ukládacího toku mobilní aplikace:
// VisitData.toMap (DateTime pole) → DatabaseService ($date serializace)
// → /api/mobile/db (konverze na BSON Date) → ověření čtením zpět.
//
// Používá API_BASE_URL z .env (stejné jako produkční aplikace); pokud běží
// lokální web server (npm run dev v projektu MATURITNISTRAKATA), lze v .env
// nastavit http://localhost:3000/api.
// Spouštět: flutter test test/visit_save_integration_test.dart
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strakataturistikaandroidapp/models/visit_data.dart';
import 'package:strakataturistikaandroidapp/repositories/visit_repository.dart';
import 'package:strakataturistikaandroidapp/services/database/database_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    // flutter_test blokuje reálné HTTP mock klientem — pro integrační test
    // proti lokálnímu serveru ho vypneme.
    HttpOverrides.global = null;
    final envFile = File('.env').readAsStringSync();
    final apiKey = RegExp(r'MOBILE_API_KEY="(.+)"').firstMatch(envFile)!.group(1)!;
    final apiBaseUrl = RegExp(r'API_BASE_URL="(.+)"').firstMatch(envFile)!.group(1)!;
    dotenv.testLoad(fileInput: '''
API_BASE_URL="$apiBaseUrl"
MOBILE_API_KEY="$apiKey"
''');
  });

  test('uložení trasy přes bridge projde a datumy se uloží správně', () async {
    final repo = VisitRepository();

    final visit = VisitData(
      id: '',
      userId: null,
      year: DateTime.now().year,
      visitDate: DateTime(2026, 8, 8, 9, 30),
      createdAt: DateTime.now(),
      state: VisitState.DRAFT,
      points: 0,
      routeTitle: 'INTEGRATION TEST TRASA',
      routeDescription: 'Testovací záznam — bude smazán',
      visitedPlaces: '',
      photos: const [],
      places: const [],
      route: {
        'duration': 3600,
        'totalDistance': 4000.0,
        'trackPoints': [
          {'latitude': 50.0, 'longitude': 14.4, 'timestamp': '2026-08-08T09:30:00.000Z', 'speed': 1.2, 'accuracy': 5.0},
          {'latitude': 50.01, 'longitude': 14.41, 'timestamp': '2026-08-08T10:30:00.000Z', 'speed': 1.3, 'accuracy': 5.0},
        ],
      },
      extraData: const {},
      extraPoints: const {'source': 'gps_tracking'},
    );

    final savedId = await repo.saveVisit(visit);
    expect(savedId, isNotNull, reason: 'saveVisit musí vrátit id (dřív padal na jsonEncode DateTime)');

    final loaded = await repo.getVisitById(savedId!);
    expect(loaded, isNotNull);
    expect(loaded!.routeTitle, 'INTEGRATION TEST TRASA');
    expect(loaded.state, VisitState.DRAFT);
    expect(loaded.visitDate, isNotNull);
    expect(loaded.route?['totalDistance'], 4000.0);

    // PENDING_REVIEW update (stejný tok jako „Dokončit“ ve formuláři)
    final updated = visit.copyWith(id: savedId, state: VisitState.PENDING_REVIEW);
    final updatedId = await repo.saveVisit(updated);
    expect(updatedId, savedId);

    final afterUpdate = await repo.getVisitById(savedId);
    expect(afterUpdate!.state, VisitState.PENDING_REVIEW);
    expect(afterUpdate.route?['totalDistance'], 4000.0,
        reason: 'route se při přepisu DRAFT → PENDING nesmí ztratit');

    // Úklid
    final deleted = await repo.deleteVisit(savedId);
    expect(deleted, isTrue);

    await DatabaseService().close();
  }, timeout: const Timeout(Duration(minutes: 2)));
}
