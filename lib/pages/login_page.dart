import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/haptic_service.dart';
import '../config/app_colors.dart';
import '../animations/app_animations.dart';

import '../widgets/ui/app_toast.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  bool _isLoading = false;
  // bool _isLogin = true; // Unused
  // bool _obscurePassword = true; // Unused
  // bool _obscureConfirmPassword = true;  // Unused
  // bool _rememberMe = false; // Unused
  bool _biometricAvailable = false;
  bool _isBiometricEnabled = false;
  
  // Password strength removed

  
  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _shakeController;
  
  // Animations
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  // Local auth
  final LocalAuthentication _localAuth = LocalAuthentication();
  
  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    // Initialize biometrics and auto-trigger if possible/enabled
    _initializeBiometrics();
  }
  
  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000), 
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _shakeController = AnimationController(
      duration: AppAnimations.durationMedium,
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    
    // Start entrance animations
    _fadeController.forward();
    _slideController.forward();
  }
  
  Future<void> _initializeBiometrics() async {
    try {
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      if (!isDeviceSupported) {
        if (mounted) setState(() => _biometricAvailable = false);
        return;
      }
      
      final isAvailable = await _localAuth.canCheckBiometrics;
      if (mounted) setState(() => _biometricAvailable = isAvailable);
      
      if (isAvailable) {
        final prefs = await SharedPreferences.getInstance();
        final isEnabled = prefs.getBool('biometric_enabled') ?? false;
        
        if (mounted) {
          setState(() => _isBiometricEnabled = isEnabled);
          
          // Auto-trigger if enabled and not currently loading (and page is fresh)
          if (isEnabled && !_isLoading) {
             // Small delay to let UI settle
             Future.delayed(const Duration(milliseconds: 500), () {
               if (mounted) _authenticateWithBiometrics();
             });
          }
        }
      }
    } catch (e) {
      debugPrint('Biometric initialization error: $e');
      if (mounted) setState(() {
        _biometricAvailable = false;
        _isBiometricEnabled = false;
      });
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _shakeController.dispose();
    super.dispose();
  }
  
  Future<void> _toggleBiometric() async {
    if (!_biometricAvailable) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final newValue = !_isBiometricEnabled;
      await prefs.setBool('biometric_enabled', newValue);
      if (mounted) {
        setState(() {
          _isBiometricEnabled = newValue;
        });
      }
      HapticService.lightImpact();
      if (newValue) {
        AppToast.showSuccess(context, 'Biometrické přihlášení povoleno');
      } else {
        AppToast.showInfo(context, 'Biometrické přihlášení zakázáno');
      }
    } catch (e) {
      debugPrint('Error toggling biometric: $e');
    }
  }
  
  Future<void> _authenticateWithBiometrics() async {
    if (!_biometricAvailable || !_isBiometricEnabled) return;
    
    try {
      final isAuthenticated = await _localAuth.authenticate(
        localizedReason: 'Přihlaste se pomocí biometrie',
      );
      
      // If biometric succeeds, we need a way to sign in.
      // But standard biometric usually unlocks credentials.
      // Since we only do Google now, biometrics might just be "Unlock the app session" 
      // IF the session token matches.
      // Ideally Google Sign-In maintains the session.
      // So this biometric might just be "Verify it's me before I click continue".
      // But `_signInWithGoogle` technically requires user interaction or silent sign in.
      
      if (isAuthenticated) {
         // Attempt silent sign-in or just proceed to Google
         _signInWithGoogle();
      }
    } catch (e) {
      // Don't show error if user canceled
      debugPrint('Biometric auth failed: $e');
    }
  }
  
  void _showError(String message) {
    HapticService.heavyImpact();
    _shakeController.forward().then((_) => _shakeController.reverse());
    AppToast.showError(context, message);
  }
  
  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    HapticService.mediumImpact();

    try {
      final result = await AuthService.signInWithGoogle();
      
      if (result.success && result.user != null) {
        if (mounted) {
          // Navigate to home quietly to avoid SnackBar animation crash on dispose
          Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
        }
      } else {
        if (mounted) {
          _showError(result.error ?? 'Google přihlášení selhalo');
        }
      }
    } catch (e) {
      if (mounted) {
        _showError('Chyba: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // 1. Brand gradient shell (assets optional)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.pageBg,
                    AppColors.brandMuted,
                    AppColors.brand.withValues(alpha: 0.35),
                  ],
                ),
              ),
            ),
          ),
          
          // 2. Dark Gradient Overlay (stronger for better text legibility)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.30),
                    Colors.black.withValues(alpha: 0.50),
                    Colors.black.withValues(alpha: 0.70),
                    Colors.black.withValues(alpha: 0.90), 
                  ],
                ),
              ),
            ),
          ),
          
          // 3. Content
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end, // Push content to bottom/center
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Spacer(), 
                      
                      // Logo or Title
                      // Assuming an app logo exists, if not using text
                      Container(
                         padding: const EdgeInsets.all(16),
                         decoration: BoxDecoration(
                           color: Colors.white.withValues(alpha: 0.1),
                           shape: BoxShape.circle,
                           border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                         ),
                         child: const Icon(Icons.pets, size: 60, color: Colors.white), 
                      ),
                      
                      const SizedBox(height: 32),
                      
                      const Text(
                        'Strakatá Turistika',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -1.0,
                          height: 1.1,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Objevujte nová místa se svým psem a zaznamenávejte společná dobrodružství.',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withValues(alpha: 0.8),
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      
                      const Spacer(),
                      
                      // Social Login Only
                      ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                            ),
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildGlassSocialButton(
                                  text: 'Pokračovat s Google',
                                  onPressed: _signInWithGoogle,
                                ),
                                
                                // Biometric button if available
                                if (_biometricAvailable) ...[
                                  const SizedBox(height: 16),
                                  _buildGlassBiometricButton(),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 48),
                      
                      // Terms and Conditions text
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Text(
                          'Pokračováním souhlasíte s našimi Podmínkami použití a Zásadami ochrany osobních údajů.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Glass Widgets ---

  // --- Glass Widgets ---

  
  Widget _buildGlassSocialButton({
    required String text,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        onPressed: () {
          HapticService.lightImpact();
          onPressed();
        },
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white, // Solid white background
          foregroundColor: Colors.black87, // Dark text
          side: BorderSide.none, // No border needed for pill
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 2,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.g_mobiledata, size: 28, color: Color(0xFF4285F4)),
            const SizedBox(width: 12),
            Text(
              text,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.2,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildGlassBiometricButton() {
    return Center(
      child: GestureDetector(
        onTap: _toggleBiometric,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: _isBiometricEnabled 
              ? AppColors.primary.withValues(alpha: 0.2) 
              : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _isBiometricEnabled ? AppColors.primary : Colors.white.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.fingerprint, 
                size: 18, 
                color: _isBiometricEnabled ? AppColors.primary : Colors.white.withValues(alpha: 0.6)
              ),
              const SizedBox(width: 8),
              Text(
                'Biometrické přihlášení ${_isBiometricEnabled ? "Zapnuto" : "Vypnuto"}',
                style: TextStyle(
                  fontSize: 12,
                  color: _isBiometricEnabled ? AppColors.primary : Colors.white.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}