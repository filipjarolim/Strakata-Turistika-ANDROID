import 'package:shared_preferences/shared_preferences.dart';

class LoggingService {
  static final LoggingService _instance = LoggingService._internal();
  factory LoggingService() => _instance;
  LoggingService._internal();

  static const String _logKey = 'app_logs';
  static const int _maxLogEntries = 1000;

  Future<void> log(String message, {String? level, Map<String, dynamic>? data}) async {
    final timestamp = DateTime.now().toIso8601String();
    final logEntry = {
      'timestamp': timestamp,
      'level': level ?? 'INFO',
      'message': message,
      'data': data,
    };

    try {
      final prefs = await SharedPreferences.getInstance();
      final existingLogs = prefs.getStringList(_logKey) ?? [];
      
      // Add new log entry
      existingLogs.add(logEntry.toString());
      
      // Keep only the last N entries
      if (existingLogs.length > _maxLogEntries) {
        existingLogs.removeRange(0, existingLogs.length - _maxLogEntries);
      }
      
      await prefs.setStringList(_logKey, existingLogs);
    } catch (e) {
      print('Failed to save log: $e');
    }
  }

  Future<List<String>> getLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(_logKey) ?? [];
    } catch (e) {
      print('Failed to get logs: $e');
      return [];
    }
  }

  Future<void> clearLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_logKey);
    } catch (e) {
      print('Failed to clear logs: $e');
    }
  }

  Future<String> exportLogs() async {
    final logs = await getLogs();
    return logs.join('\n');
  }
} 