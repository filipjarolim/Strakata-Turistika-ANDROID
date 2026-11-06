import '../services/competition_dashboard_service.dart';
import '../services/database/database_service.dart';
import '../utils/type_converter.dart';
import 'theme_bonus.dart';

class ThemeMonthHistory {
  final List<String> keywords;
  final bool ambiguous;

  const ThemeMonthHistory({required this.keywords, required this.ambiguous});

  static const empty = ThemeMonthHistory(keywords: [], ambiguous: false);
}

DateTime? readVisitInstant(dynamic value) {
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  if (value is Map && value['\$date'] != null) {
    return DateTime.tryParse(value['\$date'].toString());
  }
  return null;
}

/// Schválené výlety stejného uživatele v pražském měsíci data návštěvy.
/// Stejná historie, podle které web nepočítá slovo podruhé.
Future<ThemeMonthHistory> loadThemeMonthHistory({
  required String userId,
  required DateTime visitDate,
  String? excludeVisitId,
  DatabaseService? database,
}) async {
  if (userId.isEmpty) return ThemeMonthHistory.empty;
  final month = pragueDate(visitDate);
  final rows = await (database ?? DatabaseService()).find(
    'visits',
    {'userId': userId, 'state': 'APPROVED'},
    limit: 400,
  );
  final keywords = <String>{};
  var ambiguous = false;
  for (final row in rows) {
    final id = (row['_id'] ?? row['id'] ?? '').toString();
    if (excludeVisitId != null && excludeVisitId.isNotEmpty && id == excludeVisitId) {
      continue;
    }
    final instant = readVisitInstant(row['visitDate']);
    if (instant == null) continue;
    final rowMonth = pragueDate(instant);
    if (rowMonth.year != month.year || rowMonth.month != month.month) continue;
    final extra = row['extraPoints'];
    if (extra is! Map) continue;
    final bonus = TypeConverter.toDouble(extra['themeBonus']);
    if (bonus == null || !bonus.isFinite || bonus <= 0) continue;
    final matched = extra['themeKeywordsMatched'];
    final list = matched is List
        ? matched
            .map((item) => item.toString().trim().toLowerCase())
            .where((item) => item.isNotEmpty)
            .toList()
        : const <String>[];
    if (list.isEmpty) {
      ambiguous = true;
      continue;
    }
    keywords.addAll(list);
  }
  return ThemeMonthHistory(keywords: keywords.toList(), ambiguous: ambiguous);
}

Future<List<String>> loadMonthlyThemeKeywords(DateTime visitDate) async {
  final theme = await CompetitionDashboardService().getCurrentMonthlyTheme(forDate: visitDate);
  return theme?.keywords ?? const [];
}
