import 'database/database_service.dart';
import 'auth_service.dart';
import '../utils/type_converter.dart';

class ScoringConfig {
  final String id;
  final double pointsPerKm;
  final double minDistanceKm;
  final bool requireAtLeastOnePlace;
  final Map<String, double> placeTypePoints; // Dynamické body za různé typy míst
  final bool active;
  final DateTime updatedAt;
  final String? updatedBy;

  const ScoringConfig({
    required this.id,
    required this.pointsPerKm,
    required this.minDistanceKm,
    required this.requireAtLeastOnePlace,
    required this.placeTypePoints,
    required this.active,
    required this.updatedAt,
    this.updatedBy,
  });

  ScoringConfig copyWith({
    String? id,
    double? pointsPerKm,
    double? minDistanceKm,
    bool? requireAtLeastOnePlace,
    Map<String, double>? placeTypePoints,
    bool? active,
    DateTime? updatedAt,
    String? updatedBy,
  }) => ScoringConfig(
        id: id ?? this.id,
        pointsPerKm: pointsPerKm ?? this.pointsPerKm,
        minDistanceKm: minDistanceKm ?? this.minDistanceKm,
        requireAtLeastOnePlace: requireAtLeastOnePlace ?? this.requireAtLeastOnePlace,
        placeTypePoints: placeTypePoints ?? this.placeTypePoints,
        active: active ?? this.active,
        updatedAt: updatedAt ?? this.updatedAt,
        updatedBy: updatedBy ?? this.updatedBy,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'key': 'active',
        'pointsPerKm': pointsPerKm,
        'minDistanceKm': minDistanceKm,
        'requireAtLeastOnePlace': requireAtLeastOnePlace,
        'placeTypePoints': placeTypePoints,
        'active': active,
        'updatedAt': updatedAt.toIso8601String(),
        'updatedBy': updatedBy,
      };

  static ScoringConfig fromMap(Map<String, dynamic> map) {
    // Zpětná kompatibilita - pokud existují staré pole, převedeme je na novou mapu
    Map<String, double> placeTypePoints = {};
    
    if (map['placeTypePoints'] != null) {
      // Nová verze s mapou
      final pointsMap = map['placeTypePoints'] as Map<String, dynamic>;
      pointsMap.forEach((key, value) {
        placeTypePoints[key] = TypeConverter.toDoubleWithDefault(value, 0.0);
      });
    } else {
      // Stará verze - převedeme na novou mapu
      placeTypePoints = {
        'vrchol': TypeConverter.toDoubleWithDefault(map['peakPoints'], 1.0),
        'rozhledna': TypeConverter.toDoubleWithDefault(map['towerPoints'], 1.0),
        'strom': TypeConverter.toDoubleWithDefault(map['treePoints'], 1.0),
      };
    }
    
    return ScoringConfig(
      id: map['id']?.toString() ?? 'default_scoring_config',
      pointsPerKm: TypeConverter.toDoubleWithDefault(map['pointsPerKm'], 1.0),
      minDistanceKm: TypeConverter.toDoubleWithDefault(map['minDistanceKm'], 3.0),
      requireAtLeastOnePlace: map['requireAtLeastOnePlace'] == true,
      placeTypePoints: placeTypePoints,
      active: map['active'] == true,
      updatedAt: DateTime.tryParse(map['updatedAt']?.toString() ?? '') ?? DateTime.now(),
      updatedBy: map['updatedBy']?.toString(),
    );
  }

  factory ScoringConfig.fromJson(Map<String, dynamic> json) {
    return ScoringConfig(
      id: json['id']?.toString() ?? '',
      pointsPerKm: TypeConverter.toDoubleWithDefault(json['pointsPerKm'], 0.0),
      minDistanceKm: TypeConverter.toDoubleWithDefault(json['minDistanceKm'], 0.0),
      requireAtLeastOnePlace: json['requireAtLeastOnePlace'] == true,
      placeTypePoints: (json['placeTypePoints'] as Map<String, dynamic>? ?? {}).map(
        (key, value) => MapEntry(key, TypeConverter.toDoubleWithDefault(value, 0.0))
      ),
      active: json['active'] == true,
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ?? DateTime.now(),
      updatedBy: json['updatedBy']?.toString(),
    );
  }
}

class ScoringConfigService {
  static final ScoringConfigService _instance = ScoringConfigService._internal();
  factory ScoringConfigService() => _instance;
  ScoringConfigService._internal();

  static const String _collection = 'scoring_configs';
  final DatabaseService _dbService = DatabaseService(); // Initialize DatabaseService

  Future<ScoringConfig> getConfig() async {
    try {
      final doc = await _dbService.findOne(_collection, {'active': true});
      if (doc == null) return _defaultConfig();
      return ScoringConfig.fromMap(doc);
    } catch (e) {
      print('❌ Error getting scoring config: $e');
      return _defaultConfig();
    }
  }

  Future<bool> saveConfig(ScoringConfig config) async {
    try {
      final updatedBy = AuthService.currentUser?.id;
      final toSave = config.copyWith(updatedAt: DateTime.now(), updatedBy: updatedBy).toMap();

      await _dbService.updateOne(
        _collection,
        {'id': config.id},
        {
          '\$set': Map<String, dynamic>.from(toSave)..remove('id'),
          '\$setOnInsert': {'id': config.id}
        },
        upsert: true,
      );
      return true;
    } catch (e) {
      print('❌ Error saving scoring config: $e');
      return false;
    }
  }

  ScoringConfig _defaultConfig() => ScoringConfig(
        id: 'default_scoring_config',
        pointsPerKm: 2.0,
        minDistanceKm: 3.0,
        requireAtLeastOnePlace: true,
        placeTypePoints: {
          'PEAK': 1.0,
          'TOWER': 1.0,
          'TREE': 1.0,
          'OTHER': 0.0,
        },
        active: true,
        updatedAt: DateTime.now(),
        updatedBy: null,
      );

}

// Helper metody pro práci s place type points
extension ScoringConfigHelpers on ScoringConfig {
  double getPointsForPlaceType(String placeType) {
    return placeTypePoints[placeType] ?? 0.0;
  }

  void addPlaceTypePoints(String placeType, double points) {
    placeTypePoints[placeType] = points;
  }

  void removePlaceTypePoints(String placeType) {
    placeTypePoints.remove(placeType);
  }

  List<String> getPlaceTypes() {
    return placeTypePoints.keys.toList();
  }

  bool hasPlaceType(String placeType) {
    return placeTypePoints.containsKey(placeType);
  }
}



