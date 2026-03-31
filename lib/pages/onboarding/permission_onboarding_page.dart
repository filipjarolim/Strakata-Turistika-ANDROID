import 'package:flutter/material.dart';
import 'package:strakataturistikaandroidapp/widgets/gps/tracking_onboarding_sheet.dart';
import '../../config/app_colors.dart';
import '../../config/strakata_design_tokens.dart';
/// One-time onboarding page that forces the user to grant permissions
class PermissionOnboardingPage extends StatelessWidget {
  const PermissionOnboardingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    context.strakataTokens?.heroOverlayTop ?? AppColors.heroOverlayTop,
                    AppColors.pageBg,
                    AppColors.surfaceMuted,
                  ],
                ),
              ),
            ),
          ),
          
          // Dark Overlay
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.7),
            ),
          ),
          
          // Re-use the onboarding sheet logic but centered
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                         'Nastavení oprávnění',
                         style: TextStyle(
                           fontSize: 28,
                           fontWeight: FontWeight.bold,
                           color: Colors.white,
                         ),
                       ),
                       const SizedBox(height: 16),
                       Text(
                         'Aby aplikace správně fungovala, potřebujeme nastavit přístup k poloze a baterii.',
                         textAlign: TextAlign.center,
                         style: TextStyle(
                           fontSize: 16,
                           color: Colors.white.withValues(alpha: 0.8),
                         ),
                       ),
                       const SizedBox(height: 32),
                       
                       // Embed the sheet content directly
                       // We can't use TrackingOnboardingSheet directly if it has "Navigator.pop" calls
                       // So we'll wrap it or just rely on it updating permissions.
                       // Actually, TrackingOnboardingSheet expects to be in a BottomSheet and pops itself.
                       // We need to modify it or wrap it.
                       // Since we can't easily modify the sheet to be a page without breaking existing usage, 
                       // we'll just instantiate it here. The sheet is actually designed as a widget.
                       // The issue is `Navigator.pop(context, true)`. 
                       // In this full page context, we want to reload the PermissionGate, not pop.
                       
                       const _EmbeddedOnboarding(),
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
}

class _EmbeddedOnboarding extends StatelessWidget {
  const _EmbeddedOnboarding();

  @override
  Widget build(BuildContext context) {
    // Navigate to Home when done. 
    // We assume PermissionGate is handling the routing, so we just need to trigger a rebuild or push replacement.
    // Actually, calling PermissionGate logic again is best.
    // If we are in PermissionGate context, we can just pushReplacement to home directly?
    // The safest way is to pop until we hit the root or pushReplacement to '/'.
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: TrackingOnboardingSheet(
        showSkipButton: false, // Force them to complete it
        onComplete: () {
          // Restart the app from root to re-trigger PermissionGate check
          Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
        },
      ),
    );
  }
}
