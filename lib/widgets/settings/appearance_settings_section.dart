import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_colors.dart';
import '../../config/season_theme.dart';
import '../../services/appearance_preferences_service.dart';
import '../ui/app_toast.dart';
import '../ui/strakata_motion.dart';
import '../ui/web_mobile_section_card.dart';

/// Settings block: seasonal light themes + launcher icon.
class AppearanceSettingsSection extends StatelessWidget {
  const AppearanceSettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final appearance = AppearancePreferencesService.instance;
    return ListenableBuilder(
      listenable: appearance,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Vzhled',
              style: GoogleFonts.libreFranklin(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 12),
            WebMobileSectionCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.palette_outlined, color: AppColors.brand, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Roční období',
                          style: GoogleFonts.libreFranklin(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Jen světlý režim — barvy se přizpůsobí sezóně.',
                    style: GoogleFonts.libreFranklin(
                      fontSize: 13,
                      color: AppColors.textTertiary,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Material(
                    color: Colors.transparent,
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Podle kalendáře',
                                style: GoogleFonts.libreFranklin(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Aktuálně: ${AppSeason.calendarDefault().labelCs}',
                                style: GoogleFonts.libreFranklin(
                                  fontSize: 12,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch.adaptive(
                          value: appearance.followCalendar,
                          activeColor: AppColors.brand,
                          onChanged: (v) => appearance.setFollowCalendar(v),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: AppSeason.values.map((season) {
                      return SeasonChip(
                        season: season,
                        selected: appearance.season == season,
                        onTap: () => appearance.setSeason(season),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Icon(Icons.apps_rounded, color: AppColors.brand, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Ikona aplikace',
                          style: GoogleFonts.libreFranklin(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Změní ikonu na ploše (může vyžadovat chvíli na Androidu).',
                    style: GoogleFonts.libreFranklin(
                      fontSize: 13,
                      color: AppColors.textTertiary,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: AppIconVariant.values.map((variant) {
                      final selected = appearance.iconVariant == variant;
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: variant == AppIconVariant.classic ? 8 : 0,
                            left: variant == AppIconVariant.autumn ? 8 : 0,
                          ),
                          child: PressableScale(
                            onTap: () async {
                              final err =
                                  await appearance.setIconVariant(variant);
                              if (!context.mounted) return;
                              if (err != null) {
                                AppToast.showError(context, err);
                              } else {
                                AppToast.showSuccess(
                                  context,
                                  'Ikona: ${variant.labelCs}. Na ploše se projeví za chvíli.',
                                );
                              }
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: selected
                                    ? AppColors.brand.withValues(alpha: 0.1)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: selected
                                      ? AppColors.brand
                                      : AppColors.border,
                                  width: selected ? 2 : 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: Image.asset(
                                      variant.previewAsset,
                                      width: 64,
                                      height: 64,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        width: 64,
                                        height: 64,
                                        color: AppColors.brandMuted,
                                        child: Icon(
                                          Icons.pets_rounded,
                                          color: AppColors.brand,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    variant.labelCs,
                                    style: GoogleFonts.libreFranklin(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
