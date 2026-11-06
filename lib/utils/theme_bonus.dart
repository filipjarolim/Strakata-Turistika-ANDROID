import '../models/visit_data.dart';

/// Stejné pravidlo jako web (`lib/visits/theme-scoring.ts` a `theme-bonus.ts`).
/// Slovo se hledá v názvu a popisu místa a v popisu trasy. Typ místa TÉMA/TEMA3
/// neurčuje část. První nové slovo měsíce je 1. část, další 2. část, poslední
/// 3. část (bod za slovo + bonus za dokončení). Už zaplacená slova se nepočítají.
const themeSlotIds = {'TÉMA', 'TEMA', 'TEMA1', 'TEMA2', 'TEMA3'};

class PragueCalendarDate {
  final int year;
  final int month;
  final int day;

  const PragueCalendarDate(this.year, this.month, this.day);
}

int _lastSunday(int year, int month) {
  final last = DateTime.utc(year, month + 1, 0);
  final back = last.weekday == DateTime.sunday ? 0 : last.weekday;
  return last.day - back;
}

/// Kalendářní datum v Evropě/Praze. Stejné přelomy měsíce jako web.
PragueCalendarDate pragueDate(DateTime instant) {
  final utc = instant.toUtc();
  final start = DateTime.utc(utc.year, 3, _lastSunday(utc.year, 3), 1);
  final end = DateTime.utc(utc.year, 10, _lastSunday(utc.year, 10), 1);
  final dst = !utc.isBefore(start) && utc.isBefore(end);
  final wall = utc.add(Duration(hours: dst ? 2 : 1));
  return PragueCalendarDate(wall.year, wall.month, wall.day);
}

bool isThemeSlotPlace(Place place) {
  final typeKey = place.type.trim().toUpperCase();
  final idKey = place.id.trim().toUpperCase();
  return themeSlotIds.contains(typeKey) || themeSlotIds.contains(idKey);
}

bool textMatchesKeyword(String text, String keyword) {
  if (keyword.isEmpty) return false;
  if (keyword.length <= 2) {
    final escaped = RegExp.escape(keyword);
    final regex = RegExp(
      '(?:^|[^\\p{L}\\p{N}])$escaped(?:\$|[^\\p{L}\\p{N}])',
      unicode: true,
    );
    return regex.hasMatch(text);
  }
  return text.contains(keyword);
}

class ThemeBonusResult {
  final double bonus;
  final List<String> matchedKeywords;

  const ThemeBonusResult({required this.bonus, required this.matchedKeywords});
}

ThemeBonusResult computeVisitThemeBonus({
  required List<String> monthlyThemeKeywords,
  required List<Place> places,
  String? routeDescription,
  List<String> completedThemeKeywords = const [],
  bool historyAmbiguous = false,
  double keywordPoint = 1,
  double allKeywordsBonus = 2,
}) {
  if (historyAmbiguous) {
    return const ThemeBonusResult(bonus: 0, matchedKeywords: []);
  }
  final normalized = monthlyThemeKeywords
      .map((keyword) => keyword.toLowerCase().trim())
      .where((keyword) => keyword.isNotEmpty)
      .toList();
  if (normalized.isEmpty) {
    return const ThemeBonusResult(bonus: 0, matchedKeywords: []);
  }

  final matched = <String>{};
  void collect(String text) {
    for (final keyword in normalized) {
      if (textMatchesKeyword(text, keyword)) {
        matched.add(keyword);
        continue;
      }
      if (keyword.contains('/')) {
        final parts = keyword
            .split('/')
            .map((part) => part.trim())
            .where((part) => part.isNotEmpty);
        if (parts.any((part) => textMatchesKeyword(text, part))) {
          matched.add(keyword);
        }
      }
    }
  }

  for (final place in places) {
    collect('${place.name} ${place.description}'.toLowerCase());
  }
  if (routeDescription != null && routeDescription.trim().isNotEmpty) {
    collect(routeDescription.toLowerCase());
  }

  final completed = <String>{};
  for (final keyword in completedThemeKeywords) {
    final normalizedCompleted = keyword.toLowerCase().trim();
    if (normalized.contains(normalizedCompleted)) completed.add(normalizedCompleted);
  }
  final slots = places.where(isThemeSlotPlace).length;
  final named = matched.where((keyword) => !completed.contains(keyword)).length;
  var missing = slots - named;
  if (missing > 0) {
    for (final keyword in normalized) {
      if (missing <= 0) break;
      if (matched.contains(keyword) || completed.contains(keyword)) continue;
      matched.add(keyword);
      missing -= 1;
    }
  }

  final fresh = matched.where((keyword) => !completed.contains(keyword)).toList();
  if (fresh.isEmpty) {
    return const ThemeBonusResult(bonus: 0, matchedKeywords: []);
  }
  final covered = {...fresh, ...completed};
  final newlyComplete =
      covered.length >= normalized.length && completed.length < normalized.length;
  final perKeyword = keywordPoint.isFinite && keywordPoint >= 0 ? keywordPoint : 1.0;
  final completion = allKeywordsBonus.isFinite && allKeywordsBonus >= 0 ? allKeywordsBonus : 2.0;
  final bonus = fresh.length * perKeyword + (newlyComplete ? completion : 0);
  return ThemeBonusResult(bonus: bonus, matchedKeywords: fresh);
}
