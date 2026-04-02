import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:strakataturistikaandroidapp/widgets/gps/tracking_onboarding_sheet.dart';
import '../../config/app_colors.dart';
import '../../config/app_theme.dart';
import '../../widgets/strakata_editorial_background.dart';
/// One-time onboarding page that forces the user to grant permissions
class PermissionOnboardingPage extends StatelessWidget {
  const PermissionOnboardingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const Positioned.fill(child: StrakataEditorialBackground()),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Nastavení oprávnění',
                        textAlign: TextAlign.center,
                        style: AppTheme.editorialHeadline(
                          color: AppColors.textPrimary,
                          fontSize: 28,
                        ).copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Aby aplikace správně fungovala, potřebujeme nastavit přístup k poloze a baterii.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.libreFranklin(
                          fontSize: 16,
                          color: AppColors.textTertiary,
                          height: 1.45,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 28),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: const Color(0xFFE8E4DC)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: const _EmbeddedOnboarding(),
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
