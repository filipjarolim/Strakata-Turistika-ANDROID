import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_colors.dart';
import '../../config/app_theme.dart';
import '../../config/legal_config.dart';
import '../../pages/webview_page.dart';
import '../../services/app_update_service.dart';
import '../ui/app_toast.dart';
import '../ui/strakata_primitives.dart';

/// Shared navigation for store-required legal pages, licenses, and support.
class LegalActions {
  LegalActions._();

  static void openPrivacyPolicy(BuildContext context) {
    _openInApp(context, title: 'Zásady ochrany osobních údajů', url: LegalConfig.privacyUrl);
  }

  static void openTermsOfService(BuildContext context) {
    _openInApp(context, title: 'Podmínky použití', url: LegalConfig.termsUrl);
  }

  static void openCompetitionRules(BuildContext context) {
    _openInApp(context, title: 'Pravidla soutěže', url: LegalConfig.rulesUrl);
  }

  static Future<void> openLicenses(BuildContext context) async {
    final version = await AppUpdateService.getAppVersionString();
    if (!context.mounted) return;
    showLicensePage(
      context: context,
      applicationName: LegalConfig.appName,
      applicationVersion: version,
      applicationLegalese: LegalConfig.legalese,
    );
  }

  static Future<void> contactSupport(BuildContext context) async {
    final uri = LegalConfig.supportMailtoUri;
    final ok = await launchUrl(uri);
    if (!ok && context.mounted) {
      AppToast.showError(
        context,
        'E-mail se nepodařilo otevřít. Napište na ${LegalConfig.supportEmail}',
      );
    }
  }

  static Future<void> showAbout(BuildContext context) async {
    final version = await AppUpdateService.getAppVersionString();
    final lastUpdate = await AppUpdateService.getLastUpdateDateString();
    if (!context.mounted) return;

    await showStrakataModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            24 + MediaQuery.of(ctx).padding.bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(child: StrakataSheetHandle()),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppColors.brand.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(Icons.hiking_rounded, color: AppColors.brand, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            LegalConfig.appName,
                            style: AppTheme.editorialHeadline(
                              color: AppColors.textPrimary,
                              fontSize: 20,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Verze $version',
                            style: GoogleFonts.libreFranklin(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  LegalConfig.shortDescription,
                  style: GoogleFonts.libreFranklin(
                    fontSize: 14,
                    height: 1.45,
                    color: AppColors.textTertiary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Aktualizováno: $lastUpdate',
                  style: GoogleFonts.libreFranklin(
                    fontSize: 13,
                    color: AppColors.textTertiary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Aplikace zpracovává účet, polohu GPS, fotografie a údaje o návštěvách. '
                  'Podrobnosti, včetně práv k údajům, najdete v zásadách ochrany osobních údajů.',
                  style: GoogleFonts.libreFranklin(
                    fontSize: 13,
                    height: 1.45,
                    color: AppColors.textTertiary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 20),
                _AboutLink(
                  icon: Icons.privacy_tip_outlined,
                  label: 'Zásady ochrany osobních údajů',
                  onTap: () {
                    Navigator.pop(ctx);
                    openPrivacyPolicy(context);
                  },
                ),
                _AboutLink(
                  icon: Icons.gavel_outlined,
                  label: 'Podmínky použití',
                  onTap: () {
                    Navigator.pop(ctx);
                    openTermsOfService(context);
                  },
                ),
                _AboutLink(
                  icon: Icons.description_outlined,
                  label: 'Pravidla soutěže',
                  onTap: () {
                    Navigator.pop(ctx);
                    openCompetitionRules(context);
                  },
                ),
                _AboutLink(
                  icon: Icons.article_outlined,
                  label: 'Open source licence',
                  onTap: () {
                    Navigator.pop(ctx);
                    openLicenses(context);
                  },
                ),
                _AboutLink(
                  icon: Icons.mail_outline_rounded,
                  label: LegalConfig.supportEmail,
                  onTap: () {
                    Navigator.pop(ctx);
                    contactSupport(context);
                  },
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    LegalConfig.legalese,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.libreFranklin(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textTertiary.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static void _openInApp(
    BuildContext context, {
    required String title,
    required String url,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WebViewPage(title: title, url: url),
      ),
    );
  }
}

class _AboutLink extends StatelessWidget {
  const _AboutLink({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: const Color(0xFFF4F0E8),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(icon, size: 20, color: AppColors.textSecondary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.libreFranklin(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textTertiary.withValues(alpha: 0.6),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
