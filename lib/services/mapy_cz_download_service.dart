import 'dart:async';
import 'dart:typed_data';
import 'dart:math';
import 'dart:io';
import 'package:http/io_client.dart';
import 'package:latlong2/latlong.dart';
import 'vector_tile_provider.dart';
// Single-option CZ downloader: fixed fast config up to zoom 18
import 'download_notification_service.dart';

/// Mapy.cz-style download service with incremental updates and layered rendering
class MapyCzDownloadService {
  static bool _isDownloading = false;
  static String _currentStatus = '';
  static double _currentProgress = 0.0;
  static int _downloadedTiles = 0;
  static int _totalTilesToDownload = 0;
  static int _currentFileSize = 0;
  static int _totalFileSize = 0;
  static String _currentLayer = '';
  static int _currentZoomLevel = 0;
  static IOClient? _pooledClient;
  static DateTime? _lastDownloadCompletedAt;
  
  // Stream controllers for real-time updates
  static final StreamController<Map<String, dynamic>> _progressController = 
      StreamController<Map<String, dynamic>>.broadcast();
  static final StreamController<bool> _downloadStateController = 
      StreamController<bool>.broadcast();
  
  static Stream<Map<String, dynamic>> get progressStream => _progressController.stream;
  static Stream<bool> get downloadStateStream => _downloadStateController.stream;
  
  // Getters for current state
  static bool get isDownloading => _isDownloading;
  static String get currentStatus => _currentStatus;
  static double get currentProgress => _currentProgress;
  static int get downloadedTiles => _downloadedTiles;
  static int get totalTilesToDownload => _totalTilesToDownload;
  static int get currentFileSize => _currentFileSize;
  static int get totalFileSize => _totalFileSize;
  static String get currentLayer => _currentLayer;
  static int get currentZoomLevel => _currentZoomLevel;

