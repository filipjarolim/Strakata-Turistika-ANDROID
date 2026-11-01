/// Web (`resolveParticipantName`) prázdné a zástupné jméno přeskočí.
bool isUsableParticipantName(String value) {
  switch (value.trim().toLowerCase()) {
    case '':
    case 'unknown user':
    case 'neznámý':
    case 'neznámý turista':
    case 'neznámý uživatel':
      return false;
    default:
      return true;
  }
}

class LeaderboardEntry {
  final String userId; // may be a real userId or a display key (full name) for legacy
  final String userName;
  final String? userImage;
  final String? dogName;
  final double totalPoints;
  final int visitsCount;
  final DateTime? lastVisitDate;

  LeaderboardEntry({
    required this.userId,
    required this.userName,
    required this.totalPoints,
    required this.visitsCount,
    this.userImage,
    this.dogName,
    this.lastVisitDate,
  });

  factory LeaderboardEntry.fromMap(Map<String, dynamic> map) {
    // Aggregation returns `userDoc` from $lookup on `users`; legacy payloads may use `user`.
    final rawUser = map['user'] ?? map['userDoc'];
    final user = rawUser is Map ? Map<String, dynamic>.from(rawUser) : null;
    final String displayName = (map['displayName'] ?? '').toString();
    final String accountName = (user?['name'] ?? '').toString();
    final String explicitName = (map['userName'] ?? '').toString();
    return LeaderboardEntry(
      userId: (map['userId'] ?? map['firstUserId'] ?? map['_id'] ?? '').toString(),
      userName: _firstUsableName([accountName, explicitName, displayName]),
      userImage: user?['image']?.toString(),
      dogName: _firstFilled([map['dogName'], user?['dogName']]),
      totalPoints: _parsePointsDouble(map['totalPoints']) ?? 0.0,
      visitsCount: _parseInt(map['visitsCount']) ?? 0,
      lastVisitDate: map['lastVisitDate'] != null
          ? (map['lastVisitDate'] is DateTime
              ? map['lastVisitDate'] as DateTime
              : DateTime.tryParse(map['lastVisitDate'].toString()))
          : null,
    );
  }

  static String _firstUsableName(List<String> candidates) {
    for (final candidate in candidates) {
      if (isUsableParticipantName(candidate)) return candidate.trim();
    }
    for (final candidate in candidates) {
      final trimmed = candidate.trim();
      if (trimmed.isNotEmpty) return trimmed;
    }
    return '';
  }

  static String? _firstFilled(List<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  static double? _parsePointsDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    final s = value.toString();
    final d = double.tryParse(s);
    if (d != null) return double.parse(d.toStringAsFixed(1)); // Round to 1 decimal place
    return null;
  }
}

