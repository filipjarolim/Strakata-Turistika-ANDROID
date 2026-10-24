/// Sezóna pojmenovaná rokem ukončení, stejně jako web (`getSeasonEndingYearForVisitDate`).
/// Začíná 1. listopadu předchozího roku a končí 31. října.
/// Sezóna 2026 = 1. 11. 2025 – 31. 10. 2026. Od 1. 11. 2026 běží sezóna 2027.
int seasonEndingYear(DateTime date) {
  return date.month >= 11 ? date.year + 1 : date.year;
}

/// Veřejný výběr sezón: aktuální ročník je vždy v seznamu, budoucí ne.
/// Nejnovější (běžící) sezóna je první.
List<int> seasonsShownForResults(Iterable<int> seasonYears, DateTime now) {
  final current = seasonEndingYear(now);
  final years = <int>{current};
  for (final year in seasonYears) {
    if (year > 2000 && year <= current) years.add(year);
  }
  final list = years.toList()..sort((a, b) => b.compareTo(a));
  return list;
}
