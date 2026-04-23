import 'database/database_service.dart';
import '../utils/type_converter.dart';

class MonthlyThemeData {
  final int year;
  final int month;
  final List<String> keywords;

  const MonthlyThemeData({
    required this.year,
    required this.month,
    required this.keywords,
  });
}

class StrakataRouteData {
  final String id;
  final String label;
  final String icon;
  final int order;

  const StrakataRouteData({
    required this.id,
    required this.label,
    required this.icon,
    required this.order,
  });
}

class CompetitionDashboardService {
  static final CompetitionDashboardService _instance = CompetitionDashboardService._internal();
  factory CompetitionDashboardService() => _instance;
  CompetitionDashboardService._internal();

  final DatabaseService _db = DatabaseService();

  Future<MonthlyThemeData?> getCurrentMonthlyTheme() async {
    final now = DateTime.now();
    return _db.execute((db) async {
      final collection = db.collection('monthly_themes');
      final doc = await collection.findOne({
        'year': now.year,
        'month': now.month,
      });
      if (doc == null) return null;
      final rawKeywords = doc['keywords'] as List<dynamic>? ?? const [];
      final keywords = rawKeywords
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
      return MonthlyThemeData(
        year: TypeConverter.toInt(doc['year']) ?? now.year,
        month: TypeConverter.toInt(doc['month']) ?? now.month,
        keywords: keywords,
      );
    }).catchError((_) => null);
  }

  Future<List<StrakataRouteData>> getActiveStrakataRoutes() async {
    return _db.execute((db) async {
      final collection = db.collection('strakata_trasy');
      final docs = await collection.find({'isActive': true}).toList();
      final items = docs
          .map(
            (doc) => StrakataRouteData(
              id: doc['_id']?.toString() ?? doc['id']?.toString() ?? '',
              label: doc['label']?.toString() ?? doc['name']?.toString() ?? 'Strakatá trasa',
              icon: doc['icon']?.toString() ?? '🧭',
                      order: TypeConverter.toInt(doc['order']) ?? 999,
            ),
          )
          .where((e) => e.id.isNotEmpty)
          .toList();
      items.sort((a, b) => a.order.compareTo(b.order));
      return items;
    }).catchError((_) => <StrakataRouteData>[]);
  }
}