  /// Download Czech Republic with Mapy.cz-style functionality
  static Future<void> downloadCzechRepublic() async {
    if (_isDownloading) {
      print('🗺️ Czech Republic download already in progress...');
      return;
    }
    if (_lastDownloadCompletedAt != null &&
        DateTime.now().difference(_lastDownloadCompletedAt!).inSeconds < 10) {
      print('⏳ Download just completed recently; skipping duplicate start');
      return;
    }
    
    try {
      _isDownloading = true;
      _downloadStateController.add(true);
      _currentStatus = 'Initializing Mapy.cz-style download...';
      _currentProgress = 0.0;
      _downloadedTiles = 0;
      _currentFileSize = 0;
      _totalFileSize = 0;
      
      // Fixed configuration for Czech Republic
      const String configName = 'Czech Republic';
      const int minZoom = 6;
      const int maxZoom = 12; // limit to z<=12 as requested
      const int batchSize = 2048; // larger logical batch
      const int batchDelayMs = 0; // no delay between batches
      const int concurrency = 48; // higher bounded parallelism for speed
      
      print('🗺️ Starting Czech Republic download');
      print('🗺️ Config: $configName - Zoom $minZoom-$maxZoom');
      
      // Initialize vector tile storage and notifications
      await VectorTileProvider.initialize();
      await DownloadNotificationService.initialize();
      // Build pooled HTTP client for better throughput
      final httpClient = HttpClient();
      httpClient.userAgent = 'StrakataTuristika/1.0';
      httpClient.maxConnectionsPerHost = 64;
      httpClient.idleTimeout = const Duration(seconds: 15);
      httpClient.connectionTimeout = const Duration(seconds: 5);
      httpClient.autoUncompress = true;
      _pooledClient = IOClient(httpClient);
      
      // Show initial download notification
      await DownloadNotificationService.showDownloadProgress(
        title: '🗺️ $configName',
        progress: 0,
        total: 100,
      );
      
      // Check network connectivity first
      try {
        final response = await _pooledClient!
            .get(
          Uri.parse('https://tile.openstreetmap.org/6/34/22.png'),
          headers: {'User-Agent': 'StrakataTuristika/1.0'},
            )
            .timeout(const Duration(seconds: 2));
        
        if (response.statusCode != 200) {
          throw Exception('Network test failed');
        }
      } catch (e) {
        print('❌ Network connectivity test failed: $e');
        _currentStatus = 'Network unavailable';
        _progressController.add({
          'status': _currentStatus,
          'progress': 0.0,
          'downloadedTiles': 0,
          'totalTiles': 0,
          'currentZoom': 0,
          'currentLayer': 'default',
          'currentFileSize': 0,
          'totalFileSize': 0,
        });
        return; // Exit early if no network
      }
      
      // Czech Republic bounds (simple approach)
      final southwest = const LatLng(48.5525, 12.0911);
      final northeast = const LatLng(51.0556, 18.8592);
      
      // Calculate total tiles for existing layers only (base)
      _totalTilesToDownload = 0;
      for (int z = minZoom; z <= maxZoom; z++) {
        final range = _getTileRangeForBounds(southwest, northeast, z);
        final int minX = range['minX']!;
        final int maxX = range['maxX']!;
        final int minY = range['minY']!;
        final int maxY = range['maxY']!;
        final step = _getStepForZoom(z);
        int tilesAtZ = 0;
        for (int x = minX; x <= maxX; x += step) {
          for (int y = minY; y <= maxY; y += step) {
            if (_isTileCenterInCzechRepublic(x, y, z)) {
              tilesAtZ++;
            }
          }
        }
        _totalTilesToDownload += tilesAtZ; // base layer only
        print('🧮 Zoom $z estimate: $tilesAtZ tiles (step=$step)');
      }

      // Fallback: if somehow zero, use full range estimate without CZ filter (very conservative)
      if (_totalTilesToDownload == 0) {
        print('⚠️ Tile estimate returned 0; using conservative fallback');
        for (int z = minZoom; z <= maxZoom; z++) {
          final range = _getTileRangeForBounds(southwest, northeast, z);
          final int minX = range['minX']!;
          final int maxX = range['maxX']!;
          final int minY = range['minY']!;
          final int maxY = range['maxY']!;
          final countX = (maxX - minX + 1).clamp(0, 1 << 20);
          final countY = (maxY - minY + 1).clamp(0, 1 << 20);
          _totalTilesToDownload += (countX * countY * 3);
        }
      }
      
      print('🗺️ Total tiles to download: $_totalTilesToDownload');
      
      // Download only the base layer to avoid duplication and speed up
      final layers = ['base'];
      
      for (int z = minZoom; z <= maxZoom; z++) {
        if (!_isDownloading) break;
        
        _currentZoomLevel = z;
        _currentStatus = 'Downloading zoom level $z...';
        
        final range = _getTileRangeForBounds(southwest, northeast, z);
        final int minX = range['minX']!;
        final int maxX = range['maxX']!;
        final int minY = range['minY']!;
        final int maxY = range['maxY']!;
        
        // Download all layers for this zoom level
        for (final layer in layers) {
          if (!_isDownloading) break;
          
          _currentLayer = layer;
          _currentStatus = 'Downloading $layer layer (zoom $z)...';
          
          await _downloadLayerRange(
            minX: minX,
            maxX: maxX,
            minY: minY,
            maxY: maxY,
            zoom: z,
            layer: layer,
            batchSize: batchSize,
            batchDelayMs: batchDelayMs,
            concurrency: concurrency,
          );
        }
        
        // Update progress
        final progress = _totalTilesToDownload > 0
            ? _downloadedTiles / _totalTilesToDownload
            : 0.0;
        _currentProgress = progress;
        
        _progressController.add({
          'status': _currentStatus,
          'progress': _currentProgress,
          'downloadedTiles': _downloadedTiles,
          'totalTiles': _totalTilesToDownload,
          'currentZoom': z,
          'currentLayer': _currentLayer,
          'currentFileSize': _currentFileSize,
          'totalFileSize': _totalFileSize,
        });
        
        final percent = (progress * 100).clamp(0, 100).round();
        await DownloadNotificationService.showDownloadProgress(
          title: '🗺️ $configName',
          progress: percent,
          total: 100,
        );
        print('🗺️ Zoom level $z completed - Progress: ${percent.toString()}%');
        
        // No delay between zoom levels
        if (!_isDownloading) break;
      }
      
      _currentStatus = 'Download completed!';
      _currentProgress = 1.0;
              _progressController.add({
          'status': _currentStatus,
          'progress': _currentProgress,
          'downloadedTiles': _downloadedTiles,
          'totalTiles': _totalTilesToDownload,
          'currentZoom': maxZoom,
          'currentLayer': 'all',
          'currentFileSize': _currentFileSize,
          'totalFileSize': _totalFileSize,
        });
        
        // Show completion notification
        await DownloadNotificationService.showDownloadCompleted(
          title: '✅ Download Completed',
          message: '🗺️ $configName downloaded successfully!\n'
                   '📊 Total tiles: $_downloadedTiles\n'
                   '💾 Size: ${(_currentFileSize / 1024 / 1024).toStringAsFixed(1)} MB',
        );
      
      print('🗺️ Mapy.cz-style Czech Republic download completed!');
      
    } catch (e) {
      _currentStatus = 'Download failed: $e';
      _progressController.add({
        'status': _currentStatus,
        'progress': _currentProgress,
        'downloadedTiles': _downloadedTiles,
        'totalTiles': _totalTilesToDownload,
        'currentZoom': _currentZoomLevel,
        'currentLayer': _currentLayer,
        'currentFileSize': _currentFileSize,
        'totalFileSize': _totalFileSize,
      });
      
      // Show failure notification
      await DownloadNotificationService.showDownloadFailed(
        title: '❌ Download Failed',
        message: 'Failed to download: ${e.toString()}',
      );
      
      print('❌ Failed to download Czech Republic: $e');
    } finally {
      _isDownloading = false;
      _downloadStateController.add(false);
      await DownloadNotificationService.cancelProgressNotification();
      _lastDownloadCompletedAt = DateTime.now();
    }
  }

