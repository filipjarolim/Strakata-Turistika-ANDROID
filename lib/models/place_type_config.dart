import 'package:flutter/material.dart';
import '../services/database/database_service.dart';
import '../services/auth_service.dart';

class PlaceTypeConfig {
// ... [Class properties unchanged] ...
  final String id;
  final String name;
  final String label;
  final IconData icon;
  final int points;
  final Color color;
  final bool isActive;
  final int order;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdBy;
  final String? updatedBy;

  const PlaceTypeConfig({
    required this.id,
    required this.name,
    required this.label,
    required this.icon,
    required this.points,
    required this.color,
    this.isActive = true,
    required this.order,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
    this.updatedBy,
  });

  PlaceTypeConfig copyWith({
    String? id,
    String? name,
    String? label,
    IconData? icon,
    int? points,
    Color? color,
    bool? isActive,
    int? order,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? updatedBy,
  }) => PlaceTypeConfig(
    id: id ?? this.id,
    name: name ?? this.name,
    label: label ?? this.label,
    icon: icon ?? this.icon,
    points: points ?? this.points,
    color: color ?? this.color,
    isActive: isActive ?? this.isActive,
    order: order ?? this.order,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    createdBy: createdBy ?? this.createdBy,
    updatedBy: updatedBy ?? this.updatedBy,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'label': label,
    'icon': icon.codePoint,
    'points': points,
    'color': color.value,
    'isActive': isActive,
    'order': order,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'createdBy': createdBy,
    'updatedBy': updatedBy,
  };

  /// Maps stored Material code points to const [IconData] so release builds can tree-shake fonts.
  static IconData iconForMaterialCodePoint(int codePoint) {
    if (codePoint == Icons.terrain.codePoint) return Icons.terrain;
    if (codePoint == Icons.attractions.codePoint) return Icons.attractions;
    if (codePoint == Icons.park.codePoint) return Icons.park;
    if (codePoint == Icons.place_outlined.codePoint) return Icons.place_outlined;
    return Icons.place_outlined;
  }

  factory PlaceTypeConfig.fromMap(Map<String, dynamic> map) {
    // Default icon and color mappings
    final iconMap = {
      'PEAK': Icons.terrain,
      'TOWER': Icons.attractions,
      'TREE': Icons.park,
      'OTHER': Icons.place_outlined,
    };
    
    final colorMap = {
      'PEAK': Colors.orange,
      'TOWER': Colors.blue,
      'TREE': Colors.green,
      'OTHER': Colors.grey,
    };

    IconData getIcon() {
      if (map['icon'] is int) {
        return iconForMaterialCodePoint(map['icon'] as int);
      }
      return iconMap[map['name']] ?? Icons.place_outlined;
    }

    final colorVal = safeIntFromMap(map['color']);
    return PlaceTypeConfig(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      label: map['label']?.toString() ?? '',
      icon: getIcon(),
      points: safeIntFromMap(map['points']),
      color: Color(colorVal != 0 ? colorVal : (colorMap[map['name']]?.value ?? Colors.grey.value)),
      isActive: map['isActive'] != false,
      order: safeIntFromMap(map['order']),
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updatedAt']?.toString() ?? '') ?? DateTime.now(),
      createdBy: map['createdBy']?.toString(),
      updatedBy: map['updatedBy']?.toString(),
    );
  }

  static int safeIntFromMap(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value.toString().startsWith('Int64')) {
       // Handle Int64 specifically if it comes as a string representation or similar object
       // But often Int64 just needs .toInt() if it's the fixnum type.
       // Since we don't import fixnum here, we rely on dynamic or toString parsing if needed.
       // However, often simply value.toInt() works if it acts like a number.
       // Let's try to parse string reference if it's really an object.
       return int.tryParse(value.toString()) ?? 0;
    }
    if (value is String) {
      final parsed = int.tryParse(value);
      return parsed ?? 0;
    }
    try {
      return (value as dynamic).toInt();
    } catch (_) {
      return 0;
    }
  }
}

class PlaceTypeConfigService {
  static final PlaceTypeConfigService _instance = PlaceTypeConfigService._internal();
  factory PlaceTypeConfigService() => _instance;
  PlaceTypeConfigService._internal();

  final DatabaseService _dbService = DatabaseService();
  static const String _collection = 'place_type_configs';

  Future<List<PlaceTypeConfig>> getPlaceTypeConfigs() async {
    try {
      final configs = await _dbService.find(_collection, {});
      if (configs.isEmpty) {
        throw Exception('Kolekce place_type_configs je prázdná.');
      }
      
      configs.sort((a, b) => PlaceTypeConfig.safeIntFromMap(a['order']).compareTo(PlaceTypeConfig.safeIntFromMap(b['order'])));
      final result = configs.map((doc) => PlaceTypeConfig.fromMap(doc)).toList();
      return result.where((config) => config.isActive).toList();
    } catch (e) {
      print('❌ Error loading place type configs: $e');
      return <PlaceTypeConfig>[];
    }
  }

  Future<bool> savePlaceTypeConfigs(List<PlaceTypeConfig> configs) async {
    try {
      await _dbService.deleteMany(_collection, {});
      final currentUser = AuthService.currentUser?.id;
      final now = DateTime.now();
      
      final configsToSave = configs.map((config) {
        return config.copyWith(updatedAt: now, updatedBy: currentUser).toMap();
      }).toList();

      if (configsToSave.isNotEmpty) {
        await _dbService.insertAll(_collection, configsToSave);
      }
      return true;
    } catch (e) {
      print('❌ Error saving place type configs: $e');
      return false;
    }
  }

  Future<bool> updatePlaceTypeConfig(PlaceTypeConfig config) async {
    try {
      final currentUser = AuthService.currentUser?.id;
      final now = DateTime.now();
      
      final configToUpdate = config.copyWith(updatedAt: now, updatedBy: currentUser);
      await _dbService.updateOne(_collection, {'id': config.id}, {'\$set': configToUpdate.toMap()});
      return true;
    } catch (e) {
      print('❌ Error updating place type config: $e');
      return false;
    }
  }

  Future<bool> reorderPlaceTypeConfigs(List<String> configIds) async {
    try {
      for (int i = 0; i < configIds.length; i++) {
        await _dbService.updateOne(
          _collection,
          {'id': configIds[i]},
          {'\$set': {'order': i}},
        );
      }
      return true;
    } catch (e) {
      print('❌ Error reordering place type configs: $e');
      return false;
    }
  }

  Future<bool> deletePlaceTypeConfig(String configId) async {
    try {
      await _dbService.deleteOne(_collection, {'id': configId});
      return true;
    } catch (e) {
      print('❌ Error deleting place type config: $e');
      return false;
    }
  }

  Future<bool> updatePlaceTypeStatus(String configId, bool isActive) async {
    try {
      await _dbService.updateOne(
        _collection,
        {'id': configId},
        {'\$set': {'isActive': isActive}},
      );
      return true;
    } catch (e) {
      print('❌ Error updating place type config status: $e');
      return false;
    }
  }

  Future<bool> reorderPlaceTypes(List<String> configIds) async {
    return await reorderPlaceTypeConfigs(configIds);
  }
}
