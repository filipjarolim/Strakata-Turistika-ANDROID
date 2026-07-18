import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../error_recovery_service.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  bool _isConnected = false;
  String? _baseUrl;
  String? _apiKey;

  bool get isConnected => _isConnected;

  Future<bool> connect() async {
    try {
      await dotenv.load();
      _baseUrl = dotenv.env['API_BASE_URL']?.trim();
      _apiKey = dotenv.env['MOBILE_API_KEY']?.trim();

      if (_baseUrl == null || _baseUrl!.isEmpty) {
        print('❌ [DatabaseService] API_BASE_URL not found in .env');
        _isConnected = false;
        return false;
      }

      // Check if network is available
      final isOffline = !await ErrorRecoveryService().isNetworkAvailable();
      if (isOffline) {
        print('⚠️ [DatabaseService] Network unreachable (Offline Mode)');
        _isConnected = false;
        return false;
      }

      _isConnected = true;
      print('✅ [DatabaseService] REST API database bridge initialized (baseUrl=$_baseUrl)');
      return true;
    } catch (e) {
      print('❌ [DatabaseService] Initialization failed: $e');
      _isConnected = false;
      return false;
    }
  }

  Future<void> close() async {
    _isConnected = false;
  }

  Future<dynamic> _request(String action, String collection, Map<String, dynamic> bodyFields) async {
    if (_baseUrl == null || _apiKey == null) {
      final success = await connect();
      if (!success) {
        throw const SocketException('Nepodařilo se připojit k serveru. Zkontrolujte prosím své internetové připojení.');
      }
    }

    final isOffline = !await ErrorRecoveryService().isNetworkAvailable();
    if (isOffline) {
      _isConnected = false;
      throw const SocketException('Nepodařilo se připojit k internetu. Zkontrolujte prosím své připojení a zkuste to znovu.');
    }

    final url = Uri.parse('$_baseUrl/mobile/db');
    final headers = {
      'Content-Type': 'application/json',
      'x-mobile-api-key': _apiKey!,
    };

    final requestBody = {
      'collection': collection,
      'action': action,
      ...bodyFields,
    };

    try {
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true) {
          _isConnected = true;
          return responseData['result'];
        } else {
          throw Exception(responseData['error'] ?? 'Neznámá chyba na serveru');
        }
      } else if (response.statusCode == 401) {
        throw Exception('Chyba ověření API klíče (401 Unauthorized).');
      } else if (response.statusCode == 403) {
        throw Exception('Přístup ke kolekci "$collection" byl zamítnut (403 Forbidden).');
      } else {
        throw Exception('Server vrátil neočekávaný status kód: ${response.statusCode}');
      }
    } on TimeoutException {
      throw const SocketException('Připojení k serveru vypršelo. Zkontrolujte stabilitu internetu.');
    } on SocketException catch (e) {
      throw SocketException('Nepodařilo se navázat spojení se serverem: ${e.message}');
    } catch (e) {
      throw Exception('Chyba při komunikaci s databází: $e');
    }
  }

  Future<List<Map<String, dynamic>>> find(
    String collection,
    Map<String, dynamic> selector, {
    Map<String, dynamic>? sort,
    int? skip,
    int? limit,
  }) async {
    final body = <String, dynamic>{'selector': selector};
    if (sort != null) body['sort'] = sort;
    if (skip != null) body['skip'] = skip;
    if (limit != null) body['limit'] = limit;

    final rawResult = await _request('find', collection, body);
    if (rawResult is List) {
      return rawResult.map((item) => Map<String, dynamic>.from(item)).toList();
    }
    return [];
  }

  Future<Map<String, dynamic>?> findOne(
    String collection,
    Map<String, dynamic> selector,
  ) async {
    final rawResult = await _request('findOne', collection, {'selector': selector});
    if (rawResult != null) {
      return Map<String, dynamic>.from(rawResult);
    }
    return null;
  }

  Future<Map<String, dynamic>> insertOne(
    String collection,
    Map<String, dynamic> document,
  ) async {
    final rawResult = await _request('insertOne', collection, {'document': document});
    return Map<String, dynamic>.from(rawResult);
  }

  Future<Map<String, dynamic>> insertAll(
    String collection,
    List<Map<String, dynamic>> documents,
  ) async {
    final rawResult = await _request('insertMany', collection, {'documents': documents});
    return Map<String, dynamic>.from(rawResult);
  }

  Future<Map<String, dynamic>> updateOne(
    String collection,
    Map<String, dynamic> selector,
    Map<String, dynamic> update, {
    bool upsert = false,
  }) async {
    final rawResult = await _request('updateOne', collection, {
      'selector': selector,
      'update': update,
      'upsert': upsert,
    });
    return Map<String, dynamic>.from(rawResult);
  }

  Future<Map<String, dynamic>> updateMany(
    String collection,
    Map<String, dynamic> selector,
    Map<String, dynamic> update,
  ) async {
    final rawResult = await _request('updateMany', collection, {
      'selector': selector,
      'update': update,
    });
    return Map<String, dynamic>.from(rawResult);
  }

  Future<Map<String, dynamic>> deleteOne(
    String collection,
    Map<String, dynamic> selector,
  ) async {
    final rawResult = await _request('deleteOne', collection, {'selector': selector});
    return Map<String, dynamic>.from(rawResult);
  }

  Future<Map<String, dynamic>> deleteMany(
    String collection,
    Map<String, dynamic> selector,
  ) async {
    final rawResult = await _request('deleteMany', collection, {'selector': selector});
    return Map<String, dynamic>.from(rawResult);
  }

  Future<int> count(
    String collection,
    Map<String, dynamic> selector,
  ) async {
    final rawResult = await _request('count', collection, {'selector': selector});
    if (rawResult is int) return rawResult;
    return int.tryParse(rawResult.toString()) ?? 0;
  }

  Future<List<Map<String, dynamic>>> aggregate(
    String collection,
    List<Map<String, dynamic>> pipeline,
  ) async {
    final rawResult = await _request('aggregate', collection, {'pipeline': pipeline});
    if (rawResult is List) {
      return rawResult.map((item) => Map<String, dynamic>.from(item)).toList();
    }
    return [];
  }
}
