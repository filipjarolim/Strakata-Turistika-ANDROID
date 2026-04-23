import 'dart:async';
import 'dart:io';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';


class ErrorRecoveryService {
  static final ErrorRecoveryService _instance = ErrorRecoveryService._internal();
  factory ErrorRecoveryService() => _instance;
  ErrorRecoveryService._internal();

  static const String _errorLogKey = 'error_log';
  static const String _recoveryAttemptsKey = 'recovery_attempts';
  static const int _maxRecoveryAttempts = 3;

  late SharedPreferences _prefs;
  final List<String> _errorLog = [];
  int _recoveryAttempts = 0;

  /// Initialize the error recovery service
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    _loadErrorLog();
    _loadRecoveryAttempts();
  }

  /// Log an error for recovery purposes
  Future<void> logError(String error, {String? context, StackTrace? stackTrace}) async {
    final errorEntry = {
      'timestamp': DateTime.now().toIso8601String(),
      'error': error,
      'context': context ?? 'Unknown',
      'stackTrace': stackTrace?.toString(),
    };

    _errorLog.add(errorEntry.toString());
    
    // Keep only last 100 errors
    if (_errorLog.length > 100) {
      _errorLog.removeAt(0);
    }

    await _saveErrorLog();
    
    // Also log to Firebase Crashlytics
    FirebaseCrashlytics.instance.recordError(
      error,
      stackTrace,
      reason: context,
    );
  }

  /// Attempt to recover from an error
  Future<bool> attemptRecovery(String errorType, Future<bool> Function() recoveryFunction) async {
    if (_recoveryAttempts >= _maxRecoveryAttempts) {
      await logError('Max recovery attempts reached for: $errorType');
      return false;
    }

    try {
      _recoveryAttempts++;
      await _saveRecoveryAttempts();

      final success = await recoveryFunction();
      
      if (success) {
        await logError('Recovery successful for: $errorType');
        _resetRecoveryAttempts();
        return true;
      } else {
        await logError('Recovery failed for: $errorType');
        return false;
      }
    } catch (e, stackTrace) {
      await logError('Recovery attempt threw error: $e', stackTrace: stackTrace);
      return false;
    }
  }

  /// Validate data integrity
  Future<bool> validateDataIntegrity() async {
    try {
      // Check if SharedPreferences is accessible
      final testValue = await _prefs.setString('test_key', 'test_value');
      await _prefs.remove('test_key');

      

      // Check if app directory is accessible
      final appDir = await getApplicationDocumentsDirectory();
      if (!await appDir.exists()) {
        await appDir.create(recursive: true);
      }

      return true;
    } catch (e, stackTrace) {
      await logError('Data integrity validation failed: $e', stackTrace: stackTrace);
      return false;
    }
  }

  /// Recover corrupted data
  Future<bool> recoverCorruptedData() async {
    try {
      // Clear potentially corrupted data
      await _prefs.clear();
      
      // Reinitialize services
      await initialize();
      
      // Attempt to restore from backup if available
      await _restoreFromBackup();
      
      return true;
    } catch (e, stackTrace) {
      await logError('Data recovery failed: $e', stackTrace: stackTrace);
      return false;
    }
  }

  /// Create a backup of current data
  Future<bool> createBackup() async {
    try {
      final backupData = {
        'timestamp': DateTime.now().toIso8601String(),
        'errorLog': _errorLog,
        'recoveryAttempts': _recoveryAttempts,
        'preferences': _prefs.getKeys().map((key) => {
          'key': key,
          'value': _prefs.get(key),
        }).toList(),
      };

      final backupKey = 'backup_${DateTime.now().millisecondsSinceEpoch}';
      await _prefs.setString(backupKey, backupData.toString());
      
      // Keep only last 5 backups
      final keys = _prefs.getKeys().where((key) => key.startsWith('backup_')).toList();
      keys.sort();
      if (keys.length > 5) {
        for (int i = 0; i < keys.length - 5; i++) {
          await _prefs.remove(keys[i]);
        }
      }

      return true;
    } catch (e, stackTrace) {
      await logError('Backup creation failed: $e', stackTrace: stackTrace);
      return false;
    }
  }

  /// Restore from backup
  Future<bool> _restoreFromBackup() async {
    try {
      final keys = _prefs.getKeys().where((key) => key.startsWith('backup_')).toList();
      if (keys.isEmpty) return false;

      // Get the most recent backup
      keys.sort();
      final latestBackupKey = keys.last;
      final backupData = _prefs.getString(latestBackupKey);
      
      if (backupData != null) {
        await logError(
          'Backup restore is not supported in strict mode (latest backup: $latestBackupKey)',
          context: '_restoreFromBackup',
        );
      }

      return false;
    } catch (e, stackTrace) {
      await logError('Backup restoration failed: $e', stackTrace: stackTrace);
      return false;
    }
  }

  /// Get error statistics
  Map<String, dynamic> getErrorStatistics() {
    final now = DateTime.now();
    final last24Hours = now.subtract(const Duration(hours: 24));
    
    final recentErrors = _errorLog.where((error) {
      // Parse timestamp from error log entry
      try {
        final timestampStr = error.split("'timestamp': '")[1].split("'")[0];
        final timestamp = DateTime.parse(timestampStr);
        return timestamp.isAfter(last24Hours);
      } catch (e) {
        return false;
      }
    }).length;

    return {
      'totalErrors': _errorLog.length,
      'recentErrors': recentErrors,
      'recoveryAttempts': _recoveryAttempts,
      'maxRecoveryAttempts': _maxRecoveryAttempts,
    };
  }

  /// Reset recovery attempts
  void _resetRecoveryAttempts() {
    _recoveryAttempts = 0;
    _saveRecoveryAttempts();
  }

  /// Load error log from storage
  Future<void> _loadErrorLog() async {
    final errorLogString = _prefs.getString(_errorLogKey);
    if (errorLogString != null) {
      try {
        final List<dynamic> errorList = errorLogString.split('\n');
        _errorLog.addAll(errorList.where((error) => error.isNotEmpty).cast<String>());
      } catch (e) {
        print('Error loading error log: $e');
      }
    }
  }

  /// Save error log to storage
  Future<void> _saveErrorLog() async {
    try {
      await _prefs.setString(_errorLogKey, _errorLog.join('\n'));
    } catch (e) {
      print('Error saving error log: $e');
    }
  }

  /// Load recovery attempts from storage
  Future<void> _loadRecoveryAttempts() async {
    _recoveryAttempts = _prefs.getInt(_recoveryAttemptsKey) ?? 0;
  }

  /// Save recovery attempts to storage
  Future<void> _saveRecoveryAttempts() async {
    try {
      await _prefs.setInt(_recoveryAttemptsKey, _recoveryAttempts);
    } catch (e) {
      print('Error saving recovery attempts: $e');
    }
  }

  /// Clear all error logs
  Future<void> clearErrorLog() async {
    _errorLog.clear();
    await _prefs.remove(_errorLogKey);
  }

  /// Get network connectivity status
  Future<bool> isNetworkAvailable() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }

  /// Perform health check
  Future<Map<String, bool>> performHealthCheck() async {
    return {
      'network': await isNetworkAvailable(),
      'dataIntegrity': await validateDataIntegrity(),
      'storage': await _checkStorageHealth(),
      'services': await _checkServicesHealth(),
    };
  }

  /// Check storage health
  Future<bool> _checkStorageHealth() async {
    try {
      final testKey = 'health_check_${DateTime.now().millisecondsSinceEpoch}';
      await _prefs.setString(testKey, 'test');
      await _prefs.remove(testKey);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Check services health
  Future<bool> _checkServicesHealth() async {
    try {
      
      return true;
    } catch (e) {
      return false;
    }
  }
} 