import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'gps_page.dart';
import 'login_page.dart';

class MapTab extends StatelessWidget {
  const MapTab({super.key});

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = AuthService.currentUser != null;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: isLoggedIn ? const GpsPage() : const LoginPage(),
      ),
    );
  }
}
