import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:latlong2/latlong.dart';

/// Mapy.cz-style vector tile provider with compressed storage and layered rendering
class VectorTileProvider extends TileProvider {
  final String urlTemplate;
  final Map<String, String> headers;
  final int maxZoom;
  final int minZoom;
  final bool enableCompression;
  final bool enableLayering;
  
  // Hive boxes for different layers
  static Box? _baseLayerBox;
  static Box? _transportLayerBox;
  static Box? _labelLayerBox;
  static Box? _metadataBox;
  
  VectorTileProvider({
    required this.urlTemplate,
    Map<String, String>? headers,
    this.maxZoom = 18,
    this.minZoom = 5, // Start from zoom 5 for maximum detail
    this.enableCompression = true,
    this.enableLayering = true,
  }) : headers = Map<String, String>.from(headers ?? const {});

  /// Initialize the vector tile storage system
  static Future<void> initialize() async {
    await Hive.initFlutter();
    
    // Register adapters for custom types (only if not already registered)
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(VectorTileDataAdapter());
    }
    
    // Open boxes for different layers
    _baseLayerBox = await Hive.openBox('vector_tiles_base');
    _transportLayerBox = await Hive.openBox('vector_tiles_transport');
    _labelLayerBox = await Hive.openBox('vector_tiles_labels');
    _metadataBox = await Hive.openBox('vector_tiles_metadata');
    
