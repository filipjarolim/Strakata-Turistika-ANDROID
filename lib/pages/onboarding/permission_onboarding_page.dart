import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:strakataturistikaandroidapp/widgets/gps/tracking_onboarding_sheet.dart';
import '../../config/app_colors.dart';
import '../../config/app_theme.dart';
import '../../widgets/strakata_editorial_background.dart';
/// Onboarding page for location/battery permissions before first use.
class PermissionOnboardingPage extends StatelessWidget {
  final VoidCallback? onPermissionsChanged;

  const PermissionOnboardingPage({super.key, this.onPermissionsChanged});

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
                        child: _EmbeddedOnboarding(
                          onPermissionsChanged: onPermissionsChanged,
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
}

class _EmbeddedOnboarding extends StatelessWidget {
  final VoidCallback? onPermissionsChanged;

  const _EmbeddedOnboarding({this.onPermissionsChanged});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: TrackingOnboardingSheet(
        requireAllForComplete: false,
        showSkipButton: false,
        onComplete: onPermissionsChanged,
      ),
    );
  }
}
