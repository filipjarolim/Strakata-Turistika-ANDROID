import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'dart:async';

import '../config/app_colors.dart';
import '../config/app_theme.dart';
import '../services/mapy_cz_download_service.dart';
import '../services/vector_tile_provider.dart';
import '../widgets/ui/app_button.dart';
import '../widgets/ui/app_toast.dart';
import '../widgets/ui/web_mobile_section_card.dart';

class OfflineMapsPage extends StatefulWidget {
  const OfflineMapsPage({super.key});

  @override
  State<OfflineMapsPage> createState() => _OfflineMapsPageState();
}

class _OfflineMapsPageState extends State<OfflineMapsPage> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFBF7),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: Text(
          'Offline mapy',
          style: GoogleFonts.libreFranklin(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async => setState(() {}),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              WebMobileSectionCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Správa offline map',
                      style: AppTheme.editorialHeadline(
                        color: AppColors.textPrimary,
                        fontSize: 24,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Při běžném prohlížení mapy se dlaždice automaticky ukládají do cache. Tady vidíte schéma uložených dat.',
                      style: GoogleFonts.libreFranklin(
                        fontSize: 13,
                        color: AppColors.textTertiary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              FutureBuilder<Map<String, dynamic>>(
                future: VectorTileProvider.getDetailedStats(),
                builder: (context, snap) {
                  final stats = snap.data ?? {};
                  final total = stats['totalTiles'] ?? 0;
                  final bytes = stats['totalCompressedBytes'] ?? 0;
                  final mb = (bytes is int) ? (bytes / 1024 / 1024).toStringAsFixed(1) : '0.0';
                  final minZoom = stats['minZoom'];
                  final maxZoom = stats['maxZoom'];
                  return WebMobileSectionCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _metric('Dlaždic', total.toString()),
                            Container(width: 1, height: 42, color: const Color(0xFFE8E4DC)),
                            _metric('Velikost', '$mb MB'),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          minZoom == null ? 'Rozsah zoomu: zatím prázdné' : 'Rozsah zoomu: z$minZoom až z$maxZoom',
                          style: GoogleFonts.libreFranklin(
                            fontSize: 12,
                            color: AppColors.textTertiary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              FutureBuilder<Map<String, dynamic>>(
                future: VectorTileProvider.getDetailedStats(),
                builder: (context, snap) {
                  final stats = snap.data ?? {};
                  final sourceHistogram = (stats['sourceHistogram'] as Map?)?.cast<String, dynamic>() ?? {};
                  final browsing = (sourceHistogram['browsing'] as num?)?.toInt() ?? 0;
                  final download = (sourceHistogram['download'] as num?)?.toInt() ?? 0;
                  final unknown = (sourceHistogram['unknown'] as num?)?.toInt() ?? 0;
                  final bounds = (stats['bounds'] as Map?)?.cast<String, dynamic>() ?? {};
                  final south = (bounds['south'] as num?)?.toDouble();
                  final north = (bounds['north'] as num?)?.toDouble();
                  final west = (bounds['west'] as num?)?.toDouble();
                  final east = (bounds['east'] as num?)?.toDouble();
                  final zoomHistogram = (stats['zoomHistogram'] as Map?)?.cast<dynamic, dynamic>() ?? {};
                  final sortedZooms = zoomHistogram.entries.toList()
                    ..sort((a, b) => int.parse(a.key.toString()).compareTo(int.parse(b.key.toString())));

                  return WebMobileSectionCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Schéma uložených dat',
                          style: GoogleFonts.libreFranklin(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _schemaChip('Brouzdání', browsing, Icons.explore_rounded, const Color(0xFFDCFCE7)),
                            _schemaChip('Stažené balíčky', download, Icons.download_done_rounded, const Color(0xFFE0F2FE)),
                            _schemaChip('Neznámý zdroj', unknown, Icons.help_outline_rounded, const Color(0xFFFFF4E5)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          south == null
                              ? 'Pokrytí oblasti: zatím nejsou uložené žádné dlaždice.'
                              : 'Pokrytí oblasti: ${south.toStringAsFixed(3)} až ${north!.toStringAsFixed(3)} N, ${west!.toStringAsFixed(3)} až ${east!.toStringAsFixed(3)} E',
                          style: GoogleFonts.libreFranklin(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textTertiary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (sortedZooms.isNotEmpty)
                          Column(
                            children: sortedZooms.map((entry) {
                              final z = int.parse(entry.key.toString());
                              final count = (entry.value as num).toInt();
                              final total = (stats['totalTiles'] as num?)?.toInt() ?? 1;
                              final ratio = total == 0 ? 0.0 : (count / total).clamp(0.0, 1.0);
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 44,
                                      child: Text(
                                        'z$z',
                                        style: GoogleFonts.libreFranklin(fontSize: 12, fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: LinearProgressIndicator(
                                          value: ratio,
                                          minHeight: 8,
                                          backgroundColor: const Color(0xFFE8E4DC),
                                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.brand),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      count.toString(),
                                      style: GoogleFonts.libreFranklin(fontSize: 12, fontWeight: FontWeight.w700),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              FutureBuilder<Map<String, dynamic>>(
                future: VectorTileProvider.getDetailedStats(),
                builder: (context, snap) {
                  final stats = snap.data ?? {};
                  final recentTiles = (stats['recentTiles'] as List?)?.cast<Map>() ?? const <Map>[];
                  return WebMobileSectionCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Poslední uložené dlaždice',
                          style: GoogleFonts.libreFranklin(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (recentTiles.isEmpty)
                          Text(
                            'Zatím nic. Otevři mapu a chvíli se po ní pohybuj.',
                            style: GoogleFonts.libreFranklin(
                              fontSize: 13,
                              color: AppColors.textTertiary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ...recentTiles.map((tile) {
                          final z = tile['zoom'] ?? '?';
                          final x = tile['x'] ?? '?';
                          final y = tile['y'] ?? '?';
                          final source = tile['source'] ?? 'unknown';
                          final age = tile['ageMinutes'] ?? 0;
                          final kb = ((tile['compressedSize'] as num?)?.toDouble() ?? 0) / 1024;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8F7F4),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'z$z • x$x • y$y',
                                    style: GoogleFonts.libreFranklin(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                Text(
                                  '$source • ${kb.toStringAsFixed(1)} KB • $age min',
                                  style: GoogleFonts.libreFranklin(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textTertiary,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              StreamBuilder<Map<String, dynamic>>(
                stream: MapyCzDownloadService.progressStream,
                initialData: MapyCzDownloadService.getDownloadStats(),
                builder: (context, snapshot) {
                  final progressData = snapshot.data ?? {};
                  final isDownloading = progressData['isDownloading'] == true;
                  final progress = (progressData['progress'] as num?)?.toDouble() ?? 0.0;
                  final status = progressData['status']?.toString() ?? 'Připraveno';
                  final success = progressData['successfulTiles'] ?? 0;
                  final cached = progressData['cachedTiles'] ?? 0;
                  final failed = progressData['failedTiles'] ?? 0;

                  return WebMobileSectionCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isDownloading ? Icons.downloading_rounded : Icons.cloud_done_outlined,
                              color: isDownloading ? AppColors.brand : AppColors.textSecondary,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                status,
                                style: GoogleFonts.libreFranklin(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                            Text(
                              '${(progress * 100).round()}%',
                              style: GoogleFonts.libreFranklin(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(100),
                          child: LinearProgressIndicator(
                            value: progress.clamp(0.0, 1.0),
                            minHeight: 8,
                            backgroundColor: const Color(0xFFE8E4DC),
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.brand),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Staženo: $success • V cache: $cached • Chyby: $failed',
                          style: GoogleFonts.libreFranklin(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textTertiary,
                          ),
                        ),
                        if (isDownloading) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: AppButton(
                              onPressed: MapyCzDownloadService.stopDownload,
                              icon: Icons.stop_circle_outlined,
                              text: 'Zastavit stahování',
                              type: AppButtonType.destructiveOutline,
                              size: AppButtonSize.medium,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              WebMobileSectionCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rychlé stažení oblastí',
                      style: GoogleFonts.libreFranklin(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: AppButton(
                        onPressed: () async {
                          final sw = const LatLng(48.9, 12.3);
                          final ne = const LatLng(50.6, 16.0);
                          await MapyCzDownloadService.downloadBounds(
                            southwest: sw,
                            northeast: ne,
                            minZoom: 8,
                            maxZoom: 12,
                            concurrency: 24,
                            batchSize: 800,
                          );
                          if (context.mounted) {
                            AppToast.showInfo(context, 'Stahování středu ČR spuštěno');
                          }
                        },
                        icon: Icons.download_rounded,
                        text: 'Střed ČR (z8–12)',
                        type: AppButtonType.outline,
                        size: AppButtonSize.medium,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: AppButton(
                        onPressed: () async {
                          final sw = const LatLng(49.95, 14.15);
                          final ne = const LatLng(50.25, 14.75);
                          await MapyCzDownloadService.downloadBounds(
                            southwest: sw,
                            northeast: ne,
                            minZoom: 10,
                            maxZoom: 15,
                            concurrency: 24,
                            batchSize: 800,
                          );
                          if (context.mounted) {
                            AppToast.showInfo(context, 'Stahování Prahy spuštěno');
                          }
                        },
                        icon: Icons.download_rounded,
                        text: 'Praha (z10–15)',
                        type: AppButtonType.outline,
                        size: AppButtonSize.medium,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: AppButton(
                        onPressed: () async {
                          await MapyCzDownloadService.clearCache();
                          if (context.mounted) {
                            AppToast.showSuccess(context, 'Cache byla vyčištěna');
                          }
                          setState(() {});
                        },
                        icon: Icons.cleaning_services_outlined,
                        text: 'Vyčistit cache',
                        type: AppButtonType.secondary,
                        size: AppButtonSize.medium,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metric(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.libreFranklin(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.libreFranklin(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textTertiary,
          ),
        ),
      ],
    );
  }

  Widget _schemaChip(String label, int count, IconData icon, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textPrimary),
          const SizedBox(width: 6),
          Text(
            '$label: $count',
            style: GoogleFonts.libreFranklin(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
