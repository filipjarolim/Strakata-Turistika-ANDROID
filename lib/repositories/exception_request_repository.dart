import 'dart:math';
import '../services/database/database_service.dart';
import '../models/exception_request.dart';

class ExceptionRequestRepository {
  final DatabaseService _dbService = DatabaseService();
  static const String _collectionName = 'exception_requests';

  String _generateObjectId() {
    final random = Random.secure();
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final timeHex = timestamp.toRadixString(16).padLeft(8, '0');
    final randomHex = List.generate(16, (_) => random.nextInt(16).toRadixString(16)).join();
    return '$timeHex$randomHex';
  }

  Future<List<ExceptionRequest>> getExceptionRequests(String userId) async {
    try {
      final results = await _dbService.find(
        _collectionName,
        {'userId': userId},
        sort: {'createdAt': -1},
      );
      final rawList = (results as List<dynamic>).cast<Map<String, dynamic>>();
      return rawList.map<ExceptionRequest>((map) => ExceptionRequest.fromMap(map)).toList();
    } catch (e) {
      print('❌ Error fetching exception requests: $e');
      return [];
    }
  }

  Future<bool> hasPendingRequest(String userId) async {
    try {
      final count = await _dbService.count(
        _collectionName,
        {'userId': userId, 'status': 'PENDING'},
      );
      return count > 0;
    } catch (_) {
      return false;
    }
  }

  Future<bool> createRequest(String userId, String reason, double requestedMinKm) async {
    try {
      final hasPending = await hasPendingRequest(userId);
      if (hasPending) {
        throw Exception('Již máte jednu nevyřízenou žádost.');
      }

      final id = _generateObjectId();
      final document = {
        '_id': id,
        'userId': userId,
        'reason': reason,
        'requestedMinKm': requestedMinKm,
        'status': 'PENDING',
        'adminResponse': null,
        'approvedById': null,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
      };

      final response = await _dbService.insertOne(_collectionName, document);
      return response != null;
    } catch (e) {
      print('❌ Error creating exception request: $e');
      rethrow;
    }
  }
}
