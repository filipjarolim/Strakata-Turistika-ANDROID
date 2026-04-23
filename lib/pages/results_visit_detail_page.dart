import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_colors.dart';
import '../config/app_theme.dart';
import '../config/strakata_design_tokens.dart';
import '../models/visit_data.dart';
import '../widgets/route_thumbnail.dart';
import '../widgets/strakata_editorial_background.dart';
import '../widgets/ui/app_button.dart';
import '../widgets/ui/web_mobile_section_card.dart';

class ResultsVisitDetailPage extends StatelessWidget {
  const ResultsVisitDetailPage({
    super.key,
    required this.visit,
    required this.seasonYear,
    required this.userName,
  });

  final VisitData visit;
  final int seasonYear;
  final String userName;

  @override
  Widget build(BuildContext context) {
    final hasTrack = visit.route != null && (visit.route!['trackPoints'] as List?)?.isNotEmpty == true;
    final photos = (visit.photos ?? const <Map<String, dynamic>>[])
        .where((p) => p['url'] is String && (p['url'] as String).isNotEmpty)
        .toList();

    return Stack(
      fit: StackFit.expand,
      children: [
        const Positioned.fill(child: StrakataEditorialBackground()),
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            scrolledUnderElevation: 0,
            elevation: 0,
            title: Text(
              'Detail výpravy',
              style: GoogleFonts.libreFranklin(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            foregroundColor: AppColors.textPrimary,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              StrakataLayout.pageHorizontalInset,
              8,
              StrakataLayout.pageHorizontalInset,
              120,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sezóna $seasonYear',
                  style: GoogleFonts.libreFranklin(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textTertiary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  visit.routeTitle?.isNotEmpty == true ? visit.routeTitle! : 'Výlet',
                  style: AppTheme.editorialHeadline(
                    color: AppColors.textPrimary,
                    fontSize: 28,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _badge(Icons.calendar_month_outlined, _formatDate(visit.visitDate)),
                    _badge(Icons.person_outline, userName),
                    if (visit.dogName?.isNotEmpty == true) _badge(Icons.pets_outlined, visit.dogName!),
                  ],
                ),
                const SizedBox(height: 16),
                WebMobileSectionCard(
                  padding: EdgeInsets.zero,
                  child: RouteThumbnail(
                    visit: visit,
                    height: 220,
                    borderRadius: 24,
                  ),
                ),
                const SizedBox(height: 16),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.9,
                  children: [
                    _metricCard('Vzdálenost', _distanceValue(visit)),
                    _metricCard('Čas', _durationValue(visit)),
                    _metricCard('Průměr', _avgSpeedValue(visit)),
                    _metricCard('Body', visit.points.toStringAsFixed(0)),
                  ],
                ),
                const SizedBox(height: 16),
                WebMobileSectionCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Navštívená místa',
                        style: GoogleFonts.libreFranklin(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (visit.places.isNotEmpty)
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: visit.places
                              .map((p) => _placeChip(p.name))
                              .toList(),
                        )
                      else if (visit.visitedPlaces.trim().isNotEmpty)
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: visit.visitedPlaces
                              .split(',')
                              .map((s) => s.trim())
                              .where((s) => s.isNotEmpty)
                              .map(_placeChip)
                              .toList(),
                        )
                      else
                        Text(
                          'Žádná evidovaná místa',
                          style: GoogleFonts.libreFranklin(
                            fontSize: 13,
                            color: AppColors.textTertiary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ),
                if (photos.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  WebMobileSectionCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Fotografie',
                          style: GoogleFonts.libreFranklin(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: photos.length,
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                          itemBuilder: (_, i) => ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              photos[i]['url'] as String,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(color: const Color(0xFFF0EBE3)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if ((visit.routeLink ?? '').startsWith('http')) ...[
                  const SizedBox(height: 16),
                  AppButton(
                    onPressed: () => _openRouteLink(visit.routeLink!),
                    text: 'Otevřít odkaz na trasu',
                    icon: Icons.link_rounded,
                    type: AppButtonType.primary,
                    size: AppButtonSize.large,
                    expand: true,
                  ),
                ],
                if (hasTrack) const SizedBox(height: 4),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _badge(IconData icon, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF0EBE3),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 5),
          Text(
            value,
            style: GoogleFonts.libreFranklin(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricCard(String label, String value) {
    return WebMobileSectionCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: GoogleFonts.libreFranklin(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.libreFranklin(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.brand.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.brand.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: GoogleFonts.libreFranklin(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.brand,
        ),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Datum neznámé';
    return '${date.day}.${date.month}.${date.year}';
  }

  String _distanceValue(VisitData v) {
    final raw = v.extraPoints['distanceKm'] ?? v.extraPoints['distance'];
    if (raw is num) return '${raw.toStringAsFixed(2)} km';
    if (raw is String) {
      final parsed = double.tryParse(raw.replaceAll(',', '.'));
      if (parsed != null) return '${parsed.toStringAsFixed(2)} km';
    }
    return '—';
  }

  String _durationValue(VisitData v) {
    final raw = v.extraPoints['durationMinutes'] ?? v.extraPoints['duration'];
    final minutes = raw is num ? raw.toInt() : int.tryParse(raw?.toString() ?? '');
    if (minutes == null || minutes <= 0) return '—';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h <= 0) return '$m min';
    return m > 0 ? '$h h $m min' : '$h h';
  }

  String _avgSpeedValue(VisitData v) {
    final raw = v.extraPoints['averageSpeedKmh'] ?? v.extraPoints['averageSpeed'];
    if (raw is num) return '${raw.toStringAsFixed(2)} km/h';
    if (raw is String) {
      final parsed = double.tryParse(raw.replaceAll(',', '.'));
      if (parsed != null) return '${parsed.toStringAsFixed(2)} km/h';
    }
    return '—';
  }

  Future<void> _openRouteLink(String link) async {
    final uri = Uri.tryParse(link);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
