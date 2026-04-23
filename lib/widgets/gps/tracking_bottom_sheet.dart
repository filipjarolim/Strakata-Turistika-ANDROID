import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../models/tracking_summary.dart';
import '../ui/app_button.dart';
import '../ui/strakata_primitives.dart';
import '../../pages/dynamic_form_page.dart';

class TrackingBottomSheet extends StatelessWidget {
  final ScrollController scrollController;
  final TrackingSummary? summary;
  final bool isTracking;
  final bool isPaused;
  final VoidCallback onToggleTracking;
  final VoidCallback onPauseTracking;
  final VoidCallback onStopTracking;
  final VoidCallback onCenterMap;
  final double sheetPosition; // 0.0 to 1.0 approx, to drive animations
  final VoidCallback? onClose;
  final double? currentSpeed;
  final double? currentAltitude;
  final VoidCallback? onSimulateRoute;
  final VoidCallback? onOfflineMaps;

  const TrackingBottomSheet({
    super.key,
    required this.scrollController,
    this.summary,
    this.currentSpeed,
    this.currentAltitude,
    required this.isTracking,
    this.isPaused = false,
    required this.onToggleTracking,
    required this.onPauseTracking,
    required this.onStopTracking,
    required this.onCenterMap,
    this.sheetPosition = 0.0,
    this.onClose,
    this.onSimulateRoute,
    this.onOfflineMaps,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate opacities/sizes based on sheetPosition
    // If sheetPosition is low (collapsed ~0.15), show collapsed view
    // If high (>0.3), show expanded view

    // Simplification for initial implementation:
    // consistently use the scroll view, but list elements change visibility/opacity

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Content
          ListView(
            controller: scrollController,
            padding: EdgeInsets.zero,
            physics:
                const ClampingScrollPhysics(), // Prevent overscroll bounce at top
            children: [
              // Grip handle area
              // Grip handle area or Close button
              _buildDragHandleOrCloseButton(),

              const SizedBox(height: 4),

              // Collapsed Header View (Always visible/pinned logic handled by layout or just first item)
              _buildCompactHeader(context),

              // Expanded Content (Stats Grid, Tools, Manual Entry)
              // We use sheetPosition to animate opacity
              // 0.18 -> 0.5 expand creates space for this content
              const SizedBox(
                height: 32,
              ), // Increased padding to prevent header cut-off by drag handle

              AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: (sheetPosition > 0.25) ? 1.0 : 0.0,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Statistiky',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildStatsGrid(),

                      const SizedBox(height: 32),

                      // Manual Entry Button - Only visible when fully expanded (approx > 0.9)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: (sheetPosition > 0.9) ? 60 : 0,
                        margin: EdgeInsets.only(
                          bottom: (sheetPosition > 0.9) ? 32 : 0,
                        ),
                        child: SingleChildScrollView(
                          physics: const NeverScrollableScrollPhysics(),
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 300),
                            opacity: (sheetPosition > 0.9) ? 1.0 : 0.0,
                            child: SizedBox(
                              height: 60,
                              width: double.infinity,
                              child: AppButton(
                                text: 'Zadat aktivitu ručně',
                                icon: Icons.edit_note,
                                type: AppButtonType.secondary,
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => DynamicFormPage(
                                        slug: 'gps-tracking',
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ),

                      const Text(
                        'Nástroje mapy',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildMapTools(context),

                      const SizedBox(height: 100), // Bottom padding for scroll
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Floating Action Button (Start/Stop) - Custom positioned or part of header
          // The user wants "dynamic" feel.
          // We can place the main button in the header for collapsed state,
          // and morph it or keep it there.
        ],
      ),
    );
  }

  Widget _buildCompactHeader(BuildContext context) {
    // Dynamic transition between "Start Tracking" big button and "Active Tracking" pill
    return AnimatedCrossFade(
      duration: const Duration(milliseconds: 400),
      crossFadeState: isTracking
          ? CrossFadeState.showSecond
          : CrossFadeState.showFirst,
      // First Child: Big "Start Tracking" Button
      firstChild: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            key: const ValueKey('start_button'),
            onPressed: onToggleTracking,
            icon: const Icon(Icons.play_arrow_rounded, size: 28),
            label: const Text(
              'Spustit sledování',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ),
      // Second Child: Active Tracking Pill with Stats + Small Action Button
      secondChild: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Row(
          key: const ValueKey('active_pill'),
          children: [
            // Main Stat (Time or Distance)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isPaused ? 'Pozastaveno' : 'Probíhá záznam',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isPaused
                          ? Colors.orange.shade800
                          : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        _formatDuration(summary?.duration ?? Duration.zero),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(height: 24, width: 1, color: Colors.grey[300]),
                      const SizedBox(width: 12),
                      Text(
                        '${((summary?.totalDistance ?? 0) / 1000).toStringAsFixed(2)} km',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: 'Ukončit trasu',
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onStopTracking,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Icon(
                      Icons.stop_rounded,
                      color: Colors.red.shade700,
                      size: 26,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: isPaused ? 'Pokračovat' : 'Pauza',
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onToggleTracking,
                  borderRadius: BorderRadius.circular(16),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 240),
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isPaused
                          ? Colors.green.shade50
                          : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isPaused
                            ? Colors.green.shade200
                            : Colors.orange.shade200,
                      ),
                    ),
                    child: Icon(
                      isPaused ? Icons.play_arrow : Icons.pause,
                      color: isPaused
                          ? Colors.green.shade700
                          : Colors.orange.shade700,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  Widget _buildStatsGrid() {
    final speed = (currentSpeed ?? 0) * 3.6; // m/s to km/h
    final altitude = currentAltitude ?? 0;
    final avgSpeed = (summary?.averageSpeed ?? 0) * 3.6;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatItem(
                'Rychlost',
                speed.toStringAsFixed(1),
                'km/h',
                Icons.speed,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatItem(
                'Výška',
                altitude.toStringAsFixed(0),
                'm n.m.',
                Icons.landscape,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatItem(
                'Průměrná',
                avgSpeed.toStringAsFixed(1),
                'km/h',
                Icons.timelapse,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    String unit,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMapTools(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (onSimulateRoute != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AppButton(
              onPressed: onSimulateRoute!,
              text: 'Simulovat trasu',
              icon: Icons.play_circle_outline,
              type: AppButtonType.secondary,
              size: AppButtonSize.medium,
            ),
          ),
        if (onOfflineMaps != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AppButton(
              onPressed: onOfflineMaps!,
              text: 'Offline mapy',
              icon: Icons.download_for_offline_outlined,
              type: AppButtonType.secondary,
              size: AppButtonSize.medium,
            ),
          ),
      ],
    );
  }

  Widget _buildDragHandleOrCloseButton() {
    final showClose = sheetPosition > 0.8;

    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Center(
        child: AnimatedCrossFade(
          duration: const Duration(milliseconds: 300),
          crossFadeState: showClose
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          firstChild: const StrakataSheetHandle(),
          secondChild: GestureDetector(
            onTap: onClose,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 20, color: Colors.black54),
            ),
          ),
        ),
      ),
    );
  }
}
