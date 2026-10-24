class PublishedStanding {
  final String name;
  final double points;
  final int? rank;
  final String? dogName;

  const PublishedStanding({
    required this.name,
    required this.points,
    this.rank,
    this.dogName,
  });
}

String foldPlaceName(String value) {
  const from = 'áčďéěíňóřšťúůýž';
  const to = 'acdeeinorstuuyz';
  final lower = value.toLowerCase();
  final buffer = StringBuffer();
  for (final char in lower.split('')) {
    final index = from.indexOf(char);
    buffer.write(index >= 0 ? to[index] : char);
  }
  return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Stejné pořadí jako web: tabulka podle sloupce Pořadí, jinak podle bodů.
Map<String, dynamic> pagePublishedStandings({
  required List<PublishedStanding> rows,
  required int page,
  required int limit,
  String? searchQuery,
  bool sortByVisits = false,
}) {
  final groups = <String, _StandingGroup>{};
  for (final row in rows) {
    final key = foldPlaceName(row.name);
    if (key.isEmpty) continue;
    final group = groups.putIfAbsent(key, () => _StandingGroup(row.name));
    group.points += row.points;
    group.count += 1;
    if (row.rank != null) {
      group.rank = group.rank == null ? row.rank : (row.rank! < group.rank! ? row.rank : group.rank);
    }
    if ((row.dogName ?? '').trim().isNotEmpty) group.dogName = row.dogName!.trim();
    if (row.name.trim().length > group.name.trim().length) group.name = row.name.trim();
  }

  var ordered = groups.values.toList();
  final query = (searchQuery ?? '').trim().toLowerCase();
  if (query.isNotEmpty) {
    ordered = ordered.where((group) => group.name.toLowerCase().contains(query)).toList();
  }
  final ranked = !sortByVisits && ordered.isNotEmpty && ordered.every((group) => group.rank != null);
  ordered.sort((a, b) {
    if (ranked && a.rank != b.rank) return a.rank!.compareTo(b.rank!);
    if (sortByVisits && a.count != b.count) return b.count.compareTo(a.count);
    if (a.points != b.points) return b.points.compareTo(a.points);
    return a.name.compareTo(b.name);
  });

  final total = ordered.length;
  final start = (page - 1) * limit;
  final slice = start >= ordered.length ? <_StandingGroup>[] : ordered.skip(start).take(limit);
  return {
    'data': slice
        .map(
          (group) => {
            '_id': foldPlaceName(group.name),
            'userId': '',
            'displayName': group.name,
            'dogName': group.dogName,
            'totalPoints': group.points,
            'visitsCount': group.count,
          },
        )
        .toList(),
    'total': total,
    'hasMore': page * limit < total,
  };
}

class _StandingGroup {
  String name;
  double points = 0;
  int count = 0;
  int? rank;
  String? dogName;

  _StandingGroup(this.name);
}
