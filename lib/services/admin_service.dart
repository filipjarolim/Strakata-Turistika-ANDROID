import '../repositories/visit_repository.dart';
import '../repositories/news_repository.dart';
import '../services/database/database_service.dart';
import 'package:mongo_dart/mongo_dart.dart';

class AdminService {
  final VisitRepository _visitRepository = VisitRepository();
  final NewsRepository _newsRepository = NewsRepository();
  final DatabaseService _dbService = DatabaseService();

  /// Get aggregated stats for the dashboard
  Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      // Run in parallel for performance
      final results = await Future.wait([
        _visitRepository.getVisits(limit: 1, onlyApproved: false), // To count pending/total. This implementation is suboptimal, better to add specific count methods
        _newsRepository.getActiveNewsCount(),
        _getTotalUsersCount(),
      ]);

      // Optimization: We need specific counts, getVisits returns all. 
      // Let's implement specific count queries here or add them to repositories.
      // For now, let's use direct DB calls for counts to be efficient.
      
      int pendingVisits = await _getPendingVisitsCount();
      int activeNews = results[1] as int;
      int totalUsers = results[2] as int;

      return {
        'pendingVisits': pendingVisits,
        'activeNews': activeNews,
        'totalUsers': totalUsers,
      };
    } catch (e) {
      print('❌ [AdminService] Error fetching dashboard stats: $e');
      return {
        'pendingVisits': 0,
        'activeNews': 0,
        'totalUsers': 0,
      };
    }
  }

  Future<int> _getPendingVisitsCount() async {
    return _dbService.execute((db) async {
      return await db.collection('visits').count(where.eq('state', 'PENDING_REVIEW'));
    }).catchError((_) => 0);
  }

  Future<int> _getTotalUsersCount() async {
    return _dbService.execute((db) async {
      return await db.collection('users').count();
    }).catchError((_) => 0);
  }
}
