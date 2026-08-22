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

class CompetitionDashboardService {
  static final CompetitionDashboardService _instance = CompetitionDashboardService._internal();
  factory CompetitionDashboardService() => _instance;
  CompetitionDashboardService._internal();

  final DatabaseService _db = DatabaseService();

  /// Téma měsíce podle [forDate] (výchozí = dnes). Při dodatečném doplňování
  /// výletu se předává datum návštěvy, aby se načetlo téma správného měsíce.
  Future<MonthlyThemeData?> getCurrentMonthlyTheme({DateTime? forDate}) async {
    final date = forDate ?? DateTime.now();
    try {
      final doc = await _db.findOne('monthly_themes', {
        'year': date.year,
        'month': date.month,
      });
      if (doc == null) return null;
      final rawKeywords = doc['keywords'] as List<dynamic>? ?? const [];
      final keywords = rawKeywords
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
      return MonthlyThemeData(
        year: TypeConverter.toInt(doc['year']) ?? date.year,
        month: TypeConverter.toInt(doc['month']) ?? date.month,
        keywords: keywords,
      );
    } catch (_) {
      return null;
    }
  }
}
