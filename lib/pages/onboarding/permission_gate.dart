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

class _PermissionGateState extends State<PermissionGate> {
  Future<bool> _checkPermissions() async {
    final status = await GpsServices.checkPermissionsStatus();
    return status['location']! && status['background']! && status['battery_granted']!;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _checkPermissions(),
      builder: (context, snapshot) {
        // While checking, show a blank loading screen matching the splash
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

        final allGranted = snapshot.data ?? false;

        if (allGranted) {
          return const MyHomePage();
        } else {
          return const PermissionOnboardingPage();
        }
      },
    );
  }
}
