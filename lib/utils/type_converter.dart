
/// Utility class for safe type conversions, especially when dealing with
/// data from MongoDB which might contain Int64 (fixnum) types.
class TypeConverter {
  /// Safely converts a dynamic value to an int.
  /// Handles int, double, String, and Int64 (fixnum).
  static int? toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    
    // For Int64 or other types, use toString() and tryParse
    try {
      // Int64 has a toInt() method, but we can't easily type-check it without importing fixnum
      // Using toString() is the most robust way across different environments.
      return int.tryParse(value.toString());
    } catch (_) {
      return null;
    }
  }

  /// Safely converts a dynamic value to an int with a default value.
  static int toIntWithDefault(dynamic value, int defaultValue) {
    return toInt(value) ?? defaultValue;
  }

  /// Safely converts a dynamic value to a double.
  /// Handles int, double, String, and Int64 (fixnum).
  static double? toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.replaceAll(',', '.'));
    
    try {
      return double.tryParse(value.toString());
    } catch (_) {
      return null;
    }
  }

  /// Safely converts a dynamic value to a double with a default value.
  static double toDoubleWithDefault(dynamic value, double defaultValue) {
    return toDouble(value) ?? defaultValue;
  }

  /// Safely converts a dynamic value to a boolean.
  static bool? toBool(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is String) {
      final s = value.toLowerCase();
      if (s == 'true' || s == '1') return true;
      if (s == 'false' || s == '0') return false;
    }
    if (value is num) return value != 0;
    return null;
  }

  /// Safely converts a dynamic value to a boolean with a default value.
  static bool toBoolWithDefault(dynamic value, bool defaultValue) {
    return toBool(value) ?? defaultValue;
  }
}