  /// Download tiles for an arbitrary bounding box and zoom range (base layer only)
  static Future<void> downloadBounds({
    required LatLng southwest,
    required LatLng northeast,
    int minZoom = 8,
    int maxZoom = 14,
    int concurrency = 32,
    int batchSize = 1024,
  }) async {
    if (_isDownloading) {
      print('🗺️ A download is already in progress...');
      return;
    }
    try {
      _isDownloading = true;
      _downloadStateController.add(true);
      _currentStatus = 'Initializing custom area download...';
      _currentProgress = 0.0;
      _downloadedTiles = 0;
      _currentFileSize = 0;
      _totalFileSize = 0;

      // Initialize storage and networking
      await VectorTileProvider.initialize();
      if (_pooledClient == null) {
        final httpClient = HttpClient();
        httpClient.userAgent = 'StrakataTuristika/1.0';
        httpClient.maxConnectionsPerHost = 48;
        httpClient.idleTimeout = const Duration(seconds: 15);
        httpClient.connectionTimeout = const Duration(seconds: 5);
        httpClient.autoUncompress = true;
        _pooledClient = IOClient(httpClient);
      }

      // Quick network sanity check; avoid attempting downloads offline
      try {
        final resp = await _pooledClient!
            .get(Uri.parse('https://tile.openstreetmap.org/0/0/0.png'))
            .timeout(const Duration(seconds: 2));
        if (resp.statusCode != 200) {
          throw Exception('Network test failed with status ${resp.statusCode}');
        }
      } catch (e) {
        _currentStatus = 'Network unavailable';
        _currentProgress = 0.0;
        _progressController.add({
          'status': _currentStatus,
          'progress': 0.0,
          'downloadedTiles': 0,
          'totalTiles': 0,
          'currentZoom': 0,
          'currentLayer': 'base',
          'currentFileSize': 0,
          'totalFileSize': 0,
        });
        return;
      }

      // Estimate total tiles
      _totalTilesToDownload = 0;
      for (int z = minZoom; z <= maxZoom; z++) {
        final range = _getTileRangeForBounds(southwest, northeast, z);
        final int minX = range['minX']!;
        final int maxX = range['maxX']!;
        final int minY = range['minY']!;
        final int maxY = range['maxY']!;
        final step = _getStepForZoom(z);
        final countX = ((maxX - minX) ~/ step) + 1;
        final countY = ((maxY - minY) ~/ step) + 1;
        _totalTilesToDownload += (countX * countY);
      }

      print('🗺️ Custom area: total tiles to download (estimate): $_totalTilesToDownload');

      final layers = ['base'];
      for (int z = minZoom; z <= maxZoom && _isDownloading; z++) {
        _currentZoomLevel = z;
        for (final layer in layers) {
          if (!_isDownloading) break;
          _currentLayer = layer;
          final range = _getTileRangeForBounds(southwest, northeast, z);
          await _downloadLayerRange(
            minX: range['minX']!,
            maxX: range['maxX']!,
            minY: range['minY']!,
            maxY: range['maxY']!,
            zoom: z,
            layer: layer,
            batchSize: batchSize,
            batchDelayMs: 0,
            concurrency: concurrency,
          );
        }
        _currentProgress = _totalTilesToDownload > 0
            ? _downloadedTiles / _totalTilesToDownload
            : 0.0;
        _progressController.add({
          'status': 'Downloading zoom $z...',
          'progress': _currentProgress,
          'downloadedTiles': _downloadedTiles,
          'totalTiles': _totalTilesToDownload,
          'currentZoom': z,
          'currentLayer': _currentLayer,
          'currentFileSize': _currentFileSize,
          'totalFileSize': _totalFileSize,
        });
      }

      _currentStatus = 'Download completed!';
      _currentProgress = 1.0;
      _progressController.add({
        'status': _currentStatus,
        'progress': _currentProgress,
        'downloadedTiles': _downloadedTiles,
        'totalTiles': _totalTilesToDownload,
        'currentZoom': maxZoom,
        'currentLayer': 'base',
        'currentFileSize': _currentFileSize,
        'totalFileSize': _totalFileSize,
      });
      print('✅ Custom area download finished');
    } catch (e) {
      _currentStatus = 'Download failed: $e';
      _progressController.add({
        'status': _currentStatus,
        'progress': _currentProgress,
        'downloadedTiles': _downloadedTiles,
        'totalTiles': _totalTilesToDownload,
        'currentZoom': _currentZoomLevel,
        'currentLayer': _currentLayer,
        'currentFileSize': _currentFileSize,
        'totalFileSize': _totalFileSize,
      });
      print('❌ Failed to download custom area: $e');
    } finally {
      _isDownloading = false;
      _downloadStateController.add(false);
    }
  }
  
