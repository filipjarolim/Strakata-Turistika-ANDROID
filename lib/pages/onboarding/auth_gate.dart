import 'package:flutter/material.dart';
import '../../main.dart';
import '../../services/auth_service.dart';
import '../../pages/login_page.dart';

/// Wraps the application to enforce authentication.
///
/// Location / background permission is requested later, in context of GPS
/// tracking, after the in-app Prominent Disclosure — never at app launch.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    if (AuthService.isLoggedIn) {
      return const MyHomePage();
    } else {
      return const LoginPage();
    }
  }
}
