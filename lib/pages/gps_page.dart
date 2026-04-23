import 'dart:async';
import 'dart:ui' as ui;
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

import 'package:strakataturistikaandroidapp/services/vector_tile_provider.dart';
import 'package:strakataturistikaandroidapp/services/mapy_cz_download_service.dart';
import 'package:strakataturistikaandroidapp/services/tracking_state_service.dart';
import 'package:strakataturistikaandroidapp/services/haptic_service.dart';
import 'package:strakataturistikaandroidapp/widgets/ui/app_toast.dart';

import 'package:strakataturistikaandroidapp/models/tracking_summary.dart';
import 'package:strakataturistikaandroidapp/utils/gps_utils.dart';

import 'package:strakataturistikaandroidapp/animations/gps_animations.dart';
import 'package:strakataturistikaandroidapp/services/gps_services.dart';
import 'package:strakataturistikaandroidapp/services/scoring_config_service.dart';
import 'package:strakataturistikaandroidapp/services/error_recovery_service.dart';
import 'package:strakataturistikaandroidapp/services/gps_shortcut_bridge.dart';
import 'package:strakataturistikaandroidapp/pages/dynamic_upload_page.dart';
import 'package:strakataturistikaandroidapp/services/competition_dashboard_service.dart';

import 'package:strakataturistikaandroidapp/config/app_colors.dart';
import 'package:strakataturistikaandroidapp/widgets/ui/app_button.dart';
import 'package:strakataturistikaandroidapp/widgets/ui/strakata_primitives.dart';
import 'package:strakataturistikaandroidapp/widgets/gps/tracking_bottom_sheet.dart';
import 'package:strakataturistikaandroidapp/widgets/gps/tracking_onboarding_sheet.dart';
import '../widgets/maps/shared_map_widget.dart';

class GpsPage extends StatefulWidget {
  const GpsPage({super.key});

  @override
  State<GpsPage> createState() => _GpsPageState();
}

