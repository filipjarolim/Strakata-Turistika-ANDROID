import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../main.dart'; // For MyHomePage
import '../../services/gps_services.dart';
import '../../widgets/strakata_editorial_background.dart';
import 'permission_onboarding_page.dart';

/// Wraps the main app to enforce permissions.
class PermissionGate extends StatefulWidget {
  const PermissionGate({super.key});

  @override
  State<PermissionGate> createState() => _PermissionGateState();
}

class _PermissionGateState extends State<PermissionGate>
    with WidgetsBindingObserver {
  Future<bool>? _permissionsFuture;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshPermissions();
    }
  }

  void _refreshPermissions() {
    setState(() {
      _permissionsFuture = _checkPermissions();
    });
  }

  /// Foreground location is enough to use the app; background + battery are
  /// requested again when the user starts GPS tracking.
  Future<bool> _checkPermissions() async {
    final status = await GpsServices.checkPermissionsStatus();
    return status['location'] ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _permissionsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            backgroundColor: Colors.transparent,
            body: Stack(
              fit: StackFit.expand,
              children: [
                const Positioned.fill(child: StrakataEditorialBackground()),
                Center(child: CircularProgressIndicator(color: AppColors.brand)),
              ],
            ),
          );
        }

        final canEnterApp = snapshot.data ?? false;

        if (canEnterApp) {
          return const MyHomePage();
        }

        return PermissionOnboardingPage(onPermissionsChanged: _refreshPermissions);
      },
    );
  }
}
