import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_colors.dart';
import '../config/app_theme.dart';
import '../config/strakata_design_tokens.dart';
import '../models/tracking_summary.dart';
import '../models/visit_data.dart';
import 'dynamic_form_page.dart';
import '../repositories/visit_repository.dart';
import '../widgets/photo_viewer.dart';
import '../widgets/route_thumbnail.dart';
import '../widgets/strakata_editorial_background.dart';
import '../widgets/ui/app_button.dart';
import '../widgets/ui/app_toast.dart';
import '../widgets/ui/web_mobile_section_card.dart';

class ResultsVisitDetailPage extends StatefulWidget {
  const ResultsVisitDetailPage({
    super.key,
    required this.visit,
    required this.seasonYear,
    required this.userName,
    this.allowDraftActions = false,
  });

  final VisitData visit;
  final int seasonYear;
  final String userName;
  final bool allowDraftActions;

  @override
  State<ResultsVisitDetailPage> createState() => _ResultsVisitDetailPageState();
}

class _ResultsVisitDetailPageState extends State<ResultsVisitDetailPage> {
  final VisitRepository _repository = VisitRepository();
  late VisitData _visit;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _visit = widget.visit;
    _loadFullVisit();
  }

  Future<void> _loadFullVisit() async {
    final id = widget.visit.id;
    if (id.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    try {
      final full = await _repository.getVisitById(id);
      if (!mounted) return;
      setState(() {
        if (full != null) _visit = full;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Visit detail fetch failed: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visit = _visit;
    final hasTrack =
        visit.route != null && (visit.route!['trackPoints'] as List?)?.isNotEmpty == true;
    final photos = _displayPhotoUrls(visit);
    final themeKeywords = _themeKeywords(visit);
    final extraNotes = _extraNotes(visit);

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
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
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
                        'Sezóna ${widget.seasonYear}',
                        style: GoogleFonts.libreFranklin(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textTertiary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        visit.routeTitle?.isNotEmpty == true
                            ? visit.routeTitle!
                            : (visit.visitedPlaces.trim().isNotEmpty
                                ? visit.visitedPlaces
                                : 'Výlet'),
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
                          _badge(Icons.person_outline, widget.userName),
                          if (visit.dogName?.isNotEmpty == true)
                            _badge(Icons.pets_outlined, visit.dogName!),
                          _badge(Icons.flag_outlined, _statusText(visit.state)),
                        ],
                      ),
                      if (visit.state == VisitState.REJECTED) ...[
                        const SizedBox(height: 12),
                        WebMobileSectionCard(
                          padding: const EdgeInsets.all(14),
                          child: Text(
                            visit.rejectionReason?.trim().isNotEmpty == true
                                ? 'Důvod zamítnutí: ${visit.rejectionReason}'
                                : 'Výprava byla zamítnuta. Administrátor neuvedl konkrétní důvod — '
                                    'v případě nejasností kontaktujte pořadatele.',
                            style: GoogleFonts.libreFranklin(
                              fontSize: 13,
                              color: const Color(0xFFB91C1C),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
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
                      if ((visit.routeDescription ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 16),
                        WebMobileSectionCard(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Popis',
                                style: GoogleFonts.libreFranklin(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                visit.routeDescription!.trim(),
                                style: GoogleFonts.libreFranklin(
                                  fontSize: 14,
                                  height: 1.4,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (themeKeywords.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        WebMobileSectionCard(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Měsíční téma',
                                style: GoogleFonts.libreFranklin(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: themeKeywords.map(_placeChip).toList(),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (extraNotes.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        WebMobileSectionCard(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: extraNotes
                                .map(
                                  (row) => Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        SizedBox(
                                          width: 120,
                                          child: Text(
                                            row.$1,
                                            style: GoogleFonts.libreFranklin(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.textTertiary,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            row.$2,
                                            style: GoogleFonts.libreFranklin(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ],
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
                              ...visit.places.map(_placeCard)
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
                              PhotoGrid(urls: photos),
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
                      if (widget.allowDraftActions && visit.state == VisitState.DRAFT) ...[
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: AppButton(
                                onPressed: _deleteDraft,
                                text: 'Smazat',
                                type: AppButtonType.destructiveOutline,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: AppButton(
                                onPressed: _continueDraft,
                                text: 'Pokračovat',
                                type: AppButtonType.primary,
                              ),
                            ),
                          ],
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

  Widget _placeCard(Place place) {
    final photoUrls = _placePhotoUrls(place);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F4EE),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE8E4DC)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              place.name.isEmpty ? 'Bez názvu' : place.name,
              style: GoogleFonts.libreFranklin(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            if (place.type.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  place.type,
                  style: GoogleFonts.libreFranklin(
                    fontSize: 12,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
            if (place.description.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  place.description.trim(),
                  style: GoogleFonts.libreFranklin(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            if (photoUrls.isNotEmpty) ...[
              const SizedBox(height: 8),
              PhotoGrid(urls: photoUrls, crossAxisCount: photoUrls.length == 1 ? 1 : 2),
            ],
          ],
        ),
      ),
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

  String _statusText(VisitState state) {
    switch (state) {
      case VisitState.APPROVED:
        return 'Schváleno';
      case VisitState.PENDING_REVIEW:
        return 'Ke schválení';
      case VisitState.REJECTED:
        return 'Zamítnuto';
      case VisitState.DRAFT:
        return 'Rozpracováno';
    }
  }

  String _distanceValue(VisitData v) {
    final km = v.resolvedDistanceKm;
    if (km == null) return '—';
    return '${km.toStringAsFixed(2)} km';
  }

  String _durationValue(VisitData v) {
    final minutes = v.resolvedDurationMinutes;
    if (minutes == null || minutes <= 0) return '—';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h <= 0) return '$m min';
    return m > 0 ? '$h h $m min' : '$h h';
  }

  String _avgSpeedValue(VisitData v) {
    final speed = v.resolvedAverageSpeedKmh;
    if (speed == null) return '—';
    return '${speed.toStringAsFixed(1)} km/h';
  }

  List<String> _themeKeywords(VisitData visit) {
    final extra = visit.extraData ?? {};
    final raw = extra['themeKeywordsSelected'] ??
        extra['monthlyThemeKeywords'] ??
        extra['themeKeywords'] ??
        visit.extraPoints['themeKeywordsSelected'];
    if (raw is List) {
      return raw.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toList();
    }
    if (raw is String && raw.trim().isNotEmpty) {
      return raw.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    }
    return const [];
  }

  List<(String, String)> _extraNotes(VisitData visit) {
    final extra = visit.extraData ?? {};
    final skip = {
      'distance',
      'distanceKm',
      'duration',
      'durationMinutes',
      'averageSpeed',
      'averageSpeedKmh',
      'source',
      'themeKeywordsSelected',
      'monthlyThemeKeywords',
      'themeKeywords',
      'trackPoints',
      'routeTitle',
      'routeDescription',
      'dogName',
      'visitedPlaces',
      'photos',
      'places',
    };
    final rows = <(String, String)>[];
    void add(String label, dynamic value) {
      if (value == null) return;
      if (value is List || value is Map) return;
      final text = value.toString().trim();
      if (text.isEmpty) return;
      rows.add((label, text));
    }

    add('Pes', visit.dogName);
    extra.forEach((key, value) {
      if (skip.contains(key)) return;
      if (key.startsWith('_')) return;
      add(key, value);
    });
    return rows;
  }

  Future<void> _openRouteLink(String link) async {
    final uri = Uri.tryParse(link);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _deleteDraft() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Smazat?'),
        content: const Text('Opravdu smazat tento návrh?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Zrušit')),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Smazat', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    await _repository.deleteVisit(_visit.id);
    if (!mounted) return;
    AppToast.showInfo(context, 'Návrh byl smazán.');
    Navigator.pop(context, true);
  }

  void _continueDraft() {
    final visit = _visit;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => DynamicFormPage(
          slug: visit.formSlug,
          existingVisit: visit,
          trackingSummary: visit.route == null
              ? null
              : TrackingSummary.fromPersistedRoute(visit.route!),
        ),
      ),
    );
  }

  List<String> _displayPhotoUrls(VisitData visit) {
    final urls = <String>[];
    void add(String? raw) {
      final resolved = _resolvablePhotoUrl(raw);
      if (resolved != null && !urls.contains(resolved)) urls.add(resolved);
    }

    for (final photo in visit.photos ?? const <Map<String, dynamic>>[]) {
      add(visitPhotoUrl(photo));
    }
    for (final place in visit.places) {
      for (final photo in place.photos) {
        add(photo.url);
      }
    }
    return urls;
  }

  List<String> _placePhotoUrls(Place place) {
    final urls = <String>[];
    for (final photo in place.photos) {
      final resolved = _resolvablePhotoUrl(photo.url);
      if (resolved != null && !urls.contains(resolved)) urls.add(resolved);
    }
    return urls;
  }

  String? _resolvablePhotoUrl(String? raw) {
    var url = raw?.trim() ?? '';
    if (url.isEmpty) return null;
    if (url.startsWith('file://')) {
      url = Uri.parse(url).toFilePath();
    }
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    if (File(url).existsSync()) return url;
    return null;
  }
}