    // print('🗺️ Vector tile storage initialized');
  }

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    // Check zoom bounds
    if (coordinates.z < minZoom || coordinates.z > maxZoom) {
      throw Exception('Zoom level ${coordinates.z} is out of bounds ($minZoom-$maxZoom)');
    }
    
    final tileKey = '${coordinates.z}_${coordinates.x}_${coordinates.y}';
    final url = urlTemplate
        .replaceAll('{z}', coordinates.z.toString())
        .replaceAll('{x}', coordinates.x.toString())
        .replaceAll('{y}', coordinates.y.toString());
    
    // Provide an image provider that caches on-success and falls back to cache on failure
    return ResilientCachedTileImageProvider(
      url: url,
      headers: headers,
      tileKey: tileKey,
      layer: 'base',
    );
  }
  
  /// Get cached tile synchronously (for immediate use)
  static VectorTileData? getCachedTileSync(String tileKey, String layer) {
    try {
      Box? box;
      switch (layer) {
        case 'base':
          box = _baseLayerBox;
          break;
        case 'transport':
          box = _transportLayerBox;
          break;
        case 'labels':
          box = _labelLayerBox;
          break;
        default:
          return null;
      }
      
      if (box == null) return null;
      
      final cachedData = box.get(tileKey);
      if (cachedData != null) {
        return cachedData as VectorTileData;
      }
      
      return null;
    } catch (e) {
      print('❌ Failed to get cached vector tile: $e');
      return null;
    }
  }
  
  /// Get cached vector tile data
  static Future<VectorTileData?> getCachedTile(String tileKey, String layer) async {
    try {
      Box? box;
      switch (layer) {
        case 'base':
          box = _baseLayerBox;
          break;
        case 'transport':
          box = _transportLayerBox;
          break;
        case 'labels':
          box = _labelLayerBox;
          break;
        default:
          return null;
      }
      
      if (box == null) return null;
      
      final cachedData = box.get(tileKey);
      if (cachedData != null) {
        return cachedData as VectorTileData;
      }
      
      return null;
    } catch (e) {
      print('❌ Failed to get cached vector tile: $e');
      return null;
    }
  }
  
  /// Cache vector tile data
  static Future<void> cacheTile(String tileKey, VectorTileData data, String layer) async {
    try {
      Box? box;
      switch (layer) {
        case 'base':
          box = _baseLayerBox;
          break;
        case 'transport':
          box = _transportLayerBox;
          break;
        case 'labels':
          box = _labelLayerBox;
          break;
        default:
          return;
      }
      
      if (box == null) return;
      
      await box.put(tileKey, data);
    } catch (e) {
      print('❌ Failed to cache vector tile: $e');
    }
  }
  
  /// Get tile metadata
  static Future<Map<String, dynamic>?> getTileMetadata(String tileKey) async {
    try {
      return _metadataBox?.get(tileKey);
    } catch (e) {
      print('❌ Failed to get tile metadata: $e');
      return null;
    }
  }

  /// Estimate cache coverage ratio for a bounding box and zoom range
  static Future<double> estimateCoverage({
    required LatLng southwest,
    required LatLng northeast,
    required int zoom,
    String layer = 'base',
  }) async {
    Map<String, int> range = _computeTileRangeForBounds(southwest, northeast, zoom);
    final int minX = range['minX']!;
    final int maxX = range['maxX']!;
    final int minY = range['minY']!;
    final int maxY = range['maxY']!;
    int total = 0;
    int cached = 0;
    for (int x = minX; x <= maxX; x++) {
      for (int y = minY; y <= maxY; y++) {
        total++;
        final key = '${zoom}_${x}_${y}';
        final hit = getCachedTileSync(key, layer);
        if (hit != null && hit.isValid) cached++;
      }
    }
    if (total == 0) return 0.0;
    return cached / total;
  }

  static Map<String, int> _computeTileRangeForBounds(LatLng southwest, LatLng northeast, int zoom) {
    final n = pow(2, zoom).toDouble();
    int minTileX = ((southwest.longitude + 180) / 360 * n).floor();
    int maxTileX = ((northeast.longitude + 180) / 360 * n).floor();
    int minTileY = ((1 - log(tan(northeast.latitude * pi / 180) + 1 / cos(northeast.latitude * pi / 180)) / pi) / 2 * n).floor();
    int maxTileY = ((1 - log(tan(southwest.latitude * pi / 180) + 1 / cos(southwest.latitude * pi / 180)) / pi) / 2 * n).floor();

    final int maxIndex = n.toInt() - 1;
    minTileX = minTileX.clamp(0, maxIndex);
    maxTileX = maxTileX.clamp(0, maxIndex);
    minTileY = minTileY.clamp(0, maxIndex);
    maxTileY = maxTileY.clamp(0, maxIndex);

    if (minTileX > maxTileX) {
      final t = minTileX; minTileX = maxTileX; maxTileX = t;
    }
    if (minTileY > maxTileY) {
      final t = minTileY; minTileY = maxTileY; maxTileY = t;
    }

    return {
      'minX': minTileX,
      'maxX': maxTileX,
      'minY': minTileY,
      'maxY': maxTileY,
    };
  }
  
  /// Update tile metadata
  static Future<void> updateTileMetadata(String tileKey, Map<String, dynamic> metadata) async {
    try {
      final existing = _metadataBox?.get(tileKey) as Map?;
      final merged = <String, dynamic>{
        if (existing != null) ...Map<String, dynamic>.from(existing),
        ...metadata,
      };
      await _metadataBox?.put(tileKey, merged);
    } catch (e) {
      print('❌ Failed to update tile metadata: $e');
    }
  }
  
  /// Clear all cached tiles
  static Future<void> clearCache() async {
    try {
      await _baseLayerBox?.clear();
      await _transportLayerBox?.clear();
      await _labelLayerBox?.clear();
      await _metadataBox?.clear();
      print('🗺️ Vector tile cache cleared');
    } catch (e) {
      print('❌ Failed to clear vector tile cache: $e');
    }
  }
  
  /// Get cache statistics
  static Map<String, dynamic> getCacheStats() {
    try {
      final baseCount = _baseLayerBox?.length ?? 0;
      final transportCount = _transportLayerBox?.length ?? 0;
      final labelCount = _labelLayerBox?.length ?? 0;
      final totalTiles = baseCount + transportCount + labelCount;
      
      return {
        'totalTiles': totalTiles,
        'baseLayer': baseCount,
        'transportLayer': transportCount,
        'labelLayer': labelCount,
        'compressionEnabled': true,
        'layeringEnabled': true,
      };
    } catch (e) {
      print('❌ Failed to get cache stats: $e');
      return {};
    }
  }

  /// Detailed stats across metadata: sizes and zoom histogram
  static Future<Map<String, dynamic>> getDetailedStats() async {
    try {
      final Map<int, int> zoomHistogram = {};
      int totalCompressedBytes = 0;
      int totalTiles = 0;
      int baseCount = 0;
      int transportCount = 0;
      int labelCount = 0;
      if (_metadataBox != null) {
        for (final key in _metadataBox!.keys) {
          final meta = _metadataBox!.get(key) as Map?;
          if (meta == null) continue;
          totalTiles++;
          final z = (meta['zoom'] ?? 0) as int;
          zoomHistogram[z] = (zoomHistogram[z] ?? 0) + 1;
          totalCompressedBytes += (meta['compressedSize'] ?? 0) as int;
          final layer = meta['layer'] as String?;
          switch (layer) {
            case 'base':
              baseCount++;
              break;
            case 'transport':
              transportCount++;
              break;
            case 'labels':
              labelCount++;
              break;
          }
        }
      }
      final now = DateTime.now().millisecondsSinceEpoch;
      final recentTiles = <Map<String, dynamic>>[];
      final sourceHistogram = <String, int>{};
      int minZoom = 99;
      int maxZoom = -1;
      int? newestTs;
      int? oldestTs;
      double? minLat;
      double? maxLat;
      double? minLng;
      double? maxLng;

      if (_metadataBox != null) {
        for (final key in _metadataBox!.keys) {
          final meta = _metadataBox!.get(key) as Map?;
          if (meta == null) continue;
          final z = (meta['zoom'] ?? 0) as int;
          final x = (meta['x'] ?? 0) as int;
          final y = (meta['y'] ?? 0) as int;
          final ts = (meta['timestamp'] ?? 0) as int;
          final source = (meta['source']?.toString() ?? 'unknown');
          sourceHistogram[source] = (sourceHistogram[source] ?? 0) + 1;
          if (z < minZoom) minZoom = z;
          if (z > maxZoom) maxZoom = z;
          if (newestTs == null || ts > newestTs) newestTs = ts;
          if (oldestTs == null || ts < oldestTs) oldestTs = ts;

          final bounds = _tileBounds(z, x, y);
          minLat = minLat == null ? bounds['south'] : min(minLat, bounds['south']!);
          maxLat = maxLat == null ? bounds['north'] : max(maxLat, bounds['north']!);
          minLng = minLng == null ? bounds['west'] : min(minLng, bounds['west']!);
          maxLng = maxLng == null ? bounds['east'] : max(maxLng, bounds['east']!);

          recentTiles.add({
            'key': key.toString(),
            'zoom': z,
            'x': x,
            'y': y,
            'layer': meta['layer']?.toString() ?? 'base',
            'source': source,
            'timestamp': ts,
            'ageMinutes': ((now - ts) / 60000).round(),
            'compressedSize': (meta['compressedSize'] ?? 0) as int,
          });
        }
      }

      recentTiles.sort((a, b) => (b['timestamp'] as int).compareTo(a['timestamp'] as int));
      final recent = recentTiles.take(8).toList();

      return {
        'totalTiles': totalTiles,
        'totalCompressedBytes': totalCompressedBytes,
        'zoomHistogram': zoomHistogram,
        'baseLayer': baseCount,
        'transportLayer': transportCount,
        'labelLayer': labelCount,
        'sourceHistogram': sourceHistogram,
        'recentTiles': recent,
        'minZoom': minZoom == 99 ? null : minZoom,
        'maxZoom': maxZoom == -1 ? null : maxZoom,
        'newestTimestamp': newestTs,
        'oldestTimestamp': oldestTs,
        'bounds': {
          'south': minLat,
          'north': maxLat,
          'west': minLng,
          'east': maxLng,
        },
      };
    } catch (e) {
      print('❌ Failed to compute detailed stats: $e');
      return {};
    }
  }

  static Map<String, double> _tileBounds(int z, int x, int y) {
    final n = pow(2, z).toDouble();
    final west = x / n * 360.0 - 180.0;
    final east = (x + 1) / n * 360.0 - 180.0;
    final north = _tileYToLat(y, n);
    final south = _tileYToLat(y + 1, n);
    return {
      'west': west,
      'east': east,
      'north': north,
      'south': south,
    };
  }

  static double _tileYToLat(int y, double n) {
    final r = pi * (1.0 - 2.0 * y / n);
    return 180.0 / pi * atan(_sinh(r));
  }

  static double _sinh(double x) {
    final ex = exp(x);
    final enx = exp(-x);
    return (ex - enx) / 2.0;
  }
}

