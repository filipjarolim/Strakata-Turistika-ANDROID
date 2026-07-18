enum ExceptionStatus {
  pending,
  approved,
  rejected,
}

class ExceptionRequest {
  final String id;
  final String userId;
  final String reason;
  final double requestedMinKm;
  final ExceptionStatus status;
  final String? adminResponse;
  final DateTime createdAt;

  ExceptionRequest({
    required this.id,
    required this.userId,
    required this.reason,
    required this.requestedMinKm,
    required this.status,
    this.adminResponse,
    required this.createdAt,
  });

  factory ExceptionRequest.fromMap(Map<String, dynamic> map) {
    // Parse status
    ExceptionStatus statusVal = ExceptionStatus.pending;
    final statusStr = map['status']?.toString().toUpperCase();
    if (statusStr == 'APPROVED') {
      statusVal = ExceptionStatus.approved;
    } else if (statusStr == 'REJECTED') {
      statusVal = ExceptionStatus.rejected;
    }

    // Parse date
    DateTime dateVal = DateTime.now();
    if (map['createdAt'] != null) {
      if (map['createdAt'] is Map && map['createdAt']['\$date'] != null) {
        dateVal = DateTime.parse(map['createdAt']['\$date'].toString());
      } else {
        dateVal = DateTime.parse(map['createdAt'].toString());
      }
    }

    return ExceptionRequest(
      id: map['_id'] ?? map['id'] ?? '',
      userId: map['userId'] ?? '',
      reason: map['reason'] ?? '',
      requestedMinKm: (map['requestedMinKm'] as num?)?.toDouble() ?? 1.5,
      status: statusVal,
      adminResponse: map['adminResponse'],
      createdAt: dateVal.toLocal(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'reason': reason,
      'requestedMinKm': requestedMinKm,
      'status': status.toString().split('.').last.toUpperCase(),
      'adminResponse': adminResponse,
      'createdAt': createdAt.toUtc().toIso8601String(),
    };
  }
}
