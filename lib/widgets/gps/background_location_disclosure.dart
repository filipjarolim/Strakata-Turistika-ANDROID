import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/app_colors.dart';
import '../../config/app_theme.dart';
import '../legal/legal_actions.dart';
import '../ui/app_button.dart';

/// Google Play Prominent Disclosure for `ACCESS_BACKGROUND_LOCATION`.
///
/// Must be shown in-app immediately before the system permission dialog,
/// with an explicit accept / decline choice (not a single OK button).
class BackgroundLocationDisclosure {
  BackgroundLocationDisclosure._();

  static const String title = 'Sledování trasy na pozadí';

  static const String body =
      'Aplikace Strakatá Turistika shromažďuje údaje o poloze na pozadí, '
      'aby umožnila záznam vaší turistické trasy a měření ujeté vzdálenosti, '
      'i když je aplikace zavřená nebo ji zrovna nepoužíváte '
      '(even when the app is closed or not in use).\n\n'
      'Tato data slouží výhradně k záznamu trasy a nejsou sdílena '
      's třetími stranami za účelem reklamy.';

  /// Returns `true` only when the user taps Souhlasím.
  static Future<bool> show(BuildContext context) async {
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) {
              Navigator.of(dialogContext).pop(false);
            }
          },
          child: Dialog(
            backgroundColor: const Color(0xFFFFFBF7),
            insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
              side: const BorderSide(color: Color(0xFFE8E4DC)),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
              child: SingleChildScrollView(
                child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.brand.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.route_rounded,
                      color: AppColors.brand,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: AppTheme.editorialHeadline(
                      color: AppColors.textPrimary,
                      fontSize: 22,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    body,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.libreFranklin(
                      fontSize: 15,
                      height: 1.45,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => LegalActions.openPrivacyPolicy(dialogContext),
                    child: Text(
                      'Zásady ochrany osobních údajů',
                      style: GoogleFonts.libreFranklin(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brand,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  AppButton(
                    text: 'Souhlasím',
                    type: AppButtonType.primary,
                    size: AppButtonSize.large,
                    expand: true,
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                  ),
                  const SizedBox(height: 10),
                  AppButton(
                    text: 'Ne teď',
                    type: AppButtonType.outline,
                    size: AppButtonSize.large,
                    expand: true,
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                  ),
                ],
                ),
              ),
            ),
          ),
        );
      },
    );
    return accepted == true;
  }
}
