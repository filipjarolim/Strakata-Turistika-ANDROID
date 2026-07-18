import 'dart:math';
import '../services/database/database_service.dart';
import '../models/visit_data.dart';
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
      if (seasonYear != null) query['seasonYear'] = seasonYear;
      if (userId != null) query['userId'] = userId;
      
      // Handle state filtering logic
      if (states != null && states.isNotEmpty) {
        query['state'] = {'\$in': states.map((s) => s.name).toList()};
      } else if (onlyApproved) {
        query['state'] = 'APPROVED';
      }

      if (searchQuery != null && searchQuery.isNotEmpty) {
        final regex = '.*$searchQuery.*';
        final options = 'i';
        query['\$or'] = [
          {'routeTitle': {'\$regex': regex, '\$options': options}},
          {'visitedPlaces': {'\$regex': regex, '\$options': options}},
          {'fullName': {'\$regex': regex, '\$options': options}},
          {'extraPoints.fullName': {'\$regex': regex, '\$options': options}},
          {'extraPoints.Příjmení a jméno': {'\$regex': regex, '\$options': options}},
        ];
      }

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
      final pipeline = <Map<String, Object>>[
        {
          '\$match': {
            'seasonYear': season,
            'state': 'APPROVED',
          }
        },
        {
          '\$addFields': {
            'groupKey': {
               '\$ifNull': ['\$userId', {'\$ifNull': ['\$extraPoints.fullName', '\$fullName', 'Neznámý']}]
            },
            'normalizedName': {
               '\$ifNull': ['\$extraPoints.fullName', {'\$ifNull': ['\$fullName', 'Neznámý']}]
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
          }
        },
        {
          '\$lookup': {
            'from': 'users',
            'localField': 'userId',
            'foreignField': '_id',
            'as': 'userDocs'
          }
        },
        {
          '\$addFields': {
            'userDoc': {'\$first': '\$userDocs'},
          }
        },
        {
          '\$addFields': {
            'displayName': {
              '\$ifNull': ['\$userDoc.name', '\$legacyName']
            }
          }
        },
        if (searchQuery != null && searchQuery.isNotEmpty) 
          {
            '\$match': {
              'displayName': {'\$regex': searchQuery, '\$options': 'i'}
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

    final strakataId = visit.extraPoints['strakataRouteId']?.toString().trim();
    if (strakataId != null && strakataId.isNotEmpty) {
      data['strakataTrasaId'] = strakataId;
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
        data['createdAt'] = DateTime.now().toIso8601String();
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

      await _dbService.updateOne(
        _collectionName,
        {'_id': idToPersist},
        {'\$set': data},
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
      return null;
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
            'updatedAt': DateTime.now().toIso8601String(),
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
      final updateFields = {
        'state': newState.name,
        'updatedAt': DateTime.now().toIso8601String(),
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
            'updatedAt': DateTime.now().toIso8601String(),
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