class _GpsPageState extends State<GpsPage> with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  final TrackingStateService _trackingStateService = TrackingStateService();

  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late AnimationController _speedPulseController;
  late AnimationController _fadeController;
  late AnimationController _bounceController;
  late AnimationController _panelSlideController;
  late AnimationController _scaleController;
  late AnimationController _topQuickSheetController;

  // Animations
  late Animation<double> _pulseAnimation;

  // State variables
  LatLng? _currentLocation;
  double? _currentSpeed;
  double? _currentAltitude;
  double? _currentHeading;
  // Speed smoothing
  final List<double> _recentSpeeds = <double>[]; // m/s
  static const int _recentSpeedsWindow = 8;
  static const double _stationaryThresholdMs = 0.6; // ~2.2 km/h

  bool _isMapReady = false;
  bool _hasInitiallyCentered = false;
  Timer? _updateTimer;
  Timer? _networkTimer;
  bool _isOnline = true;
  // Smart prefetch debounce
  Timer? _prefetchDebounce;

  // Map centering state
  bool _showRecenterButton = false;
  double _currentZoom = 8.0;

  // Location stream for passive updates
  StreamSubscription<Position>? _positionStreamSub;
  StreamSubscription<bool>? _trackingStateSub;

  // Map state persistence
  static LatLng? _lastMapCenter;
  static double? _lastMapZoom;

  // Sheet state
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  double _sheetExtent = 0.18;
  double _topQuickDragStartValue = 0.0;
  double _topQuickDragAccum = 0.0;
  MonthlyThemeData? _monthlyTheme;
  List<StrakataRouteData> _strakataRoutes = const [];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startUpdateTimer();
    _startNetworkMonitor();
    // Ensure tracking service is initialized so native location events are received
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await GpsServices.initializeEnhancedGPSTracking(_trackingStateService);
        await VectorTileProvider.initialize();
      } catch (_) {}
    });
    _startPassiveLocationUpdates();
    _loadCompetitionData();
    _trackingStateSub = _trackingStateService.trackingStateStream.listen((isTracking) {
      if (!mounted) return;
      if (isTracking) {
        _pulseController.repeat(reverse: true);
        _panelSlideController.forward();
        if (_topQuickSheetController.value > 0.0) {
          _animateTopQuickSheet(expand: false);
        }
      } else {
        _pulseController.stop();
        _panelSlideController.reverse();
      }
    });
    GpsShortcutBridge.startTracking.addListener(_handleShortcutStartTracking);
  }

  Future<void> _loadCompetitionData() async {
    final theme = await CompetitionDashboardService().getCurrentMonthlyTheme();
    final routes = await CompetitionDashboardService().getActiveStrakataRoutes();
    if (!mounted) return;
    setState(() {
      _monthlyTheme = theme;
      _strakataRoutes = routes;
    });
  }

  void _initializeAnimations() {
    _pulseController = GpsAnimations.createPulseController(this);
    _slideController = GpsAnimations.createSlideController(this);
    _speedPulseController = GpsAnimations.createSpeedPulseController(this);
    _fadeController = GpsAnimations.createFadeController(this);
    _bounceController = GpsAnimations.createBounceController(this);
    _scaleController = GpsAnimations.createScaleController(this);
    _panelSlideController = GpsAnimations.createPanelSlideController(this);
    _topQuickSheetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
      value: 0.0,
    );

    _pulseAnimation = GpsAnimations.createPulseAnimation(_pulseController);

    GpsAnimations.initializeAnimations(
      pulseController: _pulseController,
      slideController: _slideController,
      fadeController: _fadeController,
      panelSlideController: _panelSlideController,
    );
  }

  void _animateTopQuickSheet({required bool expand}) {
    if (expand) {
      _topQuickSheetController.animateTo(
        1.0,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    } else {
      _topQuickSheetController.animateBack(
        0.0,
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _startPassiveLocationUpdates() async {
    // Check permissions without requesting them aggressively yet
    final status = await GpsServices.checkPermissionsStatus();
    final hasLocation = status['location'] ?? false;

    if (hasLocation) {
      _positionStreamSub?.cancel();
      try {
        _positionStreamSub =
            Geolocator.getPositionStream(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.high,
                distanceFilter: 5,
              ),
            ).listen(
              (Position position) {
                if (!mounted) return;

                // Only update local state if NOT tracking (tracking service handles source of truth then)
                if (!_trackingStateService.isTracking) {
                  setState(() {
                    _currentLocation = LatLng(
                      position.latitude,
                      position.longitude,
                    );
                    _currentHeading = position.heading;
                    _currentAltitude = position.altitude;
                    // Speed is usually 0 if stationary, but we can capture it
                    _currentSpeed = position.speed;

                    // Center map if not centered yet
                    if (!_hasInitiallyCentered && _isMapReady) {
                      _smoothMoveToLocation(_currentLocation!);
                      _hasInitiallyCentered = true;
                    }
                  });
                }
              },
              onError: (e) {
                print('Passive location stream error: $e');
              },
            );
      } catch (e) {
        print('Failed to start passive location: $e');
      }
    }
  }

  void _startUpdateTimer() {
    _updateTimer = Timer.periodic(const Duration(milliseconds: 800), (timer) {
      if (mounted) {
        setState(() {
          // Update current location from tracking service
          final summary = _trackingStateService.getSummary();
          if (_trackingStateService.isTracking &&
              summary.trackPoints.isNotEmpty) {
            final lastPoint = summary.trackPoints.last;
            _currentLocation = lastPoint.toLatLng();
            // Speed smoothing & stationary detection
            final s = lastPoint.speed;
            _recentSpeeds.add(s);
            if (_recentSpeeds.length > _recentSpeedsWindow) {
              _recentSpeeds.removeAt(0);
            }
            final avg = _recentSpeeds.isEmpty
                ? s
                : _recentSpeeds.reduce((a, b) => a + b) / _recentSpeeds.length;
            final isStationary = avg < _stationaryThresholdMs;
            _currentSpeed = isStationary ? 0.0 : avg;
            // Animate speed pulse only when moving
            if (isStationary) {
              if (_speedPulseController.isAnimating) {
                _speedPulseController.stop();
              }
            } else {
              if (!_speedPulseController.isAnimating) {
                _speedPulseController.repeat(reverse: true);
              }
            }
            _currentAltitude = lastPoint.altitude;
            _currentHeading = lastPoint.heading;
            // Center on first valid fix once the map is ready
            if (!_hasInitiallyCentered &&
                _currentLocation != null &&
                _isMapReady) {
              _smoothMoveToLocation(_currentLocation!);
              _hasInitiallyCentered = true;
            }
          } else {
            // Not tracking: clear transient indicators
            _recentSpeeds.clear();
            _currentSpeed = null;
            _currentHeading = null;
            _currentAltitude = null;
            if (_speedPulseController.isAnimating) {
              _speedPulseController.stop();
            }
          }
        });
      }
    });
  }

  void _smoothMoveToLocation(LatLng location) {
    // Smooth map movement with easing
    _mapController.move(location, 16.0);
  }

  void _startNetworkMonitor() {
    // Initial check
    ErrorRecoveryService().isNetworkAvailable().then((available) {
      if (mounted) {
        _updateOnlineState(available);
      }
    });
    _networkTimer?.cancel();
    _networkTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      final available = await ErrorRecoveryService().isNetworkAvailable();
      if (mounted) {
        _updateOnlineState(available);
      }
    });
  }

  void _updateOnlineState(bool online) {
    if (_isOnline == online) return;
    setState(() {
      _isOnline = online;
    });

    // When coming back online, refresh tiles with smooth transition
    if (online && _isMapReady) {
      _refreshTilesOnOnline();
    }
  }

  void _refreshTilesOnOnline() {
    if (!_isMapReady) return;

    final cam = _mapController.camera;
    final center = cam.center;
    final zoom = cam.zoom;

    // Small movement to trigger tile refresh without jarring user
    final offset = 0.0001; // Very small offset
    final newCenter = LatLng(
      center.latitude + offset,
      center.longitude + offset,
    );

    // Smooth transition to refresh tiles
    _mapController.move(newCenter, zoom);

    // After a brief moment, move back to original position
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_isMapReady) {
        _mapController.move(center, zoom);
      }
    });
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    _networkTimer?.cancel();
    _prefetchDebounce?.cancel();
    _positionStreamSub?.cancel();
    _trackingStateSub?.cancel();
    GpsShortcutBridge.startTracking.removeListener(
      _handleShortcutStartTracking,
    );

    GpsAnimations.disposeAnimations(
      pulseController: _pulseController,
      slideController: _slideController,
      speedPulseController: _speedPulseController,
      fadeController: _fadeController,
      bounceController: _bounceController,
      scaleController: _scaleController,
      panelSlideController: _panelSlideController,
    );
    _topQuickSheetController.dispose();
    super.dispose();
  }

  void _handleShortcutStartTracking() {
    if (!mounted || !GpsShortcutBridge.startTracking.value) return;
    GpsShortcutBridge.consumeStartTracking();
    if (!_trackingStateService.isTracking) {
      _startTracking();
    }
  }

  Future<void> _startTracking() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Spustit sledování'),
          content: const Text('Opravdu chcete spustit GPS sledování?'),
          actions: [
            AppButton(
              onPressed: () => Navigator.of(context).pop(false),
              text: 'Zrušit',
              type: AppButtonType.ghost,
              size: AppButtonSize.small,
            ),
            AppButton(
              onPressed: () => Navigator.of(context).pop(true),
              text: 'Spustit',
              type: AppButtonType.primary,
              size: AppButtonSize.small,
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      // 1. Check if GPS service is enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        GpsServices.showGPSDisabledDialog(context); // Helper we kept/refactored
        return;
      }

      // 2. Check permissions status
      final status = await GpsServices.checkPermissionsStatus();
      bool allGranted =
          (status['location'] ?? false) &&
          (status['background'] ?? false) &&
          (status['battery_granted'] ?? false);

      if (!allGranted) {
        // Show SIMPLIFIED Onboarding Sheet
        final result = await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => const TrackingOnboardingSheet(),
        );

        // If sheet returns true (user clicked "Hotovo" or auto-closed),
        // we check one last time just to be sure, then valid = true
        if (result == true) {
          final finalStatus = await GpsServices.checkPermissionsStatus();
          if ((finalStatus['location'] ?? false) &&
              (finalStatus['background'] ?? false) &&
              (finalStatus['battery_granted'] ?? false)) {
            allGranted = true;
          }
        } else {
          // User cancelled the wizard
          return;
        }
      }

      // 3. Start tracking if permissions are good
      if (allGranted) {
        await GpsServices.startTracking(
          trackingStateService: _trackingStateService,
          context: context,
          onSuccess: () => _pulseController.repeat(reverse: true),
        );
      }
    }
  }

  Future<void> _stopTracking() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Zastavit sledování'),
          content: const Text('Opravdu chcete zastavit GPS sledování?'),
          actions: [
            AppButton(
              onPressed: () => Navigator.of(context).pop(false),
              text: 'Zrušit',
              type: AppButtonType.ghost,
              size: AppButtonSize.small,
            ),
            AppButton(
              onPressed: () => Navigator.of(context).pop(true),
              text: 'Zastavit',
              type: AppButtonType.destructive,
              size: AppButtonSize.small,
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await GpsServices.stopTracking(
        trackingStateService: _trackingStateService,
        context: context,
        onSuccess: () {
          _pulseController.stop();
          HapticService.mediumImpact();
          // Clear UI indicators on stop
          setState(() {
            _recentSpeeds.clear();
            _currentSpeed = null;
            _currentHeading = null;
            _currentAltitude = null;
            _hasInitiallyCentered = false;
          });
          if (_speedPulseController.isAnimating) {
            _speedPulseController.stop();
          }
        },
        showTrackingSummary: _showTrackingSummary,
      );
    }
  }

  void _toggleTracking() {
    HapticService.selectionClick();
    if (_trackingStateService.isTracking) {
      if (_trackingStateService.isRecordingPaused) {
        _resumeTracking();
      } else {
        _pauseTracking();
      }
    } else {
      _startTracking();
    }
  }

  void _pauseTracking() {
    _trackingStateService.setRecordingPaused(true);
    _pulseController.stop();
    HapticService.mediumImpact();
    setState(() {});
  }

  void _resumeTracking() {
    _trackingStateService.setRecordingPaused(false);
    _pulseController.repeat(reverse: true);
    HapticService.selectionClick();
    setState(() {});
  }

  void _showSimulateSheet() async {
    final cfg = await ScoringConfigService().getConfig();
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final presets = [
          _SimPreset('Krátká procházka', 1.5, Icons.directions_walk),
          _SimPreset(
            'Základní (min. vzdálenost)',
            cfg.minDistanceKm,
            Icons.flag_circle,
          ),
          _SimPreset('Delší trasa', 5.0, Icons.terrain),
          _SimPreset('Dlouhá trasa', 10.0, Icons.hiking),
          _SimPreset('Městská křivkovaná', 4.0, Icons.route, useSmart: true),
        ];
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.55,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (_, controller) => Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(child: StrakataSheetHandle()),
                const SizedBox(height: 12),
                const Text(
                  'Simulovat trasu',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  'Vyberte jednu z předvyplněných tras. Body za vzdálenost se počítají podle aktuálního bodování. Body za místa (vrchol/rozhledna/strom) přidáte v detailu návštěvy po ukončení.',
                  style: TextStyle(color: Colors.grey[700]),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    controller: controller,
                    itemCount: presets.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final p = presets[i];
                      final distancePoints = (p.km >= cfg.minDistanceKm)
                          ? (p.km * cfg.pointsPerKm)
                          : 0.0;
                      return InkWell(
                        onTap: () async {
                          Navigator.of(ctx).pop();
                          await _simulatePreset(p);
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF4CAF50,
                                  ).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  p.icon,
                                  color: const Color(0xFF4CAF50),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p.label,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF111827),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        _chip('${p.km.toStringAsFixed(1)} km'),
                                        const SizedBox(width: 6),
                                        _chip(
                                          'Body za vzd.: ${distancePoints.toStringAsFixed(1)}',
                                        ),
                                        if (p.useSmart) ...[
                                          const SizedBox(width: 6),
                                          _chip('Křivkovaná trasa'),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.play_arrow,
                                color: Color(0xFF4CAF50),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          color: Color(0xFF374151),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Future<void> _simulatePreset(_SimPreset preset) async {
    // Ensure tracking is started
    if (!_trackingStateService.isTracking) {
      await _startTracking();
      await Future.delayed(const Duration(milliseconds: 300));
    }
    HapticService.mediumImpact();

    final start = _currentLocation ?? const LatLng(50.0755, 14.4378);
    final points = preset.useSmart
        ? GpsUtils.generateSmartRoute()
        : _generateLoopRoute(start, preset.km);

    // Feed points instantly with small time deltas to avoid huge distances
    DateTime t = DateTime.now();
    for (int i = 0; i < points.length; i++) {
      final p = points[i];
      t = t.add(const Duration(seconds: 2));
      final position = Position(
        latitude: p.latitude,
        longitude: p.longitude,
        timestamp: t,
        accuracy: 6.0,
        altitude: 200.0,
        altitudeAccuracy: 5.0,
        heading: 90.0,
        headingAccuracy: 5.0,
        speed: 2.0,
        speedAccuracy: 1.0,
      );
      _trackingStateService.forceAddPosition(position);
    }

    // Removed simulation completion toast per request
  }

  List<LatLng> _generateLoopRoute(LatLng start, double targetKm) {
    final List<LatLng> pts = [];
    final totalMeters = (targetKm * 1000).clamp(200, 50000).toDouble();
    const stepMeters = 30.0; // ~30m between points for smoothness
    final steps = (totalMeters / stepMeters).round();
    final latRad = start.latitude * (pi / 180);
    final dLatPerM = 1 / 111320.0;
    final dLngPerM = 1 / (111320.0 * cos(latRad));
    // Create a rectangular loop path (2:1 aspect)
    final perSide = steps ~/ 4;
    LatLng cur = start;
    // East
    for (int i = 0; i < perSide; i++) {
      cur = LatLng(cur.latitude, cur.longitude + stepMeters * dLngPerM);
      pts.add(cur);
    }
    // North
    for (int i = 0; i < perSide; i++) {
      cur = LatLng(cur.latitude + stepMeters * dLatPerM, cur.longitude);
      pts.add(cur);
    }
    // West
    for (int i = 0; i < perSide; i++) {
      cur = LatLng(cur.latitude, cur.longitude - stepMeters * dLngPerM);
      pts.add(cur);
    }
    // South
    for (int i = 0; i < perSide; i++) {
      cur = LatLng(cur.latitude - stepMeters * dLatPerM, cur.longitude);
      pts.add(cur);
    }
    // If leftover steps due to rounding, continue east
    final leftover = steps - (perSide * 4);
    for (int i = 0; i < leftover; i++) {
      cur = LatLng(cur.latitude, cur.longitude + stepMeters * dLngPerM);
      pts.add(cur);
    }
    return pts;
  }

  void _showTrackingSummary(TrackingSummary summary, [String? draftId]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildSummarySheet(summary, draftId),
    );
  }

  Widget _buildSummarySheet(TrackingSummary summary, String? draftId) {
    final duration = summary.duration;
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;
    final distanceKm = summary.totalDistance / 1000;
    final avgSpeedKmh = summary.averageSpeed * 3.6;
    final maxSpeedKmh = summary.maxSpeed * 3.6;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          Center(child: StrakataSheetHandle(color: AppColors.border)),
          const SizedBox(height: 16),
          if (draftId != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: AppColors.secondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Trasa byla uložena jako návrh. Můžete doplnit informace později.',
                        style: TextStyle(
                          color: AppColors.secondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (draftId != null) const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Shrnutí trasy',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.5,
                children: [
                  _buildStatCard(
                    'Doba',
                    '${hours}h ${minutes}m ${seconds}s',
                    Icons.timer_outlined,
                  ),
                  _buildStatCard(
                    'Vzdálenost',
                    '${distanceKm.toStringAsFixed(2)} km',
                    Icons.straighten,
                  ),
                  _buildStatCard(
                    'Průměrná rychlost',
                    '${avgSpeedKmh.toStringAsFixed(1)} km/h',
                    Icons.speed,
                  ),
                  _buildStatCard(
                    'Max rychlost',
                    '${maxSpeedKmh.toStringAsFixed(1)} km/h',
                    Icons.trending_up,
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: AppColors.border, width: 1.2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      'Doplnit později',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) =>
                              const DynamicUploadPage(slug: 'gps-tracking'),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.textPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Doplnit a odeslat',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: AppColors.textPrimary, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // follow-location toggle removed; we now only recenter on first fix or via the recenter pill

  void _centerOnLocation() {
    if (_currentLocation != null) {
      // Smooth map movement with animation
      _mapController.move(_currentLocation!, 16.0);
      _bounceController.forward().then((_) => _bounceController.reverse());

      AppToast.showSuccess(context, 'Vycentrováno na vaši polohu');
    }
  }

  void _openUploadFromTopSheet(String slug, {String? toast}) {
    if (toast != null && toast.isNotEmpty) {
      AppToast.showInfo(context, toast);
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DynamicUploadPage(slug: slug)),
    );
  }

  void _showScoredPlacesSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.52,
        minChildSize: 0.36,
        maxChildSize: 0.86,
        snap: true,
        snapSizes: const [0.36, 0.52, 0.86],
        builder: (_, controller) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: Container(
            color: const Color(0xFFFFFBF7),
            child: ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
              children: [
                const Center(child: StrakataSheetHandle()),
                const SizedBox(height: 10),
                const Text(
                  'Bodovaná místa z mapy',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 6),
                Text(
                  'Vyberte kategorii a otevřete nahrání trasy s navštívenými místy.',
                  style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 14),
                if (_strakataRoutes.isEmpty)
                  const Text('Aktivní bodované kategorie teď nejsou dostupné.')
                else
                  ..._strakataRoutes.map(
                    (r) => Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () {
                            Navigator.of(ctx).pop();
                            _openUploadFromTopSheet(
                              'gps-tracking',
                              toast: 'Vybraná kategorie: ${r.label}. Doplňte ji v detailech návštěvy.',
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF4F0E8),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFE8E4DC)),
                            ),
                            child: Row(
                              children: [
                                Text(r.icon, style: const TextStyle(fontSize: 20)),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    r.label,
                                    style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                  ),
                                ),
                                const Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: _trackingStateService.trackingStateStream,
      builder: (context, snapshot) {
        final isTracking = snapshot.data ?? false;

        return Scaffold(
          extendBodyBehindAppBar: true,
          body: Stack(
            children: [
              SharedMapWidget(
                mapController: _mapController,
                center: _lastMapCenter ?? const LatLng(49.8175, 15.4730),
                zoom: _lastMapZoom ?? 8.0,
                onMapReady: () {
                  _isMapReady = true;
                  _currentZoom = _mapController.camera.zoom;
                  if (_currentLocation != null && !_hasInitiallyCentered) {
                    _smoothMoveToLocation(_currentLocation!);
                    _hasInitiallyCentered = true;
                  }
                },
                onPositionChanged: (MapPosition position, bool hasGesture) {
                  final newZoom = position.zoom ?? _mapController.camera.zoom;
                  if (newZoom != _currentZoom) {
                    _currentZoom = newZoom;
                  }
                  if (hasGesture) {
                    if (!_showRecenterButton) {
                      setState(() {
                        _showRecenterButton = true;
                      });
                    }
                  }
                  // Save map state
                  _lastMapCenter = position.center;
                  _lastMapZoom = position.zoom;
                },
                markers: _currentLocation != null
                    ? [
                        Marker(
                          point: _currentLocation!,
                          width: 60,
                          height: 60,
                          child: GestureDetector(
                            onTap: () {
                              _pulseController.forward(from: 0.0);
                              HapticService.selectionClick();
                            },
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                if (_trackingStateService.isTracking)
                                  ScaleTransition(
                                    scale: _pulseAnimation,
                                    child: Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(
                                          alpha: 0.3,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                                if (_currentHeading != null)
                                  Transform.rotate(
                                    angle: (_currentHeading! * (3.14159 / 180)),
                                    child: CustomPaint(
                                      size: const Size(100, 100),
                                      painter: DirectionalConePainter(),
                                    ),
                                  ),
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 3,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.3,
                                        ),
                                        blurRadius: 6,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ]
                    : [],
                polylines:
                    (_trackingStateService.isTracking &&
                        _trackingStateService
                            .getSummary()
                            .trackPoints
                            .isNotEmpty)
                    ? [
                        Polyline(
                          points: _trackingStateService
                              .getSummary()
                              .trackPoints
                              .map((p) => p.toLatLng())
                              .toList(),
                          strokeWidth: 8,
                          color: Colors.white.withValues(alpha: 0.75),
                        ),
                        Polyline(
                          points: _trackingStateService
                              .getSummary()
                              .trackPoints
                              .map((p) => p.toLatLng())
                              .toList(),
                          strokeWidth: 4.5,
                          color: AppColors.primary,
                        ),
                      ]
                    : [],
              ),

              // 2. Map Controls - Positioned above sheet
              Positioned(
                bottom:
                    MediaQuery.of(context).size.height *
                    0.22, // Above collapsed sheet
                right: 16,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedScale(
                      scale: _showRecenterButton ? 1.0 : 0.92,
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      child: AnimatedOpacity(
                        opacity: _showRecenterButton ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 180),
                        child: IgnorePointer(
                          ignoring: !_showRecenterButton,
                          child: Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: _centerOnLocation,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: BackdropFilter(
                                  filter: ui.ImageFilter.blur(
                                    sigmaX: 8,
                                    sigmaY: 8,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.88,
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.7,
                                        ),
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.14,
                                          ),
                                          blurRadius: 12,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.my_location,
                                      color: Colors.black87,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 3. Top Gradient for Status Bar visibility
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 100,
                child: AnimatedOpacity(
                  opacity: _sheetExtent > 0.95 ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: 0.6),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              _buildTopQuickActionSheet(isTracking),

              // 4. Offline/Download Indicators (Top Left)
              Positioned(
                top: MediaQuery.of(context).padding.top + 10,
                left: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      child: !_isOnline
                          ? Container(
                              key: const ValueKey('offline_badge'),
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red[50],
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.red[200]!),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.wifi_off,
                                    size: 16,
                                    color: Colors.red[700],
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Offline',
                                    style: TextStyle(
                                      color: Colors.red[700],
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),

              Positioned(
                top: MediaQuery.of(context).padding.top + 10,
                right: 16,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 240),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: isTracking
                      ? ClipRRect(
                          key: const ValueKey('tracking_hud'),
                          borderRadius: BorderRadius.circular(16),
                          child: BackdropFilter(
                            filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.82),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.65),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _trackingStateService.isRecordingPaused
                                        ? Icons.pause_circle_filled_rounded
                                        : Icons.radio_button_checked_rounded,
                                    size: 14,
                                    color:
                                        _trackingStateService.isRecordingPaused
                                        ? Colors.orange
                                        : AppColors.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${((_currentSpeed ?? 0.0) * 3.6).toStringAsFixed(1)} km/h',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ),

              // 5. Draggable Sheet
              NotificationListener<DraggableScrollableNotification>(
                onNotification: (notification) {
                  if ((notification.extent - _sheetExtent).abs() > 0.015) {
                    setState(() {
                      _sheetExtent = notification.extent;
                    });
                  }
                  return true;
                },
                child: DraggableScrollableSheet(
                  controller: _sheetController,
                  initialChildSize: 0.18,
                  minChildSize: 0.18,
                  maxChildSize: 1.0,
                  snap: true,
                  snapSizes: const [0.18, 0.42, 0.78, 1.0],
                  builder: (context, scrollController) {
                    return ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                      child: TrackingBottomSheet(
                        scrollController: scrollController,
                        summary: _trackingStateService.getSummary(),
                        currentSpeed: _currentSpeed,
                        currentAltitude: _currentAltitude,
                        isTracking: isTracking,
                        isPaused: _trackingStateService.isRecordingPaused,
                        onToggleTracking: _toggleTracking,
                        onPauseTracking: _pauseTracking,
                        onStopTracking: _stopTracking,
                        onCenterMap: _centerOnLocation,
                        sheetPosition: _sheetExtent,
                        onSimulateRoute: () => _showSimulateSheet(),
                        onOfflineMaps: () => _showOfflineManager(),
                        onClose: () {
                          _sheetController.animateTo(
                            0.42,
                            duration: const Duration(milliseconds: 360),
                            curve: Curves.easeOutCubic,
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showOfflineManager() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (_, controller) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(child: StrakataSheetHandle()),
              const SizedBox(height: 12),
              const Text(
                'Offline mapy',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: ListView(
                  controller: controller,
                  children: [
                    ListTile(
                      leading: const Icon(
                        Icons.cloud_done_outlined,
                        color: Color(0xFF4CAF50),
                      ),
                      title: const Text('Pokrytí aktuálního zobrazení'),
                      subtitle: FutureBuilder<double>(
                        future: VectorTileProvider.estimateCoverage(
                          southwest: LatLng(
                            _mapController.camera.center.latitude - 0.04,
                            _mapController.camera.center.longitude - 0.06,
                          ),
                          northeast: LatLng(
                            _mapController.camera.center.latitude + 0.04,
                            _mapController.camera.center.longitude + 0.06,
                          ),
                          zoom: _mapController.camera.zoom.floor().clamp(8, 16),
                        ),
                        builder: (context, snap) {
                          final v = ((snap.data ?? 0) * 100)
                              .clamp(0, 100)
                              .toStringAsFixed(0);
                          return Text('$v % dlaždic v cache');
                        },
                      ),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(
                        Icons.download_for_offline_outlined,
                        color: Color(0xFF4CAF50),
                      ),
                      title: const Text('Stáhnout aktuální zobrazení'),
                      subtitle: const Text(
                        'Stáhne mapu kolem aktuální pozice pro offline použití',
                      ),
                      onTap: () async {
                        Navigator.of(ctx).pop();
                        if (!_isOnline) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Offline: nelze stahovat'),
                            ),
                          );
                          return;
                        }
                        final cam = _mapController.camera;
                        final center = cam.center;
                        final zoom = cam.zoom;
                        // Build a small bounding box around current view approximating ~2km at current zoom
                        final latDelta =
                            0.05; // ~5.5km at mid-latitudes; conservative
                        final lngDelta = 0.08;
                        final sw = LatLng(
                          center.latitude - latDelta,
                          center.longitude - lngDelta,
                        );
                        final ne = LatLng(
                          center.latitude + latDelta,
                          center.longitude + lngDelta,
                        );
                        // Choose zoom band centered around current zoom
                        final minZ = zoom.floor().clamp(8, 14);
                        final maxZ = (zoom.floor() + 2).clamp(10, 16);
                        await MapyCzDownloadService.downloadBounds(
                          southwest: sw,
                          northeast: ne,
                          minZoom: minZ,
                          maxZoom: maxZ,
                          concurrency: 24,
                          batchSize: 800,
                        );
                        // Refresh tiles to leverage fresh cache
                        _mapController.move(
                          _mapController.camera.center,
                          _mapController.camera.zoom,
                        );
                        if (mounted) {
                          AppToast.showInfo(
                            context,
                            'Offline dlaždice se stahují na pozadí',
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      leading: const Icon(
                        Icons.select_all,
                        color: Color(0xFF111827),
                      ),
                      title: const Text('Stáhnout dle výběru oblasti'),
                      subtitle: const Text(
                        'Vyberte obdélník přes mapu a stáhněte dlaždice předem',
                      ),
                      onTap: () async {
                        Navigator.of(ctx).pop();
                        // Simple selection: use current view with wider margins as preset
                        if (!_isOnline) {
                          AppToast.showError(
                            context,
                            'Offline: nelze stahovat',
                          );
                          return;
                        }
                        final cam = _mapController.camera;
                        final c = cam.center;
                        final z = cam.zoom.floor();
                        final sw = LatLng(
                          c.latitude - 0.12,
                          c.longitude - 0.18,
                        );
                        final ne = LatLng(
                          c.latitude + 0.12,
                          c.longitude + 0.18,
                        );
                        await MapyCzDownloadService.downloadBounds(
                          southwest: sw,
                          northeast: ne,
                          minZoom: z.clamp(8, 14),
                          maxZoom: (z + 2).clamp(10, 16),
                          concurrency: 24,
                          batchSize: 800,
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      leading: const Icon(
                        Icons.cleaning_services_outlined,
                        color: Color(0xFFF59E0B),
                      ),
                      title: const Text('Vyčistit cache'),
                      onTap: () async {
                        await MapyCzDownloadService.clearCache();
                        if (mounted) {
                          AppToast.showSuccess(context, 'Cache byla vyčištěna');
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopQuickActionSheet(bool isTracking) {
    final topInset = MediaQuery.of(context).padding.top;
    const expandedHeight = 292.0;
    const collapsedVisible = 46.0;
    const collapsedOffset = expandedHeight - collapsedVisible;

    return AnimatedBuilder(
      animation: _topQuickSheetController,
      builder: (context, child) {
        final t = _topQuickSheetController.value.clamp(0.0, 1.0);
        final top = ui.lerpDouble(
          topInset + 8 - collapsedOffset,
          topInset + 8,
          t,
        )!;
        final contentOpacity = Curves.easeOut.transform(t);
        final isExpandedEnough = t > 0.15;
        return Positioned(
          left: 12,
          right: 12,
          top: top,
          height: expandedHeight,
          child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragStart: (_) {
          _topQuickDragAccum = 0.0;
          _topQuickDragStartValue = _topQuickSheetController.value;
        },
        onVerticalDragUpdate: (details) {
          _topQuickDragAccum += details.delta.dy;
          final dragRange = expandedHeight - collapsedVisible;
          final next = (_topQuickDragStartValue + (_topQuickDragAccum / dragRange))
              .clamp(-0.08, 1.08);
          final softened = next < 0
              ? next * 0.35
              : (next > 1 ? 1 + (next - 1) * 0.35 : next);
          _topQuickSheetController.value = softened.clamp(0.0, 1.0);
        },
        onVerticalDragEnd: (details) {
          final velocity = details.primaryVelocity ?? 0.0;
          final drag = _topQuickDragAccum;
          final current = _topQuickSheetController.value;
          if (drag > 12 || velocity > 130) {
            _animateTopQuickSheet(expand: true);
          } else if (drag < -12 || velocity < -130) {
            _animateTopQuickSheet(expand: false);
          } else {
            _animateTopQuickSheet(expand: current >= 0.48);
          }
          _topQuickDragAccum = 0.0;
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white.withValues(alpha: 0.75)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: () => _animateTopQuickSheet(
                        expand: _topQuickSheetController.value < 0.5,
                      ),
                      child: Container(
                        width: 52,
                        height: 24,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0EBE3),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Icon(
                          isExpandedEnough ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.upload_file_rounded, size: 18, color: AppColors.textPrimary),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Rychlé nahrání souboru',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                        ),
                      ),
                      if (isTracking)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: const Color(0xFFA7F3D0)),
                          ),
                          child: const Text(
                            'Tracking běží',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF047857)),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 180),
                      opacity: contentOpacity,
                      child: IgnorePointer(
                        ignoring: !isExpandedEnough,
                        child: ListView(
                          physics: const BouncingScrollPhysics(),
                          padding: EdgeInsets.zero,
                          children: [
                            _quickActionRow(
                              icon: Icons.upload_file_outlined,
                              title: 'Nahrát GPX',
                              subtitle: 'Import z externí aplikace',
                              onTap: () => _openUploadFromTopSheet('gpx-upload'),
                            ),
                            _quickActionRow(
                              icon: Icons.photo_camera_outlined,
                              title: 'Nahrát screenshot',
                              subtitle: 'Screenshot trasy z mobilu',
                              onTap: () => _openUploadFromTopSheet('screenshot-upload'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  },
);
  }

  Widget _quickActionRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F0E8),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: AppColors.textSecondary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        subtitle,
                        style: TextStyle(fontSize: 12, color: Colors.grey[700], fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SimPreset {
  final String label;
  final double km;
  final IconData icon;
  final bool useSmart;
  _SimPreset(this.label, this.km, this.icon, {this.useSmart = false});
}

// Custom painter for the directional cone/ray
class DirectionalConePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final baseColor = const Color(0xFF4CAF50);

    // Create a cone shape pointing forward
    final path = ui.Path();

    // Start from the center (your position)
    final center = Offset(size.width / 2, size.height / 2);
    final tip = Offset(size.width / 2, size.height / 2 - 30); // Shorter cone
    const halfWidth = 20.0; // Wider cone

    // Triangle path (upwards; widget rotation applies heading)
    path.moveTo(center.dx, center.dy);
    path.lineTo(center.dx - halfWidth, tip.dy);
    path.lineTo(center.dx + halfWidth, tip.dy);
    path.close();

    // Linear gradient from center (opaque) to tip line (transparent)
    final gradientPaint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true
      ..shader = ui.Gradient.linear(
        center,
        tip,
        [
          baseColor.withValues(alpha: 0.6), // More transparent
          baseColor.withValues(alpha: 0.0),
        ],
        [0.0, 1.0],
      );

    // Draw the cone with gradient fill and no border
    canvas.drawPath(path, gradientPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
