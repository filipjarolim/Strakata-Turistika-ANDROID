import 'dart:math';
import '../services/database/database_service.dart';
import '../models/visit_data.dart';
import '../utils/published_standings.dart';
import '../utils/type_converter.dart';

class VisitRepository {
  final DatabaseService _dbService = DatabaseService();

  /// Musí odpovídat Prisma `VisitData` → `@@map("visits")` (stejná DB jako web).
  static const String _collectionName = 'visits';

  // Helper to generate 24-char hex MongoDB ObjectId
  String _generateObjectId() {
    final random = Random.secure();
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final timeHex = timestamp.toRadixString(16).padLeft(8, '0');
    final randomHex = List.generate(16, (_) => random.nextInt(16).toRadixString(16)).join();
    return '$timeHex$randomHex';
  }

  static String _escapeRegex(String input) {
    return input.replaceAllMapped(
      RegExp(r'[.*+?^${}()|[\]\\]'),
      (m) => '\\${m[0]}',
    );
  }

  /// Fetch visits with pagination, filtering, and sorting
  Future<Map<String, dynamic>> getVisits({
    int page = 1,
    int limit = 20,
    int? seasonYear,
    String? searchQuery,
    String? userId,
    bool onlyApproved = true,
    List<VisitState>? states, // New: Filter by specific states
  }) async {
    try {
      final query = <String, dynamic>{};
      final and = <Map<String, dynamic>>[];
      if (seasonYear != null) {
        and.add({
          '\$or': [
            {'seasonYear': seasonYear},
            {'year': seasonYear},
          ],
        });
      }
      if (userId != null) query['userId'] = userId;
      
      // Handle state filtering logic
      if (states != null && states.isNotEmpty) {
        query['state'] = {'\$in': states.map((s) => s.name).toList()};
      } else if (onlyApproved) {
        query['state'] = 'APPROVED';
      }

      if (searchQuery != null && searchQuery.isNotEmpty) {
        final trimmed = searchQuery.trim();
        final clipped = trimmed.length > 80 ? trimmed.substring(0, 80) : trimmed;
        final safe = _escapeRegex(clipped);
        if (safe.isNotEmpty) {
          final regex = '.*$safe.*';
          const options = 'i';
          and.add({
            '\$or': [
              {'routeTitle': {'\$regex': regex, '\$options': options}},
              {'visitedPlaces': {'\$regex': regex, '\$options': options}},
              {'fullName': {'\$regex': regex, '\$options': options}},
              {'extraPoints.fullName': {'\$regex': regex, '\$options': options}},
              {'extraPoints.Příjmení a jméno': {'\$regex': regex, '\$options': options}},
            ],
          });
        }
      }
      if (onlyApproved) {
        final testingIds = await _testingSeasonIds();
        if (testingIds.isNotEmpty) {
          and.add({'seasonId': {'\$nin': testingIds}});
        }
      }
      if (and.isNotEmpty) query['\$and'] = and;

      final totalCount = await _dbService.count(_collectionName, query);
      final docs = await _dbService.find(
        _collectionName, 
        query,
        sort: {'visitDate': -1},
        skip: (page - 1) * limit,
        limit: limit,
      );
      final visits = docs.map((doc) => VisitData.fromMap(doc)).toList();

      return {
        'data': visits,
        'total': totalCount,
        'hasMore': (page * limit) < totalCount,
      };
    } catch (e) {
      print('❌ [VisitRepository] Error fetching visits: $e');
      return {'data': <VisitData>[], 'total': 0, 'hasMore': false};
    }
  }

