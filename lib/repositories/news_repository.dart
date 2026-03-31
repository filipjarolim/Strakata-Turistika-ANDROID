import '../services/database/database_service.dart';
import '../models/news_item.dart';
import 'package:mongo_dart/mongo_dart.dart';

class NewsRepository {
  final DatabaseService _dbService = DatabaseService();
  static const String _collectionName = 'news';

  /// Fetch news with pagination, filtering, and sorting
  Future<Map<String, dynamic>> getNews({
    int page = 1,
    int limit = 20,
    String? searchQuery,
    bool onlyPublished = false,
  }) async {
    return _dbService.execute((db) async {
      final collection = db.collection(_collectionName);
      final query = where;

      if (onlyPublished) {
        query.eq('status', 'PUBLISHED');
      }

      if (searchQuery != null && searchQuery.isNotEmpty) {
        final regex = '.*$searchQuery.*';
        final options = 'i';
        query.raw({
          '\$or': [
            {'title': {'\$regex': regex, '\$options': options}},
            {'content': {'\$regex': regex, '\$options': options}},
            {'tags': {'\$regex': regex, '\$options': options}},
          ]
        });
      }

      // Sort by publish date for public, created date for admin
      if (onlyPublished) {
        query.sortBy('publishDate', descending: true);
      } else {
        query.sortBy('createdAt', descending: true);
      }
      
      query.skip((page - 1) * limit).limit(limit);

      final totalCount = await collection.count(query);
      final docs = await collection.find(query).toList();
      final news = docs.map((doc) => NewsItem.fromMap(doc)).toList();

      return {
        'data': news,
        'total': totalCount,
        'hasMore': (page * limit) < totalCount,
      };
    }).catchError((e) {
      print('❌ [NewsRepository] Error fetching news: $e');
      return {'data': <NewsItem>[], 'total': 0};
    });
  }

  /// Get active news count
  Future<int> getActiveNewsCount() async {
    return _dbService.execute((db) async {
      final collection = db.collection(_collectionName);
      return await collection.count(where.eq('status', 'PUBLISHED'));
    }).catchError((e) => 0);
  }

  /// Save a news item (Create or Update)
  Future<bool> saveNews(NewsItem news) async {
    return _dbService.execute((db) async {
      final collection = db.collection(_collectionName);
      final data = news.toMap();
      
      if (news.id.isEmpty) {
        data['_id'] = ObjectId().toHexString();
        data['createdAt'] = DateTime.now();
        // If creating as published, set publish date
        if (news.status == NewsStatus.PUBLISHED && news.publishDate == null) {
          data['publishDate'] = DateTime.now();
        }
      } else {
        data['_id'] = news.id;
        data['updatedAt'] = DateTime.now();
        // If changing to published, set publish date if not set
        if (news.status == NewsStatus.PUBLISHED && news.publishDate == null) {
          data['publishDate'] = DateTime.now();
        }
      }
      
      await collection.update(where.eq('_id', data['_id']), data, upsert: true);
      return true;
    }).catchError((e) {
      print('❌ [NewsRepository] Error saving news: $e');
      return false;
    });
  }

  /// Delete a news item
  Future<bool> deleteNews(String id) async {
    return _dbService.execute((db) async {
      final collection = db.collection(_collectionName);
      await collection.remove(where.eq('_id', id));
      return true;
    }).catchError((e) {
      print('❌ [NewsRepository] Error deleting news: $e');
      return false;
    });
  }
}
