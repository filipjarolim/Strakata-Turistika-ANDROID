import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'config/app_theme.dart';
import 'config/app_colors.dart';
import 'config/strakata_design_tokens.dart';
import 'animations/app_animations.dart';
import 'widgets/tab_switch.dart';
import 'widgets/custom_bottom_nav_bar.dart';
import 'pages/explore_tab.dart';
import 'pages/map_tab.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'services/notifications_service.dart';
import 'pages/webview_page.dart';
import 'services/database/database_service.dart';

import 'services/auth_service.dart';

import 'pages/onboarding/auth_gate.dart';
import 'pages/login_page.dart';
import 'pages/settings_page.dart';
import 'pages/user_profile_page.dart';
import 'pages/offline_maps_page.dart';

import 'pages/dynamic_form_page.dart';
import 'pages/results_page.dart';

import 'services/haptic_service.dart';

import 'services/error_recovery_service.dart';
import 'dart:ui';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'services/offline_ui_bridge.dart';
import 'services/app_update_service.dart';
import 'services/gps_services.dart'; // Added
import 'services/tracking_state_service.dart'; // Added
import 'services/vector_tile_provider.dart';
import 'services/app_shortcuts_service.dart';
import 'services/gps_shortcut_bridge.dart';
import 'package:url_launcher/url_launcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  try {
    await Firebase.initializeApp();

    // Initialize Crashlytics and Flutter error forwarding
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  } catch (e, st) {
    FirebaseCrashlytics.instance.recordError(
      e,
      st,
      reason: 'Firebase init failed',
    );
  }

  // Initialize MongoDB connection
  try {
    await DatabaseService().connect();
  } catch (e, st) {
    FirebaseCrashlytics.instance.recordError(
      e,
      st,
      reason: 'Mongo init failed',
    );
  }

  // Initialize Auth service
  try {
    await AuthService.initialize();
  } catch (e, st) {
    FirebaseCrashlytics.instance.recordError(e, st, reason: 'Auth init failed');
  }

  // Initialize new services
  try {
    // Parallelize independent service initialization
    await Future.wait([
      ErrorRecoveryService().initialize(),

      // Notifications: background handler and service init
      (() async {
        FirebaseMessaging.onBackgroundMessage(
          firebaseMessagingBackgroundHandler,
        );
        await NotificationsService().initialize();
      })(),

      // Initialize VectorTileProvider for offline maps
      VectorTileProvider.initialize().catchError((e) {
        print('⚠️ VectorTileProvider init failed: $e');
      }),

      // Initialize GPS Tracking Service
      (() async {
        try {
          final trackingStateService = TrackingStateService();
          await GpsServices.initializeEnhancedGPSTracking(trackingStateService);
        } catch (e) {
          print('⚠️ Extended GPS init failed in main: $e');
        }
      })(),
      AppShortcutsService().initialize(),
    ]);
  } catch (e, st) {
    FirebaseCrashlytics.instance.recordError(
      e,
      st,
      reason: 'Local services init failed',
    );
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Strakatá Turistika',
      debugShowCheckedModeBanner: false,
      locale: const Locale('cs', 'CZ'),
      supportedLocales: const [Locale('cs', 'CZ'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.lightTheme,
      themeMode: ThemeMode.light,
      // Use AuthGate as the initial route to handle permission and auth checks
      home: const AuthGate(),
      routes: {
        '/login': (context) => const LoginPage(),
        '/settings': (context) => const SettingsPage(),
        '/user-profile': (context) => const UserProfilePage(),
        '/offline-maps': (context) => const OfflineMapsPage(),
        '/visit-data-form': (context) => const DynamicFormPage(slug: 'gps-tracking'),
        '/tos': (context) => const WebViewPage(
          title: 'Podmínky použití',
          url: 'https://www.strakata.cz/terms',
        ),
        '/privacy': (context) => const WebViewPage(
          title: 'Zásady ochrany osobních údajů',
          url: 'https://www.strakata.cz/privacy',
        ),
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  int _currentIndex = 0;
  final TrackingStateService _trackingStateService = TrackingStateService();
  StreamSubscription<AppShortcutAction>? _shortcutSubscription;
  late final List<Widget?> _tabCache;
  late final VoidCallback _offlineOpenListener;

  // Notification handling
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _tabCache = List<Widget?>.filled(4, null, growable: false);
    _ensureTabInitialized(0);

    // Add lifecycle observer to handle app resume
    WidgetsBinding.instance.addObserver(this);
    _initializeAppShortcuts();

    // Create animations

    // Initialize notification handling
    _initializeNotificationHandling();
    // Listen for offline manager open requests
    _offlineOpenListener = () {
      if (OfflineUiBridge.openManager.value && mounted) {
        OfflineUiBridge.consumeOpenManager();
        Navigator.of(context)
            .push(MaterialPageRoute(builder: (context) => const OfflineMapsPage()));
      }
    };
    OfflineUiBridge.openManager.addListener(_offlineOpenListener);

    // Check for app updates after the first frame is rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        AppUpdateService.checkForUpdate(context);
      }
    });
  }

  @override
  void dispose() {
    // Remove lifecycle observer
    WidgetsBinding.instance.removeObserver(this);
    _shortcutSubscription?.cancel();
    OfflineUiBridge.openManager.removeListener(_offlineOpenListener);

    super.dispose();
  }

  void _initializeAppShortcuts() {
    final shortcuts = AppShortcutsService();
    _shortcutSubscription = shortcuts.actions.listen(_handleShortcutAction);
    final pending = shortcuts.consumePendingAction();
    if (pending != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleShortcutAction(pending);
      });
    }
  }

  Future<void> _handleShortcutAction(AppShortcutAction action) async {
    if (!mounted) return;
    switch (action) {
      case AppShortcutAction.openMap:
        await _onNavItemTapped(2);
        break;
      case AppShortcutAction.startTracking:
        await _onNavItemTapped(2);
        GpsShortcutBridge.requestStartTracking();
        break;
      case AppShortcutAction.openOffline:
        OfflineUiBridge.requestOpenManager();
        break;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // When app returns to foreground, reconnect to MongoDB
    if (state == AppLifecycleState.resumed) {
      _reconnectToDatabase();
    }
  }

  Future<void> _reconnectToDatabase() async {
    try {
      // Test if database is still connected
      final isConnected = DatabaseService().isConnected;

      if (!isConnected) {
        await DatabaseService().close();
        await DatabaseService().connect();
      }

      // Always refresh user data from database when app resumes
      if (AuthService.isLoggedIn) {
        await AuthService.refreshCurrentUser();
      }

      // Refresh current page to reload data
      // Intentionally avoid forced rebuild on resume to reduce UI jank.
    } catch (e) {
      FirebaseCrashlytics.instance.recordError(
        e,
        null,
        reason: 'Database reconnection failed',
      );
    }
  }

  void _initializeNotificationHandling() {
    // Handle notification taps
    _notifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        _handleNotificationTap(response);
      },
    );
  }

  void _handleNotificationTap(NotificationResponse response) {
    if (response.payload == 'gps_tracking_page') {
      // Switch to GPS tab instead of pushing a separate page
      _onNavItemTapped(2);
    }
  }

  Future<void> _onNavItemTapped(int index) async {
    if (index == 3) {
      await _showProfileQuickMenu();
      return;
    }
    if (index == _currentIndex) return;
    // Gate GPS tab (2) and Profile tab (3) for unauthenticated users
    if ((index == 2 || index == 3) && AuthService.currentUser == null) {
      await HapticService.lightImpact();
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      }
      return;
    }

    // Provide haptic feedback for navigation
    await HapticService.navigationTap();

    _ensureTabInitialized(index);
    setState(() {
      _currentIndex = index;
    });
  }

  void _ensureTabInitialized(int index) {
    if (_tabCache[index] != null) return;
    switch (index) {
      case 0:
        _tabCache[index] = const ExploreTab();
        break;
      case 1:
        _tabCache[index] = const ResultsPage();
        break;
      case 2:
        _tabCache[index] = const MapTab();
        break;
      case 3:
        _tabCache[index] = const UserProfilePage();
        break;
    }
  }

  Future<void> _showProfileQuickMenu() async {
    if (!mounted) return;
    await HapticService.lightImpact();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBF7),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: const Color(0xFFE8E4DC)),
          ),
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[350],
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
              const SizedBox(height: 12),
              _profileMenuItem(
                icon: Icons.person_outline_rounded,
                title: 'Profil',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  if (!mounted) return;
                  _ensureTabInitialized(3);
                  setState(() {
                    _currentIndex = 3;
                  });
                },
              ),
              _profileMenuItem(
                icon: Icons.download_for_offline_outlined,
                title: 'Offline mapy',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  if (!mounted) return;
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const OfflineMapsPage()),
                  );
                },
              ),
              _profileMenuItem(
                icon: Icons.description_outlined,
                title: 'Pravidla soutěže',
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  final url = Uri.parse('https://www.strakata.cz/pravidla');
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                },
              ),
              _profileMenuItem(
                icon: Icons.info_outline_rounded,
                title: 'O aplikaci',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  showAboutDialog(
                    context: context,
                    applicationName: 'Strakatá Turistika',
                    applicationVersion: '1.1.0',
                    applicationIcon: const Icon(Icons.hiking, size: 44, color: Color(0xFF2E7D32)),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _profileMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F0E8),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(icon, color: AppColors.textSecondary, size: 20),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const Spacer(),
                const Icon(Icons.chevron_right_rounded, color: Color(0xFF9CA3AF)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  context.strakataTokens?.heroOverlayTop ??
                      AppColors.heroOverlayTop,
                  AppColors.pageBg,
                  AppColors.surfaceMuted,
                ],
              ),
            ),
          ),
        ),
        // Home tab uses a light editorial background; no dark scrim.
        Positioned.fill(
          child: AnimatedOpacity(
            duration: AppAnimations.durationPageTransition,
            curve: AppAnimations.curveStandard,
            opacity: _currentIndex == 0 ? 0.0 : 1.0,
            child: Container(color: Theme.of(context).colorScheme.surface),
          ),
        ),
        Positioned.fill(
          child: Scaffold(
            extendBody:
                true, // Fixes navbar transparency issue by extending content behind it
            backgroundColor: Colors.transparent,
            body: TabSwitch(
              switchTo: _onNavItemTapped,
              child: IndexedStack(
                index: _currentIndex,
                children: [
                  _tabCache[0] ?? const SizedBox.shrink(),
                  _tabCache[1] ?? const SizedBox.shrink(),
                  _tabCache[2] ?? const SizedBox.shrink(),
                  _tabCache[3] ?? const SizedBox.shrink(),
                ],
              ),
            ),
            bottomNavigationBar: Material(
              color: Colors.transparent,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.bottomCenter,
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 260,
                    child: IgnorePointer(
                      child: AnimatedOpacity(
                        opacity: (_currentIndex == 0 || _currentIndex == 3)
                            ? 1.0
                            : 0.0,
                        duration: const Duration(milliseconds: 240),
                        curve: Curves.easeOutCubic,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.white,
                                Colors.white.withValues(alpha: 0.88),
                                Colors.white.withValues(alpha: 0.45),
                                Colors.white.withValues(alpha: 0),
                              ],
                              stops: const [0.0, 0.28, 0.58, 1.0],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  StreamBuilder<bool>(
                    stream: _trackingStateService.trackingStateStream,
                    initialData: _trackingStateService.isTracking,
                    builder: (context, trackingSnapshot) {
                      final isTracking = trackingSnapshot.data ?? false;
                      return StreamBuilder<String>(
                        stream: _trackingStateService.trackingInfoStream,
                        initialData: null,
                        builder: (context, infoSnapshot) {
                          return CustomBottomNavBar(
                            currentIndex: _currentIndex,
                            onTap: _onNavItemTapped,
                            isTracking: isTracking,
                            trackingInfo: infoSnapshot.data,
                            onTrackingTap: () => _onNavItemTapped(2),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