  /// Get leaderboard data (aggregated points per user)
  Future<Map<String, dynamic>> getLeaderboard({
    required int season,
    int page = 1,
    int limit = 50,
    String? searchQuery,
    bool sortByVisits = false,
  }) async {
    try {
      final fromSheet = await _leaderboardFromPublishedSheet(
        season: season,
        page: page,
        limit: limit,
        searchQuery: searchQuery,
        sortByVisits: sortByVisits,
      );
      if (fromSheet != null) return fromSheet;

      final testingIds = await _testingSeasonIds();
      final pipeline = <Map<String, Object>>[
        {
          '\$match': {
            '\$or': [
              {'seasonYear': season},
              {'year': season},
            ],
            'state': 'APPROVED',
            if (testingIds.isNotEmpty) 'seasonId': {'\$nin': testingIds},
          }
        },
        {
          '\$addFields': {
            'groupKey': {
               '\$ifNull': ['\$userId', {'\$ifNull': ['\$extraPoints.fullName', '\$fullName', 'Neznámý']}]
            },
            'normalizedName': {
               '\$ifNull': ['\$user.name', {'\$ifNull': ['\$extraPoints.fullName', {'\$ifNull': ['\$fullName', 'Neznámý']}]}]
            }
          }
        },
        {
          '\$group': {
            '_id': '\$groupKey',
            'totalPoints': {'\$sum': {'\$ifNull': ['\$points', '\$extraPoints.Body', '\$extraPoints.points', 0]}},
            'visitsCount': {'\$sum': 1},
            'lastVisitDate': {'\$max': {'\$ifNull': ['\$visitDate', '\$createdAt']}},
            'userId': {'\$first': '\$userId'},
            'legacyName': {'\$first': '\$normalizedName'},
            'user': {'\$first': '\$user'},
            'dogName': {'\$first': '\$dogName'},
          }
        },
        {
          '\$addFields': {
            'displayName': {
              '\$ifNull': ['\$user.name', '\$legacyName']
            },
            'dogName': {
              '\$ifNull': ['\$user.dogName', '\$dogName']
            }
          }
        },
        if (searchQuery != null && searchQuery.isNotEmpty) 
          {
            '\$match': {
              'displayName': {'\$regex': _escapeRegex(searchQuery), '\$options': 'i'}
            }
          },
        {
          '\$sort': {
            sortByVisits ? 'visitsCount' : 'totalPoints': -1,
            'lastVisitDate': -1
          }
        },
        {
          '\$facet': {
            'metadata': [{'\$count': 'total'}],
            'data': [{'\$skip': (page - 1) * limit}, {'\$limit': limit}]
          }
        }
      ];

      final result = await _dbService.aggregate(_collectionName, pipeline);
      
      if (result.isEmpty) return {'data': [], 'total': 0, 'hasMore': false};

      final formattedResult = result.first;
      final metadata = (formattedResult['metadata'] as List).cast<Map>();
      final total = metadata.isNotEmpty ? (metadata.first['total'] ?? 0) : 0;
      final data = (formattedResult['data'] as List).cast<Map<String, dynamic>>();

      return {
        'data': data,
        'total': total,
        'hasMore': (page * limit) < total,
      };
    } catch (e) {
      print('❌ [VisitRepository] Error fetching leaderboard: $e');
      return {'data': [], 'total': 0, 'hasMore': false};
    }
  }

