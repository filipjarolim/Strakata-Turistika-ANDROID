import '../services/database/database_service.dart';
import '../models/visit_data.dart';
import 'package:mongo_dart/mongo_dart.dart';
import '../utils/type_converter.dart';

class VisitRepository {
  final DatabaseService _dbService = DatabaseService();
  static const String _collectionName = 'visits';

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
    return _dbService.execute((db) async {
      final collection = db.collection(_collectionName);
      final query = where;
      if (seasonYear != null) query.eq('seasonYear', seasonYear);
      if (userId != null) query.eq('userId', userId);
      
      // Handle state filtering logic
      if (states != null && states.isNotEmpty) {
        query.oneFrom('state', states.map((s) => s.name).toList());
      } else if (onlyApproved) {
        query.eq('state', 'APPROVED');
      }

      if (searchQuery != null && searchQuery.isNotEmpty) {
        final regex = '.*$searchQuery.*';
        final options = 'i';
        query.raw({
          '\$or': [
            {'routeTitle': {'\$regex': regex, '\$options': options}},
            {'visitedPlaces': {'\$regex': regex, '\$options': options}},
            {'fullName': {'\$regex': regex, '\$options': options}},
            {'extraPoints.fullName': {'\$regex': regex, '\$options': options}},
            {'extraPoints.Příjmení a jméno': {'\$regex': regex, '\$options': options}},
          ]
        });
      }

      query.sortBy('visitDate', descending: true);
      query.skip((page - 1) * limit).limit(limit);

      final totalCount = await collection.count(query);
      final docs = await collection.find(query).toList();
      final visits = docs.map((doc) => VisitData.fromMap(doc)).toList();

      return {
        'data': visits,
        'total': totalCount,
        'hasMore': (page * limit) < totalCount,
      };
    }).catchError((e) {
      print('❌ [VisitRepository] Error fetching visits: $e');
      return {'data': <VisitData>[], 'total': 0};
    });
  }

  /// Get leaderboard data (aggregated points per user)
  Future<Map<String, dynamic>> getLeaderboard({
    required int season,
    int page = 1,
    int limit = 50,
    String? searchQuery,
    bool sortByVisits = false,
  }) async {
    return _dbService.execute((db) async {
      final collection = db.collection(_collectionName);
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

      final result = await collection.aggregateToStream(pipeline).toList();
      
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
    }).catchError((e) {
      print('❌ [VisitRepository] Error fetching leaderboard: $e');
      return {'data': [], 'total': 0, 'hasMore': false};
    });
  }

  /// Get distinct seasons available in the database
  Future<List<int>> getAvailableSeasons() async {
    return _dbService.execute((db) async {
      final collection = db.collection(_collectionName);
      final pipeline = [
        {'\$group': {'_id': '\$seasonYear'}},
        {'\$sort': {'_id': -1}}
      ];

      final result = await collection.aggregateToStream(pipeline).toList();
      
      return result.map((doc) {
        final val = doc['_id'];
        return TypeConverter.toIntWithDefault(val, 0);
      }).where((year) => year > 2000).toList();
    }).catchError((e) {
      print('❌ [VisitRepository] Error fetching seasons: $e');
      return <int>[];
    });
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

  /// Save a visit (Create or Update)
  Future<bool> saveVisit(VisitData visit) async {
    return _dbService.execute((db) async {
      final collection = db.collection(_collectionName);
      final data = visit.toMap();
      if (visit.id.isEmpty) {
        data['_id'] = ObjectId().toHexString();
        data['createdAt'] = DateTime.now();
      } else {
        data['_id'] = visit.id;
      }
      
      await collection.update(where.eq('_id', data['_id']), data, upsert: true);
      return true;
    }).catchError((e) {
      print('❌ [VisitRepository] Error saving visit: $e');
      return false;
    });
  }

  Future<bool> updateVisitPoints(String visitId, double points, int peaksCount, int towersCount, int treesCount) async {
    return _dbService.execute((db) async {
      final collection = db.collection(_collectionName);
      await collection.update(
        where.eq('_id', visitId),
        modify
          .set('points', points)
          .set('extraPoints.peaks', peaksCount)
          .set('extraPoints.towers', towersCount)
          .set('extraPoints.trees', treesCount)
          .set('extraPoints.points', points)
          .set('updatedAt', DateTime.now())
      );
      return true;
    }).catchError((e) {
      print('❌ [VisitRepository] Error updating visit points: $e');
      return false;
    });
  }

  /// Delete a visit
  Future<bool> deleteVisit(String id) async {
    return _dbService.execute((db) async {
      final collection = db.collection(_collectionName);
      await collection.remove(where.eq('_id', id));
      return true;
    }).catchError((e) {
      print('❌ [VisitRepository] Error deleting visit: $e');
      return false;
    });
  }

  /// Get full visit detail by ID
  Future<VisitData?> getVisitById(String id) async {
    return _dbService.execute((db) async {
      final collection = db.collection(_collectionName);
      final doc = await collection.findOne(where.eq('_id', id));
      if (doc == null) return null;
      return VisitData.fromMap(doc);
    }).catchError((e) {
      print('❌ [VisitRepository] Error fetching visit by id: $e');
      return null;
    });
  }

  /// Update the state of a visit (Admin)
  Future<bool> updateVisitState(String visitId, VisitState newState, {String? rejectionReason}) async {
    return _dbService.execute((db) async {
      final collection = db.collection(_collectionName);
      final modifier = modify.set('state', newState.name);
      if (rejectionReason != null) {
        modifier.set('rejectionReason', rejectionReason);
      }
      
      await collection.update(
        where.eq('_id', visitId),
        modifier
      );
      
      return true;
    }).catchError((e) {
      print('❌ [VisitRepository] Error updating visit state: $e');
      return false;
    });
  }

  /// Bulk update visit states
  Future<int> bulkUpdateVisitStates(Iterable<String> ids, VisitState newState) async {
    return _dbService.execute((db) async {
      final collection = db.collection(_collectionName);
      await collection.update(
        where.oneFrom('_id', ids.toList()),
        modify.set('state', newState.name).set('updatedAt', DateTime.now()),
        multiUpdate: true
      );
      return ids.length;
    }).catchError((e) {
      print('❌ [VisitRepository] Error bulk updating visit states: $e');
      return 0;
    });
  }
}