  static Future<Uint8List?> _fetchTileBytes(String url) async {
    for (int attempt = 0; attempt < 2; attempt++) {
      try {
        final response = await _pooledClient!
            .get(
              Uri.parse(url),
              headers: {
                'User-Agent': 'StrakataTuristika/1.0',
                'Accept': 'image/png',
                'Connection': 'keep-alive',
                'Accept-Encoding': 'gzip, deflate',
                'Cache-Control': 'no-cache',
              },
            )
            .timeout(const Duration(seconds: 3));
        if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
          return response.bodyBytes;
        }
      } catch (_) {
        // retry quickly once
      }
    }
    return null;
  }
  /// Download a specific layer
  static Future<void> _downloadLayerRange({
    required int minX,
    required int maxX,
    required int minY,
    required int maxY,
    required int zoom,
    required String layer,
    required int batchSize,
    required int batchDelayMs,
    required int concurrency,
  }) async {
    List<Map<String, int>> batch = [];
    final int step = _getStepForZoom(zoom);

    for (int x = minX; x <= maxX && _isDownloading; x += step) {
      for (int y = minY; y <= maxY && _isDownloading; y += step) {
        if (!_isTileCenterInCzechRepublic(x, y, zoom)) continue;
        batch.add({'x': x, 'y': y});
        if (batch.length >= batchSize) {
          await _processBatch(batch, zoom, layer, concurrency);
          batch = [];
          if (batchDelayMs > 0) {
            await Future.delayed(Duration(milliseconds: batchDelayMs));
          }
        }
      }
    }

    // Flush remaining
    if (_isDownloading && batch.isNotEmpty) {
      await _processBatch(batch, zoom, layer, concurrency);
    }
  }

  static Future<void> _processBatch(
    List<Map<String, int>> batch,
    int zoom,
    String layer,
    int concurrency,
  ) async {
    for (int i = 0; i < batch.length && _isDownloading; i += concurrency) {
      final end = (i + concurrency < batch.length) ? i + concurrency : batch.length;
      final slice = batch.sublist(i, end);
      final futures = <Future<void>>[];
      for (final tile in slice) {
        futures.add(_downloadTile(tile['x']!, tile['y']!, zoom, layer));
      }
      await Future.wait(futures);
      
      _downloadedTiles += slice.length;
      _currentProgress = _totalTilesToDownload > 0
          ? _downloadedTiles / _totalTilesToDownload
          : 0.0;

      _progressController.add({
        'status': 'Downloading $layer layer (zoom $zoom)...',
        'progress': _currentProgress,
        'downloadedTiles': _downloadedTiles,
        'totalTiles': _totalTilesToDownload,
        'currentZoom': zoom,
        'currentLayer': layer,
        'currentFileSize': _currentFileSize,
        'totalFileSize': _totalFileSize,
      });
      
      final percent = (_currentProgress * 100).clamp(0, 100).round();
      await DownloadNotificationService.showDownloadProgress(
        title: '🗺️ Czech Republic',
        progress: percent,
        total: 100,
      );
    }
  }
  
  /// Download a single tile
  static Future<void> _downloadTile(int x, int y, int z, String layer) async {
    try {
      final tileKey = '${z}_${x}_${y}';
      
      // Check if already cached
      final cachedTile = await VectorTileProvider.getCachedTile(tileKey, layer);
      if (cachedTile != null && cachedTile.isValid) {
        return; // Already cached and valid
      }
      
      // Get layer-specific URL
      final url = _getLayerUrl(z, x, y, layer);
      
      final bytes = await _fetchTileBytes(url);
      if (bytes != null) {
        // Compress and cache the tile
        final tileData = VectorTileData.compress(bytes, layer);
        await VectorTileProvider.cacheTile(tileKey, tileData, layer);
        
        // Update file size statistics
        _currentFileSize += bytes.length;
        
        // Update metadata
        await VectorTileProvider.updateTileMetadata(tileKey, {
          'layer': layer,
          'zoom': z,
          'x': x,
          'y': y,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'size': bytes.length,
          'compressedSize': tileData.compressedSize,
          'compressionRatio': tileData.compressionRatio,
        });
        
        print('🗺️ Downloaded and cached tile: $tileKey ($layer) - Compression: ${(tileData.compressionRatio * 100).toStringAsFixed(1)}%');
      }
    } catch (e) {
      print('❌ Failed to download tile ${z}/${x}/${y} ($layer): $e');
    }
  }
  
  /// Get layer-specific URL
  static String _getLayerUrl(int z, int x, int y, String layer) {
    switch (layer) {
      case 'base':
        return 'https://tile.openstreetmap.org/$z/$x/$y.png';
      case 'transport':
        return 'https://tile.openstreetmap.org/$z/$x/$y.png'; // Same for now
      case 'labels':
        return 'https://tile.openstreetmap.org/$z/$x/$y.png'; // Same for now
      default:
        return 'https://tile.openstreetmap.org/$z/$x/$y.png';
    }
  }
  
  /// Get tile coordinate range for bounds (no allocation of full list)
  static Map<String, int?> _getTileRangeForBounds(LatLng southwest, LatLng northeast, int zoom) {
    final n = pow(2, zoom).toDouble();
    int minTileX = ((southwest.longitude + 180) / 360 * n).floor();
    int maxTileX = ((northeast.longitude + 180) / 360 * n).floor();
    int minTileY = ((1 - log(tan(northeast.latitude * pi / 180) + 1 / cos(northeast.latitude * pi / 180)) / pi) / 2 * n).floor();
    int maxTileY = ((1 - log(tan(southwest.latitude * pi / 180) + 1 / cos(southwest.latitude * pi / 180)) / pi) / 2 * n).floor();

    // Clamp to grid
    final int maxIndex = n.toInt() - 1;
    minTileX = minTileX.clamp(0, maxIndex);
    maxTileX = maxTileX.clamp(0, maxIndex);
    minTileY = minTileY.clamp(0, maxIndex);
    maxTileY = maxTileY.clamp(0, maxIndex);

    // Ensure ordering
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

  /// Zoom-dependent stepping to drastically reduce high-zoom tiles
  static int _getStepForZoom(int z) {
    if (z <= 12) return 1;      // full coverage
    if (z == 13) return 1;
    if (z == 14) return 1;
    if (z == 15) return 2;
    if (z == 16) return 4;
    if (z == 17) return 6;      // slightly coarser than 4, still dense
    return 8;                    // z >= 18
  }

  /// Check if tile center lies within Czech Republic bounding limits
  static bool _isTileCenterInCzechRepublic(int x, int y, int z) {
    try {
      final n = pow(2, z).toDouble();
      // tile center coordinates
      final tileCenterLng = (x + 0.5) / n * 360.0 - 180.0;
      final r = pi * (1.0 - 2.0 * (y + 0.5) / n);
      final tileCenterLat = 180.0 / pi * atan(_sinh(r));
      return tileCenterLat >= 48.55 && tileCenterLat <= 51.06 &&
             tileCenterLng >= 12.09 && tileCenterLng <= 18.86;
    } catch (_) {
      return false;
    }
  }

  // Simple sinh implementation to avoid needing dart:math's missing function in some contexts
  static double _sinh(double x) {
    final ex = exp(x);
    final enx = exp(-x);
    return (ex - enx) / 2.0;
  }
  
  /// Stop download
  static void stopDownload() {
    _isDownloading = false;
    print('🗺️ Mapy.cz-style download stopped');
  }
  
  /// Get download statistics
  static Map<String, dynamic> getDownloadStats() {
    final cacheStats = VectorTileProvider.getCacheStats();
    
    return {
      'isDownloading': _isDownloading,
      'currentStatus': _currentStatus,
      'currentProgress': _currentProgress,
      'downloadedTiles': _downloadedTiles,
      'totalTilesToDownload': _totalTilesToDownload,
      'currentFileSize': _currentFileSize,
      'totalFileSize': _totalFileSize,
      'currentLayer': _currentLayer,
      'currentZoomLevel': _currentZoomLevel,
      'cacheStats': cacheStats,
      'compressionEnabled': true,
      'layeringEnabled': true,
      'incrementalUpdates': true,
    };
  }
  
  /// Clear all cached data
  static Future<void> clearCache() async {
    await VectorTileProvider.clearCache();
    print('🗺️ Mapy.cz-style cache cleared');
  }
} 