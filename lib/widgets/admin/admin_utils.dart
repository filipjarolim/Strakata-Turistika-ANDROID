import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/visit_data.dart';
import '../../services/scoring_config_service.dart';
import '../../utils/type_converter.dart';

class AdminUtils {
  // Date and Time Formatting
  static String formatDate(DateTime? date, {String? format}) {
    if (date == null) return 'Neznámé datum';
    
    final formatter = DateFormat(format ?? 'dd.MM.yyyy');
    return formatter.format(date);
  }

  static String formatDateTime(DateTime? dateTime, {String? format}) {
    if (dateTime == null) return 'Neznámý čas';
    
    final formatter = DateFormat(format ?? 'dd.MM.yyyy HH:mm');
    return formatter.format(dateTime);
  }

  static String formatDuration(Duration? duration) {
    if (duration == null) return 'Neznámá doba';
    
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
    } else {
      return '${seconds}s';
    }
  }

  static String formatRelativeTime(DateTime? dateTime) {
    if (dateTime == null) return 'Neznámý čas';
    
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays > 0) {
      return '${difference.inDays} dní zpět';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hodin zpět';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minut zpět';
    } else {
      return 'Právě teď';
    }
  }

  // Number Formatting
  static String formatNumber(num? number, {int decimalPlaces = 1}) {
    if (number == null) return '0';
    
    if (number == number.toInt()) {
      return number.toInt().toString();
    }
    
    return number.toStringAsFixed(decimalPlaces);
  }

  static String formatDistance(double? distanceKm) {
    if (distanceKm == null) return '0 km';
    
    if (distanceKm < 1) {
      return '${(distanceKm * 1000).round()} m';
    }
    
    return '${formatNumber(distanceKm)} km';
  }

  static String formatSpeed(double? speedKmh) {
    if (speedKmh == null) return '0 km/h';
    
    return '${formatNumber(speedKmh)} km/h';
  }

  static String formatElevation(double? elevationM) {
    if (elevationM == null) return '0 m';
    
    return '${elevationM.round()} m';
  }

  // Status and State Formatting
  static String getVisitStateText(String state) {
    switch (state) {
      case 'PENDING_REVIEW':
        return 'Čeká na revizi';
      case 'APPROVED':
        return 'Schváleno';
      case 'REJECTED':
        return 'Odmítnuto';
      case 'DRAFT':
        return 'Koncept';
      default:
        return 'Neznámý stav';
    }
  }

  static Color getVisitStateColor(String state) {
    switch (state) {
      case 'PENDING_REVIEW':
        return Colors.orange;
      case 'APPROVED':
        return Colors.green;
      case 'REJECTED':
        return Colors.red;
      case 'DRAFT':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  static IconData getVisitStateIcon(String state) {
    switch (state) {
      case 'PENDING_REVIEW':
        return Icons.schedule;
      case 'APPROVED':
        return Icons.check_circle;
      case 'REJECTED':
        return Icons.cancel;
      case 'DRAFT':
        return Icons.edit;
      default:
        return Icons.help;
    }
  }

  // Field Type Formatting
  static String getFieldTypeText(String type) {
    switch (type) {
      case 'text':
        return 'Text';
      case 'textarea':
        return 'Dlouhý text';
      case 'number':
        return 'Číslo';
      case 'select':
        return 'Výběr';
      case 'checkbox':
        return 'Zaškrtávací pole';
      case 'date':
        return 'Datum';
      case 'time':
        return 'Čas';
      case 'datetime':
        return 'Datum a čas';
      case 'email':
        return 'Email';
      case 'phone':
        return 'Telefon';
      case 'url':
        return 'URL';
      case 'rating':
        return 'Hodnocení';
      case 'file':
        return 'Soubor';
      case 'image':
        return 'Obrázek';
      case 'location':
        return 'Lokace';
      case 'distance':
        return 'Vzdálenost';
      case 'duration':
        return 'Doba trvání';
      case 'elevation':
        return 'Nadmořská výška';
      case 'speed':
        return 'Rychlost';
      case 'places':
        return 'Místa';
      default:
        return 'Neznámý typ';
    }
  }

  static Color getFieldTypeColor(String type) {
    switch (type) {
      case 'text':
      case 'textarea':
        return Colors.blue;
      case 'number':
      case 'distance':
      case 'elevation':
      case 'speed':
        return Colors.green;
      case 'select':
        return Colors.purple;
      case 'checkbox':
        return Colors.orange;
      case 'date':
      case 'time':
      case 'datetime':
        return Colors.red;
      case 'email':
      case 'phone':
      case 'url':
        return Colors.indigo;
      case 'rating':
        return Colors.amber;
      case 'places':
        return Colors.teal;
      case 'file':
      case 'image':
        return Colors.brown;
      case 'location':
        return Colors.deepPurple;
      case 'duration':
        return Colors.cyan;
      default:
        return Colors.grey;
    }
  }

  static IconData getFieldTypeIcon(String type) {
    switch (type) {
      case 'text':
        return Icons.text_fields;
      case 'textarea':
        return Icons.subject;
      case 'number':
        return Icons.numbers;
      case 'select':
        return Icons.list;
      case 'checkbox':
        return Icons.check_box;
      case 'date':
        return Icons.calendar_today;
      case 'time':
        return Icons.access_time;
      case 'datetime':
        return Icons.date_range;
      case 'email':
        return Icons.email;
      case 'phone':
        return Icons.phone;
      case 'url':
        return Icons.link;
      case 'rating':
        return Icons.star;
      case 'file':
        return Icons.attach_file;
      case 'image':
        return Icons.image;
      case 'location':
        return Icons.location_on;
      case 'distance':
        return Icons.route;
      case 'duration':
        return Icons.timer;
      case 'elevation':
        return Icons.landscape;
      case 'speed':
        return Icons.speed;
      case 'places':
        return Icons.place;
      default:
        return Icons.help;
    }
  }

  // Validation Helpers
  static bool isValidEmail(String? email) {
    if (email == null || email.isEmpty) return false;
    
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(email);
  }

  static bool isValidPhone(String? phone) {
    if (phone == null || phone.isEmpty) return false;
    
    // Remove all non-digit characters
    final digitsOnly = phone.replaceAll(RegExp(r'[^\d]'), '');
    return digitsOnly.length >= 9;
  }

  static bool isValidUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    
    try {
      Uri.parse(url);
      return true;
    } catch (e) {
      return false;
    }
  }

  static bool isValidNumber(String? number) {
    if (number == null || number.isEmpty) return false;
    
    return double.tryParse(number) != null;
  }

  // Data Processing Helpers
  static List<T> sortByField<T>(
    List<T> list,
    dynamic Function(T) fieldSelector, {
    bool ascending = true,
  }) {
    final sorted = List<T>.from(list);
    
    if (ascending) {
      sorted.sort((a, b) {
        final aValue = fieldSelector(a);
        final bValue = fieldSelector(b);
        
        if (aValue == null && bValue == null) return 0;
        if (aValue == null) return -1;
        if (bValue == null) return 1;
        
        if (aValue is String && bValue is String) {
          return aValue.toLowerCase().compareTo(bValue.toLowerCase());
        }
        
        if (aValue is num && bValue is num) {
          return aValue.compareTo(bValue);
        }
        
        if (aValue is DateTime && bValue is DateTime) {
          return aValue.compareTo(bValue);
        }
        
        return aValue.toString().compareTo(bValue.toString());
      });
    } else {
      sorted.sort((a, b) {
        final aValue = fieldSelector(a);
        final bValue = fieldSelector(b);
        
        if (aValue == null && bValue == null) return 0;
        if (aValue == null) return 1;
        if (bValue == null) return -1;
        
        if (aValue is String && bValue is String) {
          return bValue.toLowerCase().compareTo(aValue.toLowerCase());
        }
        
        if (aValue is num && bValue is num) {
          return bValue.compareTo(aValue);
        }
        
        if (aValue is DateTime && bValue is DateTime) {
          return bValue.compareTo(aValue);
        }
        
        return bValue.toString().compareTo(aValue.toString());
      });
    }
    
    return sorted;
  }

  static List<T> filterBySearch<T>(
    List<T> list,
    String searchQuery,
    List<String Function(T)> searchFields,
  ) {
    if (searchQuery.isEmpty) return list;
    
    final query = searchQuery.toLowerCase();
    
    return list.where((item) {
      for (final field in searchFields) {
        final value = field(item);
        if (value.toLowerCase().contains(query)) {
          return true;
        }
      }
      return false;
    }).toList();
  }

  static List<T> paginate<T>(
    List<T> list, {
    int page = 1,
    int pageSize = 20,
  }) {
    final startIndex = (page - 1) * pageSize;
    final endIndex = startIndex + pageSize;
    
    if (startIndex >= list.length) return [];
    if (endIndex >= list.length) return list.sublist(startIndex);
    
    return list.sublist(startIndex, endIndex);
  }

  // UI Helper Functions
  static Color getContrastColor(Color backgroundColor) {
    final luminance = backgroundColor.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }

  static Color darkenColor(Color color, double amount) {
    assert(amount >= 0 && amount <= 1);
    
    final hsl = HSLColor.fromColor(color);
    final darkened = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return darkened.toColor();
  }

  static Color lightenColor(Color color, double amount) {
    assert(amount >= 0 && amount <= 1);
    
    final hsl = HSLColor.fromColor(color);
    final lightened = hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0));
    return lightened.toColor();
  }

  static String getInitials(String? name) {
    if (name == null || name.isEmpty) return '?';
    
    final parts = name.trim().split(' ');
    if (parts.length == 1) {
      return parts[0].substring(0, 1).toUpperCase();
    }
    
    return '${parts[0].substring(0, 1)}${parts[1].substring(0, 1)}'.toUpperCase();
  }

  static String truncateText(String text, int maxLength, {String suffix = '...'}) {
    if (text.length <= maxLength) return text;
    
    return '${text.substring(0, maxLength - suffix.length)}$suffix';
  }

  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  // Score Calculation Helpers
  static double calculateVisitScore(
    VisitData visitData,
    ScoringConfig scoringConfig,
  ) {
    double score = 0.0;
    
    // Only award points if minimum distance requirement is met
    final distance = visitData.route?['distance'] as double?;
    if (distance != null && distance >= scoringConfig.minDistanceKm) {
      // Base points for distance
      score += distance * scoringConfig.pointsPerKm;
      
      // Points for places visited (only if distance requirement is met)
      for (final place in visitData.places) {
        final placeType = place.type?.name ?? 'OTHER';
        if (scoringConfig.hasPlaceType(placeType)) {
          score += scoringConfig.getPointsForPlaceType(placeType);
        } else {
          score += scoringConfig.getPointsForPlaceType('OTHER'); // Use OTHER type points
        }
      }
      
      // Bonus for meeting minimum requirements
      if (scoringConfig.requireAtLeastOnePlace && visitData.places.isNotEmpty) {
        score += 5; // Bonus points
      }
    }
    
    return score;
  }

  static String getScoreGrade(double score) {
    if (score >= 90) return 'A+';
    if (score >= 85) return 'A';
    if (score >= 80) return 'A-';
    if (score >= 75) return 'B+';
    if (score >= 70) return 'B';
    if (score >= 65) return 'B-';
    if (score >= 60) return 'C+';
    if (score >= 55) return 'C';
    if (score >= 50) return 'C-';
    if (score >= 45) return 'D+';
    if (score >= 40) return 'D';
    if (score >= 35) return 'D-';
    return 'F';
  }

  static Color getScoreGradeColor(double score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    return Colors.red;
  }

  // Statistics Helpers
  static Map<String, dynamic> calculateVisitStatistics(List<VisitData> visits) {
    if (visits.isEmpty) {
      return {
        'totalVisits': 0,
        'totalDistance': 0.0,
        'totalDuration': Duration.zero,
        'averageScore': 0.0,
        'stateDistribution': <String, int>{},
        'monthlyDistribution': <String, int>{},
      };
    }
    
    double totalDistance = 0.0;
    Duration totalDuration = Duration.zero;
    double totalScore = 0.0;
    final stateDistribution = <String, int>{};
    final monthlyDistribution = <String, int>{};
    
    for (final visit in visits) {
      // Distance
      final distance = visit.route?['distance'] as double?;
      if (distance != null) {
        totalDistance += distance;
      }
      
      // Duration
      final duration = TypeConverter.toInt(visit.route?['duration']);
      if (duration != null) {
        totalDuration += Duration(seconds: duration);
      }
      
      // State distribution
      final state = visit.state.name;
      stateDistribution[state] = (stateDistribution[state] ?? 0) + 1;
      
      // Monthly distribution
      if (visit.visitDate != null) {
        final monthKey = '${visit.visitDate!.year}-${visit.visitDate!.month.toString().padLeft(2, '0')}';
        monthlyDistribution[monthKey] = (monthlyDistribution[monthKey] ?? 0) + 1;
      }
    }
    
    return {
      'totalVisits': visits.length,
      'totalDistance': totalDistance,
      'totalDuration': totalDuration,
      'averageScore': totalScore / visits.length,
      'stateDistribution': stateDistribution,
      'monthlyDistribution': monthlyDistribution,
    };
  }

  // Export Helpers
  static String exportToCsv(List<Map<String, dynamic>> data, List<String> headers) {
    if (data.isEmpty) return headers.join(',');
    
    final csv = StringBuffer();
    
    // Add headers
    csv.writeln(headers.join(','));
    
    // Add data rows
    for (final row in data) {
      final values = headers.map((header) {
        final value = row[header];
        if (value == null) return '';
        if (value is String && value.contains(',')) {
          return '"$value"';
        }
        return value.toString();
      });
      csv.writeln(values.join(','));
    }
    
    return csv.toString();
  }

  static String exportToJson(List<Map<String, dynamic>> data) {
    return JsonEncoder._().convert(data);
  }

  // Import Helpers
  static List<Map<String, dynamic>> parseCsv(String csvData) {
    final lines = csvData.trim().split('\n');
    if (lines.length < 2) return [];
    
    final headers = lines[0].split(',').map((h) => h.trim()).toList();
    final data = <Map<String, dynamic>>[];
    
    for (int i = 1; i < lines.length; i++) {
      final values = _parseCsvLine(lines[i]);
      if (values.length == headers.length) {
        final row = <String, dynamic>{};
        for (int j = 0; j < headers.length; j++) {
          row[headers[j]] = values[j];
        }
        data.add(row);
      }
    }
    
    return data;
  }

  static List<String> _parseCsvLine(String line) {
    final result = <String>[];
    final buffer = StringBuffer();
    bool inQuotes = false;
    
    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      
      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (char == ',' && !inQuotes) {
        result.add(buffer.toString().trim());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }
    
    result.add(buffer.toString().trim());
    return result;
  }
}

// Extension for JsonEncoder
class JsonEncoder {
  static const JsonEncoder withIndent = JsonEncoder._();
  
  const JsonEncoder._();
  
  String convert(dynamic obj) {
    return obj.toString(); // Simplified implementation
  }
}