  Future<List<String>> _testingSeasonIds() async {
    try {
      final rows = await _dbService.find('seasons', {'isTesting': true}, limit: 50);
      return rows
          .map((row) => (row['_id'] ?? '').toString())
          .where((id) => id.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<Map<String, dynamic>?> _leaderboardFromPublishedSheet({
    required int season,
    required int page,
    required int limit,
    String? searchQuery,
    required bool sortByVisits,
  }) async {
    try {
      final docs = await _dbService.find(
        'season_standings',
        {'seasonYear': season},
        limit: 5000,
      );
      if (docs.isEmpty) return null;
      final rows = docs.map((doc) {
        final points = doc['points'];
        final rank = doc['rank'];
        return PublishedStanding(
          name: (doc['participantName'] ?? '').toString(),
          points: points is num ? points.toDouble() : double.tryParse('$points') ?? 0,
          rank: rank is num ? rank.toInt() : int.tryParse('$rank'),
          dogName: doc['dogName']?.toString(),
        );
      }).where((row) => row.name.trim().isNotEmpty).toList();
      if (rows.isEmpty) return null;
      return pagePublishedStandings(
        rows: rows,
        page: page,
        limit: limit,
        searchQuery: searchQuery,
        sortByVisits: sortByVisits,
      );
    } catch (_) {
      return null;
    }
  }

  /// Get distinct seasons available in the database
  Future<List<int>> getAvailableSeasons() async {
    try {
      final pipeline = [
        {'\$group': {'_id': '\$seasonYear'}},
        {'\$sort': {'_id': -1}}
      ];

      final result = await _dbService.aggregate(_collectionName, pipeline);
      
      return result.map((doc) {
        final val = doc['_id'];
        return TypeConverter.toIntWithDefault(val, 0);
      }).where((year) => year > 2000).toList();
    } catch (e) {
      print('❌ [VisitRepository] Error fetching seasons: $e');
      return <int>[];
    }
  }

  /// Get all visits for a specific user
  Future<List<VisitData>> getVisitsByUserId(String userId) async {
    // Reuse getVisits with high limit and specific filters
    final result = await getVisits(
      page: 1, 
      limit: 1000, 
      userId: userId, 
      onlyApproved: false // User wants to see ALL their visits including drafts/pending
    );
    return (result['data'] as List<dynamic>).cast<VisitData>();
  }

  static const Set<String> _mongoKeysPreserveOnUpdate = {
    'galleryImages',
    'strakataTrasaId',
    'strakataTrasaIcon',
    'isFreeCategory',
    'freeCategoryIcon',
    'deletedAt',
    'deletedBy',
    // Při přepisu DRAFT → PENDING může být route v paměti ztracený; bez toho replaceOne smaže polyline v DB.
    'route',
    'routeLink',
  };

  /// Sladění s Prisma modelem `VisitData` (`@@map("visits")`): odstraní pole, která Prisma
  /// v dokumentu nečeká (a mohla by rozbít validaci zápisu), doplní výchozí hodnoty.
  static void _prepareVisitDocumentForPrismaStorage(
    VisitData visit,
    Map<String, dynamic> data,
  ) {
    data.remove('user');
    data.remove('displayName');

    if (data.containsKey('dogNotAllowed')) {
      final dog = data.remove('dogNotAllowed');
      if (dog != null && '$dog'.isNotEmpty) {
        final ed = visit.extraData != null
            ? Map<String, dynamic>.from(visit.extraData!)
            : (data['extraData'] is Map
                ? Map<String, dynamic>.from(data['extraData'] as Map)
                : <String, dynamic>{});
        ed['dogNotAllowed'] = dog;
        data['extraData'] = ed;
      }
    }

    if (!data.containsKey('isFreeCategory') || data['isFreeCategory'] == null) {
      data['isFreeCategory'] = false;
    }

    data.removeWhere((_, v) => v == null);
  }

  /// Save a visit (Create or Update). Vrací `_id` dokumentu v MongoDB, nebo `null` při chybě.
  Future<String?> saveVisit(VisitData visit) async {
    try {
      final data = Map<String, dynamic>.from(visit.toMap());
      final String idToPersist;
      if (visit.id.isEmpty) {
        idToPersist = _generateObjectId();
        data['_id'] = idToPersist;
        data['createdAt'] = DateTime.now();
      } else {
        idToPersist = visit.id;
        data['_id'] = visit.id;
        final existing = await _dbService.findOne(_collectionName, {'_id': idToPersist});
        if (existing != null) {
          for (final key in _mongoKeysPreserveOnUpdate) {
            final hasIncoming = data.containsKey(key) && data[key] != null;
            if (!hasIncoming && existing[key] != null) {
              data[key] = existing[key];
            }
          }
        }
      }

      _prepareVisitDocumentForPrismaStorage(visit, data);

      // Poslední uživatelská úprava — web (admin) podle tohoto pole řadí a filtruje.
      data['lastEditedAt'] = DateTime.now();

      final setData = Map<String, dynamic>.from(data);
      setData.remove('_id');

      await _dbService.updateOne(
        _collectionName,
        {'_id': idToPersist},
        {'\$set': setData},
        upsert: true,
      );

      final verified = await _dbService.findOne(_collectionName, {'_id': idToPersist});
      if (verified == null) {
        print('❌ [VisitRepository] saveVisit: dokument po zápisu v DB nenalezen (_id=$idToPersist)');
        return null;
      }
      final st = verified['state']?.toString();
      if (st != null && visit.state.name.isNotEmpty && st != visit.state.name) {
        print(
          '⚠️ [VisitRepository] saveVisit: state v DB="$st" vs očekávaný="${visit.state.name}" (_id=$idToPersist)',
        );
      }

      return idToPersist;
    } catch (e) {
      print('❌ [VisitRepository] Error saving visit: $e');
      rethrow;
    }
  }

  Future<bool> updateVisitPoints(String visitId, double points, int peaksCount, int towersCount, int treesCount) async {
    try {
      await _dbService.updateOne(
        _collectionName,
        {'_id': visitId},
        {
          '\$set': {
            'points': points,
            'extraPoints.peaks': peaksCount,
            'extraPoints.towers': towersCount,
            'extraPoints.trees': treesCount,
            'extraPoints.points': points,
            'lastEditedAt': DateTime.now(),
          }
        }
      );
      return true;
    } catch (e) {
      print('❌ [VisitRepository] Error updating visit points: $e');
      return false;
    }
  }

  /// Delete a visit
  Future<bool> deleteVisit(String id) async {
    try {
      await _dbService.deleteOne(_collectionName, {'_id': id});
      return true;
    } catch (e) {
      print('❌ [VisitRepository] Error deleting visit: $e');
      return false;
    }
  }

  /// Get full visit detail by ID
  Future<VisitData?> getVisitById(String id) async {
    try {
      final doc = await _dbService.findOne(_collectionName, {'_id': id});
      if (doc == null) return null;
      return VisitData.fromMap(doc);
    } catch (e) {
      print('❌ [VisitRepository] Error fetching visit by id: $e');
      return null;
    }
  }

  /// Update the state of a visit (Admin)
  Future<bool> updateVisitState(String visitId, VisitState newState, {String? rejectionReason}) async {
    try {
      final updateFields = <String, dynamic>{
        'state': newState.name,
        'lastEditedAt': DateTime.now(),
      };
      if (rejectionReason != null) {
        updateFields['rejectionReason'] = rejectionReason;
      }
      
      await _dbService.updateOne(
        _collectionName,
        {'_id': visitId},
        {'\$set': updateFields}
      );
      
      return true;
    } catch (e) {
      print('❌ [VisitRepository] Error updating visit state: $e');
      return false;
    }
  }

  /// Bulk update visit states
  Future<int> bulkUpdateVisitStates(Iterable<String> ids, VisitState newState) async {
    try {
      await _dbService.updateMany(
        _collectionName,
        {'_id': {'\$in': ids.toList()}},
        {
          '\$set': {
            'state': newState.name,
            'lastEditedAt': DateTime.now(),
          }
        }
      );
      return ids.length;
    } catch (e) {
      print('❌ [VisitRepository] Error bulk updating visit states: $e');
      return 0;
    }
  }
}