/// ImageProvider that fetches a network tile, caches it, and falls back to cached tile if network fails
class ResilientCachedTileImageProvider extends ImageProvider<ResilientCachedTileImageProvider> {
  final String url;
  final Map<String, String> headers;
  final String tileKey;
  final String layer;

  const ResilientCachedTileImageProvider({
    required this.url,
    required this.headers,
    required this.tileKey,
    required this.layer,
  });

  @override
  Future<ResilientCachedTileImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<ResilientCachedTileImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(ResilientCachedTileImageProvider key, ImageDecoderCallback decode) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key),
      scale: 1.0,
      informationCollector: () sync* {
        yield ErrorDescription('URL: ${key.url}');
      },
    );
  }

  Future<ui.Codec> _loadAsync(ResilientCachedTileImageProvider key) async {
    // Try network first
    try {
      final response = await http.get(Uri.parse(key.url), headers: key.headers);
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        // Cache compressed tile
        try {
          final data = VectorTileData.compress(response.bodyBytes, key.layer);
          await VectorTileProvider.cacheTile(key.tileKey, data, key.layer);
          final parts = key.tileKey.split('_');
          if (parts.length == 3) {
            final z = int.tryParse(parts[0]) ?? 0;
            final x = int.tryParse(parts[1]) ?? 0;
            final y = int.tryParse(parts[2]) ?? 0;
            await VectorTileProvider.updateTileMetadata(key.tileKey, {
              'layer': key.layer,
              'zoom': z,
              'x': x,
              'y': y,
              'timestamp': DateTime.now().millisecondsSinceEpoch,
              'compressedSize': data.compressedSize,
              'compressionRatio': data.compressionRatio,
              'source': 'browsing',
            });
          }
        } catch (_) {}
        return await ui.instantiateImageCodec(response.bodyBytes);
      }
    } catch (_) {}

    final cached = VectorTileProvider.getCachedTileSync(key.tileKey, key.layer);
    if (cached != null && cached.isValid) {
      final bytes = cached.decompress();
      return await ui.instantiateImageCodec(bytes);
    }

    throw Exception('Tile unavailable: ${key.url}');
  }

  @override
  bool operator ==(Object other) {
    return other is ResilientCachedTileImageProvider &&
        other.url == url &&
        other.tileKey == tileKey &&
        mapEquals(other.headers, headers) &&
        other.layer == layer;
  }

  @override
  int get hashCode => Object.hash(url, tileKey, layer, headers.length);
}

