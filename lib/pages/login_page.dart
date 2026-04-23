import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/public_web_url.dart';
import '../services/auth_service.dart';
import '../services/haptic_service.dart';
import '../widgets/ui/app_toast.dart';

/// Stejná struktura a copy jako `/auth/login` na webu (`LoginForm` + `CardWrapper` + `auth/layout`).
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  late final AnimationController _entrance;
  late final Animation<double> _fade;
  late final TapGestureRecognizer _registerTap;

  static const Color _bg = Color(0xFFFAFAF6);
  static const Color _cardBg = Color(0xFFFAFAF6);
  static const Color _peach0 = Color(0xFFF9DBC4);
  static const Color _peach1 = Color(0xFFDB7B2E);
  static const Color _iconTile0 = Color(0xFFF9DBC4);
  static const Color _iconTile1 = Color(0xFFE8C4A8);
  static const Color _emerald700 = Color(0xFF047857);

  @override
  void initState() {
    super.initState();
    _registerTap = TapGestureRecognizer()..onTap = _openRegisterOnWeb;
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _fade = CurvedAnimation(parent: _entrance, curve: Curves.easeOutCubic);
    _entrance.forward();
  }

  @override
  void dispose() {
    _registerTap.dispose();
    _entrance.dispose();
    super.dispose();
  }

  Future<void> _openRegisterOnWeb() async {
    final uri = Uri.parse('${publicWebBaseUrl()}/auth/register');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      AppToast.showError(context, 'Odkaz se nepodařilo otevřít.');
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    HapticService.mediumImpact();
    try {
      final result = await AuthService.signInWithGoogle();
      if (result.success && result.user != null) {
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
        }
      } else {
        if (mounted) {
          AppToast.showError(context, result.error ?? 'Google přihlášení selhalo');
        }
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(context, 'Chyba: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signOut() async {
    HapticService.lightImpact();
    await AuthService.signOut();
    if (!mounted) return;
    AppToast.showInfo(context, 'Byli jste odhlášeni.');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final year = DateTime.now().year;
    final maxCard = 576.0;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: FadeTransition(
                opacity: _fade,
                child: Align(
                  alignment: Alignment.center,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxCard),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildCard(),
                          const SizedBox(height: 32),
                          _buildRegisterRow(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Text(
                'Strakatá Turistika © $year',
                textAlign: TextAlign.center,
                style: GoogleFonts.libreFranklin(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2.4,
                  height: 1.2,
                  color: Colors.black.withValues(alpha: 0.4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard() {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.09),
            blurRadius: 56,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 10,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_peach0, _peach1],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 8),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
                      gradient: const LinearGradient(
                        colors: [_iconTile0, _iconTile1],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.login_rounded,
                      size: 36,
                      color: Colors.black.withValues(alpha: 0.9),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Přihlášení',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.libreFranklin(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                    letterSpacing: -0.5,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Používáme jen Google — bez hesla a bez ověřovacích e-mailů.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.libreFranklin(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    height: 1.55,
                    color: Colors.black.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                _buildGoogleButton(),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _isLoading ? null : _signOut,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.black.withValues(alpha: 0.55),
                    textStyle: GoogleFonts.libreFranklin(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: const Text('Odhlásit se'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoogleButton() {
    return SizedBox(
      height: 56,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _isLoading ? null : _signInWithGoogle,
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Opacity(
              opacity: _isLoading ? 0.45 : 1,
              child: Text(
                'Pokračovat s Google',
                style: GoogleFonts.libreFranklin(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRegisterRow() {
    return Text.rich(
      textAlign: TextAlign.center,
      TextSpan(
        style: GoogleFonts.libreFranklin(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: const Color(0xFF3F3F46),
        ),
        children: [
          const TextSpan(text: 'Nemáte ještě účet? '),
          TextSpan(
            text: 'Založit přes Google',
            style: GoogleFonts.libreFranklin(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _emerald700,
              decoration: TextDecoration.underline,
              decorationColor: _emerald700,
            ),
            recognizer: _registerTap,
          ),
        ],
      ),
    );
  }
}
