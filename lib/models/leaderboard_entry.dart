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
    final user = (map['user'] ?? map['userDoc']) as Map<String, dynamic>?;
    final String displayName = (map['displayName'] ?? '').toString();
    return LeaderboardEntry(
      userId: (map['userId'] ?? map['firstUserId'] ?? map['_id'] ?? '').toString(),
      userName: (user != null ? (user['name'] ?? '') : displayName).toString(),
      userImage: user?['image']?.toString(),
      dogName: user?['dogName']?.toString(),
      totalPoints: _parsePointsDouble(map['totalPoints']) ?? 0.0,
      visitsCount: _parseInt(map['visitsCount']) ?? 0,
      lastVisitDate: map['lastVisitDate'] != null
          ? (map['lastVisitDate'] is DateTime
              ? map['lastVisitDate'] as DateTime
              : DateTime.tryParse(map['lastVisitDate'].toString()))
          : null,
    );
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