/// Vector tile data structure
class VectorTileData {
  final Uint8List compressedData;
  final String layer;
  final DateTime timestamp;
  final int originalSize;
  final int compressedSize;
  final String hash;
  
  VectorTileData({
    required this.compressedData,
    required this.layer,
    required this.timestamp,
    required this.originalSize,
    required this.compressedSize,
    required this.hash,
  });
  
  /// Compress tile data
  static VectorTileData compress(Uint8List data, String layer) {
    final compressed = GZipEncoder().encode(data);
    final hash = sha256.convert(data).toString();
    
    return VectorTileData(
      compressedData: Uint8List.fromList(compressed!),
      layer: layer,
      timestamp: DateTime.now(),
      originalSize: data.length,
      compressedSize: compressed.length,
      hash: hash,
    );
  }
  
  /// Decompress tile data
  Uint8List decompress() {
    final decoder = GZipDecoder();
    final decompressed = decoder.decodeBytes(compressedData);
    return Uint8List.fromList(decompressed);
  }
  
  /// Get compression ratio
  double get compressionRatio => originalSize > 0 ? compressedSize / originalSize : 1.0;
  
  /// Check if data is still valid
  bool get isValid {
    final age = DateTime.now().difference(timestamp);
    return age.inDays < 30; // 30 days validity
  }
}

/// Hive adapter for VectorTileData
class VectorTileDataAdapter extends TypeAdapter<VectorTileData> {
  @override
  final int typeId = 0;
  
  @override
  VectorTileData read(BinaryReader reader) {
    return VectorTileData(
      compressedData: reader.read() as Uint8List,
      layer: reader.read() as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(reader.read() as int),
      originalSize: reader.read() as int,
      compressedSize: reader.read() as int,
      hash: reader.read() as String,
    );
  }
  
  @override
  void write(BinaryWriter writer, VectorTileData obj) {
    writer.write(obj.compressedData);
    writer.write(obj.layer);
    writer.write(obj.timestamp.millisecondsSinceEpoch);
    writer.write(obj.originalSize);
    writer.write(obj.compressedSize);
    writer.write(obj.hash);
  }
}

 