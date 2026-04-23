// Spustit z kořene projektu (stejná složka jako .env):
//   flutter test test/visit_pipeline_smoke_test.dart
//
// Volitelně ověření přes Prisma (stejný stack jako admin na webu):
//   MATURITNISTRAKATA_ROOT=/cesta/k/MATURITNISTRAKATA flutter test test/visit_pipeline_smoke_test.dart
//
// Ověří: připojení k Mongo, načtení formulářů z `form_configs`, zápis a čtení z `visits`,
// úklid testovacího záznamu. Při selhání `saveVisit` zkontroluj log (replaceOne / writeError).

import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:test/test.dart';
import 'package:strakataturistikaandroidapp/models/visit_data.dart';
import 'package:strakataturistikaandroidapp/repositories/visit_repository.dart';
import 'package:strakataturistikaandroidapp/services/database/database_service.dart';
import 'package:strakataturistikaandroidapp/services/form_service.dart';

void main() {
  // Nepoužívat TestWidgetsFlutterBinding — mockuje HttpClient a rozbije mongo_dart (400).

  group('Visit pipeline smoke (Mongo + form_configs + visits)', () {
    setUpAll(() async {
      await dotenv.load(fileName: '.env');
      final ok = await DatabaseService().connect();
      if (!ok) {
        fail(
          'DatabaseService.connect() failed. Nastav DATABASE_URL v .env v kořeni projektu.',
        );
      }
    });

    tearDownAll(() async {
      await DatabaseService().close();
    });

    test('FormService načte stejné slugy jako web (kolekce form_configs)', () async {
      for (final slug in ['screenshot-upload', 'gpx-upload', 'gps-tracking']) {
        final cfg = await FormService().getFormBySlug(slug);
        expect(cfg, isNotNull, reason: 'form $slug — getFormBySlug');
        final c = cfg!;
        expect(c.steps, isNotEmpty, reason: 'form $slug má mít alespoň jeden krok');
        final upload = c.steps.where((s) => s.id == 'upload').toList();
        expect(
          upload.isNotEmpty || c.steps.length == 1,
          isTrue,
          reason: 'očekává se krok upload nebo jednokrokový formulář ($slug)',
        );
      }
    });

    test('saveVisit zapíše dokument, getVisitById ho přečte, deleteVisit smaže', () async {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final visit = VisitData(
        id: '',
        visitDate: DateTime.now(),
        routeTitle: 'SMOKE_PIPELINE_$ts',
        routeDescription: 'Automatický test — bezpečně smazat.',
        points: 1.0,
        visitedPlaces: 'Smoke místo',
        year: DateTime.now().year,
        extraPoints: {
          'source': 'screenshot',
          'distance': 5.2,
          'distanceKm': 5.2,
          'elapsedTime': 90,
        },
        extraData: {
          'distance': '5.2',
          'duration': '90',
        },
        places: [
          Place(
            id: 'smoke-p-$ts',
            name: 'Smoke vrchol',
            type: 'OTHER',
            photos: [
              PlacePhoto(
                id: 'smoke-ph-$ts',
                url: 'https://res.cloudinary.com/demo/image/upload/sample.jpg',
                uploadedAt: DateTime.now().toUtc(),
                publicId: 'smoke/$ts',
              ),
            ],
            createdAt: DateTime.now().toUtc(),
          ),
        ],
        state: VisitState.PENDING_REVIEW,
        photos: [
          {
            'url': 'https://res.cloudinary.com/demo/image/upload/sample.jpg',
            'public_id': 'smoke_route/$ts',
          },
        ],
        routeLink: jsonEncode([
          {'lat': 50.08, 'lng': 14.42},
          {'lat': 50.081, 'lng': 14.421},
        ]),
        distanceKm: 5.2,
        durationMinutes: 90,
      );

      final id = await VisitRepository().saveVisit(visit);
      expect(
        id,
        isNotNull,
        reason:
            'saveVisit vrátil null — v konzoli hledej [VisitRepository] saveVisit: replaceOne selhalo',
      );
      expect(id, isNotEmpty);

      // Stejná logika jako `app/api/admin/[collection]/route.ts` pro VisitData:
      // jen PENDING_REVIEW | APPROVED | REJECTED a bez smazaných (deletedAt null / chybí).
      await DatabaseService().execute((db) async {
        final col = db.collection('visits');
        final adminStyle = {
          '\$and': [
            {'_id': id},
            {
              'state': {
                '\$in': ['PENDING_REVIEW', 'APPROVED', 'REJECTED'],
              },
            },
            {
              '\$or': [
                {'deletedAt': null},
                {'deletedAt': {'\$exists': false}},
              ],
            },
          ],
        };
        final row = await col.findOne(adminStyle);
        expect(
          row,
          isNotNull,
          reason:
              'záznam po uložení neprojde admin-style filtrem (stav / deletedAt) — v admin dashboard by nebyl vidět',
        );
        expect(row!['seasonYear'], visit.year);
        expect(row['state'], 'PENDING_REVIEW');
      });

      // Volitelně: stejná DB přes Prisma jako Next admin (`VisitData`).
      final prismaRoot = Platform.environment['MATURITNISTRAKATA_ROOT']?.trim();
      if (prismaRoot != null && prismaRoot.isNotEmpty) {
        final sep = Platform.pathSeparator;
        final scriptPath = '$prismaRoot${sep}scripts${sep}prisma-find-visit-by-id.mjs';
        final r = Process.runSync(
          'node',
          [scriptPath, id!],
          workingDirectory: prismaRoot,
          environment: Map<String, String>.from(Platform.environment),
        );
        expect(
          r.exitCode,
          0,
          reason:
              'Prisma nenašla záznam (exit ${r.exitCode}). stdout=${r.stdout} stderr=${r.stderr}',
        );
        expect(r.stdout.toString(), contains('OK'));
      }

      final back = await VisitRepository().getVisitById(id!);
      expect(back, isNotNull, reason: 'dokument po zápisu v kolekci visits nešel přečíst');
      expect(back!.routeTitle, visit.routeTitle);

      final removed = await VisitRepository().deleteVisit(id);
      expect(removed, isTrue);

      final gone = await VisitRepository().getVisitById(id);
      expect(gone, isNull);
    });

    test('replaceOne přímo: minimální dokument do visits (diagnostika)', () async {
      final id = ObjectId().oid;
      await DatabaseService().execute((db) async {
        final col = db.collection('visits');
        final doc = <String, dynamic>{
          '_id': id,
          'visitDate': DateTime.now().toIso8601String(),
          'routeTitle': 'SMOKE_RAW_$id',
          'routeDescription': '',
          'dogName': null,
          'points': 0.1,
          'visitedPlaces': '',
          'routeLink': null,
          'route': null,
          'distanceKm': 1.0,
          'durationMinutes': 10,
          'seasonYear': DateTime.now().year,
          'extraPoints': {'source': 'screenshot'},
          'extraData': null,
          'places': [],
          'state': 'DRAFT',
          'rejectionReason': null,
          'createdAt': DateTime.now().toIso8601String(),
          'photos': null,
          'seasonId': null,
          'userId': null,
          'isFreeCategory': false,
        };
        doc.removeWhere((_, v) => v == null);

        final wr = await col.replaceOne(where.eq('_id', id), doc, upsert: true);
        expect(
          wr.isSuccess,
          isTrue,
          reason:
              'přímý replaceOne do visits selhal: err=${wr.writeError?.errmsg} wc=${wr.writeConcernError?.errmsg}',
        );

        final read = await col.findOne(where.eq('_id', id));
        expect(read, isNotNull);
        await col.remove(where.eq('_id', id));
      });
    });
  });
}
