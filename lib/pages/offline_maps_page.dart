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
          'Mapa v terénu',
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
                      'Co tady najdete',
                      style: AppTheme.editorialHeadline(
                        color: AppColors.textPrimary,
                        fontSize: 24,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    _bullet(
                      'Když posouváte mapu v aplikaci, telefon si části mapy schová — v horách nebo bez signálu pak můžete mapu dál prohlížet.',
                    ),
                    const SizedBox(height: 8),
                    _bullet(
                      'Níže vidíte, kolik to zabírá místa a jestli právě něco nestahuje na pozadí.',
                    ),
                    const SizedBox(height: 8),
                    _bullet(
                      'Můžete si před výletem stáhnout větší kus mapy (tlačítka dole) — potřebujete Wi‑Fi nebo mobilní data.',
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
                  final minZoom = stats['minZoom'] as int?;
                  final maxZoom = stats['maxZoom'] as int?;
                  final sourceHistogram =
                      (stats['sourceHistogram'] as Map?)?.cast<String, dynamic>() ?? {};
                  final browsing = (sourceHistogram['browsing'] as num?)?.toInt() ?? 0;
                  final download = (sourceHistogram['download'] as num?)?.toInt() ?? 0;
                  final unknown = (sourceHistogram['unknown'] as num?)?.toInt() ?? 0;
                  final bounds = (stats['bounds'] as Map?)?.cast<String, dynamic>() ?? {};
                  final south = (bounds['south'] as num?)?.toDouble();
                  final north = (bounds['north'] as num?)?.toDouble();
                  final west = (bounds['west'] as num?)?.toDouble();
                  final east = (bounds['east'] as num?)?.toDouble();
                  final zoomHistogram =
                      (stats['zoomHistogram'] as Map?)?.cast<dynamic, dynamic>() ?? {};
                  final sortedZooms = zoomHistogram.entries.toList()
                    ..sort((a, b) => int.parse(a.key.toString()).compareTo(int.parse(b.key.toString())));
                  final recentTiles = (stats['recentTiles'] as List?)?.cast<Map>() ?? const <Map>[];

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      WebMobileSectionCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Na tomto telefonu',
                              style: GoogleFonts.libreFranklin(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Součet uložených částí mapy (OpenStreetMap).',
                              style: GoogleFonts.libreFranklin(
                                fontSize: 13,
                                color: AppColors.textTertiary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _metric('částí mapy', total.toString()),
                                Container(width: 1, height: 42, color: const Color(0xFFE8E4DC)),
                                _metric('místo v telefonu', '$mb MB'),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              minZoom == null
                                  ? 'Zatím nemáte nic uložené — otevřete mapu v aplikaci a projděte oblast, kterou chcete mít k dispozici offline.'
                                  : 'Úroveň přiblížení: od „${_zoomLabel(minZoom)}“ po „${_zoomLabel(maxZoom ?? minZoom)}“.',
                              style: GoogleFonts.libreFranklin(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      WebMobileSectionCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Jak se mapa dostala do telefonu',
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
                                _schemaChip(
                                  'Prohlížení v aplikaci',
                                  browsing,
                                  Icons.explore_rounded,
                                  const Color(0xFFDCFCE7),
                                ),
                                _schemaChip(
                                  'Stažení balíčku',
                                  download,
                                  Icons.download_done_rounded,
                                  const Color(0xFFE0F2FE),
                                ),
                                _schemaChip(
                                  'Ostatní',
                                  unknown,
                                  Icons.layers_outlined,
                                  const Color(0xFFFFF4E5),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              south == null
                                  ? 'Zatím není uložená žádná konkrétní oblast — projděte mapu prstem, nebo použijte stahování níže.'
                                  : 'Orientačně jde o úsek mezi severem a jihem, západem a východem, kde už jste mapu načetli (čím víc mapu posouváte, tím větší „kus“ se schová).',
                              style: GoogleFonts.libreFranklin(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textTertiary,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      WebMobileSectionCard(
                        padding: const EdgeInsets.all(8),
                        child: Theme(
                          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                            title: Row(
                              children: [
                                Icon(Icons.tune_rounded, size: 20, color: AppColors.textSecondary),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Technické detaily',
                                    style: GoogleFonts.libreFranklin(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(left: 30, top: 4),
                              child: Text(
                                'Čísla zoomu, souřadnice a poslední uložené dlaždice — pro ty, kdo to chtějí vidět.',
                                style: GoogleFonts.libreFranklin(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textTertiary,
                                  height: 1.3,
                                ),
                              ),
                            ),
                            children: [
                              if (south != null && north != null && west != null && east != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: SelectableText(
                                    'Souřadnice pokrytí: ${south.toStringAsFixed(4)}–${north.toStringAsFixed(4)} °N, '
                                    '${west.toStringAsFixed(4)}–${east.toStringAsFixed(4)} °E',
                                    style: GoogleFonts.libreFranklin(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textTertiary,
                                    ),
                                  ),
                                ),
                              if (sortedZooms.isNotEmpty) ...[
                                Text(
                                  'Rozložení podle úrovně přiblížení (číslo = „zoom“)',
                                  style: GoogleFonts.libreFranklin(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ...sortedZooms.map((entry) {
                                  final z = int.parse(entry.key.toString());
                                  final count = (entry.value as num).toInt();
                                  final totalTiles = (stats['totalTiles'] as num?)?.toInt() ?? 1;
                                  final ratio =
                                      totalTiles == 0 ? 0.0 : (count / totalTiles).clamp(0.0, 1.0);
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 120,
                                          child: Text(
                                            'úroveň $z',
                                            style: GoogleFonts.libreFranklin(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(8),
                                            child: LinearProgressIndicator(
                                              value: ratio,
                                              minHeight: 8,
                                              backgroundColor: const Color(0xFFE8E4DC),
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(AppColors.brand),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          count.toString(),
                                          style: GoogleFonts.libreFranklin(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                              if (recentTiles.isEmpty)
                                Text(
                                  'Žádné nedávné záznamy dlaždic.',
                                  style: GoogleFonts.libreFranklin(
                                    fontSize: 12,
                                    color: AppColors.textTertiary,
                                  ),
                                )
                              else ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Poslední uložené dlaždice (technický identifikátor):',
                                  style: GoogleFonts.libreFranklin(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                ...recentTiles.map((tile) {
                                  final z = tile['zoom'] ?? '?';
                                  final x = tile['x'] ?? '?';
                                  final y = tile['y'] ?? '?';
                                  final source = tile['source'] ?? '?';
                                  final age = tile['ageMinutes'] ?? 0;
                                  final kb = ((tile['compressedSize'] as num?)?.toDouble() ?? 0) / 1024;
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8F7F4),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'úroveň $z • část $x/$y',
                                          style: GoogleFonts.libreFranklin(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'zdroj: $source • ${kb.toStringAsFixed(1)} kB • před $age min',
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
                            ],
                          ),
                        ),
                      ),
                    ],
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
                  final progress = (progressData['progress'] as num?)?.toDouble() ??
                      (progressData['currentProgress'] as num?)?.toDouble() ??
                      0.0;
                  final statusRaw = (progressData['status'] ?? progressData['currentStatus'])
                          ?.toString() ??
                      '';
                  final status = _friendlyDownloadStatus(statusRaw);
                  final success = progressData['successfulTiles'] ?? 0;
                  final cached = progressData['cachedTiles'] ?? 0;
                  final failed = progressData['failedTiles'] ?? 0;

                  return WebMobileSectionCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Stahování na pozadí',
                          style: GoogleFonts.libreFranklin(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              isDownloading ? Icons.downloading_rounded : Icons.cloud_done_outlined,
                              color: isDownloading ? AppColors.brand : AppColors.textSecondary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                status.isEmpty ? 'Nic se nestahuje.' : status,
                                style: GoogleFonts.libreFranklin(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                  height: 1.3,
                                ),
                              ),
                            ),
                            Text(
                              '${(progress * 100).round()} %',
                              style: GoogleFonts.libreFranklin(
                                fontSize: 14,
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
                          'Nově staženo: $success • už bylo v telefonu: $cached • nepodařilo se: $failed',
                          style: GoogleFonts.libreFranklin(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textTertiary,
                            height: 1.35,
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
                      'Stáhnout mapu dopředu',
                      style: GoogleFonts.libreFranklin(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Vyberte oblast — stáhne se větší balík (střední detail pro celou republiku, nebo podrobněji Praha). '
                      'Doporučujeme Wi‑Fi, může to trvat několik minut.',
                      style: GoogleFonts.libreFranklin(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textTertiary,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 14),
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
                            AppToast.showInfo(context, 'Stahuje se střední přiblížení pro velkou část Česka…');
                          }
                        },
                        icon: Icons.download_rounded,
                        text: 'Velká část Česka (střední detail)',
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
                            AppToast.showInfo(context, 'Stahuje se Praha s podrobnější mapou…');
                          }
                        },
                        icon: Icons.download_rounded,
                        text: 'Praha a okolí (podrobnější)',
                        type: AppButtonType.outline,
                        size: AppButtonSize.medium,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Uvolnit místo',
                      style: GoogleFonts.libreFranklin(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Smaže uloženou mapu z tohoto telefonu. Aplikace si ji znovu doplní z internetu, až ji budete znovu potřebovat.',
                      style: GoogleFonts.libreFranklin(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textTertiary,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: AppButton(
                        onPressed: () async {
                          await MapyCzDownloadService.clearCache();
                          if (context.mounted) {
                            AppToast.showSuccess(context, 'Uložená mapa byla smazána.');
                          }
                          setState(() {});
                        },
                        icon: Icons.cleaning_services_outlined,
                        text: 'Smazat uloženou mapu z telefonu',
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

  Widget _bullet(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '• ',
          style: GoogleFonts.libreFranklin(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppColors.brand,
            height: 1.4,
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.libreFranklin(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ),
      ],
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
          textAlign: TextAlign.center,
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

  /// Srozumitelný popis čísla zoomu (0–18).
  static String _zoomLabel(int z) {
    if (z <= 8) return 'velmi daleko (celý kraj)';
    if (z <= 10) return 'daleko (větší oblast)';
    if (z <= 12) return 'středně (město a okolí)';
    if (z <= 14) return 'blíž (čtvrť, ulice)';
    if (z <= 16) return 'podrobně (domy, cesty)';
    return 'velmi zblízka';
  }

  static String _friendlyDownloadStatus(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return '';
    const pairs = <String, String>{
      'Initializing Mapy.cz-style download...': 'Připravuje se stahování…',
      'Initializing custom area download...': 'Připravuje se stahování vybrané oblasti…',
      'Network unavailable': 'Bez připojení k internetu — stahování nelze spustit.',
      'Download completed!': 'Stahování dokončeno.',
      'Download stopped': 'Stahování bylo zastaveno.',
      'Stopping download...': 'Zastavuje se stahování…',
    };
    if (pairs.containsKey(s)) return pairs[s]!;
    if (s.startsWith('Downloading zoom level')) {
      final m = RegExp(r'zoom level (\d+)').firstMatch(s);
      if (m != null) {
        return 'Stahuje se úroveň přiblížení ${m.group(1)}…';
      }
    }
    if (s.startsWith('Downloading ') && s.contains('layer (zoom')) {
      final m = RegExp(r'zoom (\d+)\)').firstMatch(s);
      if (m != null) return 'Stahuje se úroveň přiblížení ${m.group(1)}…';
    }
    if (s.startsWith('Download failed:')) {
      return 'Stahování se nepovedlo. Zkuste to znovu s lepším signálem.';
    }
    return s;
  }
}
