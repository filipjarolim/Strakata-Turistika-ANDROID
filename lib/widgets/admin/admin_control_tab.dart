import 'package:flutter/material.dart';
import '../../models/visit_data.dart';
import '../../repositories/visit_repository.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:io';
import 'admin_widgets.dart';
import '../../widgets/ui/glass_ui.dart';
import '../../widgets/ui/app_button.dart';
import '../../widgets/ui/app_toast.dart';
import '../../utils/type_converter.dart';

class AdminControlTab {
  static Widget build({
    required List<VisitData> visitDataList,
    required bool isLoading,
    required bool isRefreshing,
    required Function(VisitData) onVisitTap,
    required VoidCallback onRefresh,
    required String searchQuery,
    required Function(String) onSearchChanged,
    required String sortBy,
    required Function(String) onSortChanged,
    required bool sortDesc,
    required VoidCallback onSortDirectionChanged,
    required bool isBulkMode,
    required Set<String> selectedVisitIds,
    required Function(String) onToggleVisitSelection,
    required VoidCallback onToggleBulkMode,
    required VoidCallback onShowAdminActivityLogs,
    required VoidCallback onBulkApprove,
    required VoidCallback onBulkReject,
    required TextEditingController searchController,
    required Function(VisitData) onShowRouteDetailsSheet,
  }) {
    if (isLoading) {
      return _buildLoadingState();
    }

    // Calculate stats for pending reviews
    final pendingCount = visitDataList.where((v) => v.state == VisitState.PENDING_REVIEW).length;
    final totalPoints = visitDataList.fold<double>(0, (sum, v) => sum + v.points);
    
    if (visitDataList.isEmpty) {
      return _buildEmptyState(
        icon: Icons.assignment_turned_in,
        title: 'Žádné návštěvy k revizi',
        subtitle: 'Všechny návštěvy byly již zpracovány',
        actionLabel: 'Obnovit',
        onAction: onRefresh,
      );
    }
    
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      color: const Color(0xFF2E7D32),
      backgroundColor: Colors.white,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 100),
        itemCount: visitDataList.length + 2, // +2 for stats card and control panel
        itemBuilder: (context, index) {
          // Stats card
          if (index == 0) {
            return GlassCard(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      icon: Icons.pending_actions_rounded,
                      label: 'ČEKÁ',
                      value: '$pendingCount',
                      color: Colors.orange[800]!,
                    ),
                  ),
                  Container(width: 1, height: 40, color: const Color(0xFFF3F4F6)),
                  Expanded(
                    child: _buildStatItem(
                      icon: Icons.assignment_turned_in_rounded,
                      label: 'CELKEM',
                      value: '${visitDataList.length}',
                      color: Colors.blue[800]!,
                    ),
                  ),
                  Container(width: 1, height: 40, color: const Color(0xFFF3F4F6)),
                  Expanded(
                    child: _buildStatItem(
                      icon: Icons.stars_rounded,
                      label: 'BODY',
                      value: totalPoints.toStringAsFixed(0),
                      color: Colors.amber[800]!,
                    ),
                  ),
                ],
              ),
            );
          }
          
          // Control Panel matching results_page
          if (index == 1) {
            return GlassCard(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              padding: const EdgeInsets.all(16),
              child: _buildControlPanel(
                searchQuery,
                onSearchChanged,
                sortBy,
                onSortChanged,
                sortDesc,
                onSortDirectionChanged,
                isBulkMode,
                selectedVisitIds,
                onToggleBulkMode,
                onShowAdminActivityLogs,
                onBulkApprove,
                onBulkReject,
                searchController,
              ),
            );
          }
          
          // Visit cards
          final visitIndex = index - 2;
          final visitData = visitDataList[visitIndex];
          final isSelected = selectedVisitIds.contains(visitData.id);
          
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: AdminWidgets.buildVisitCard(
              visitData: visitData,
              isSelected: isSelected,
              isBulkMode: isBulkMode,
              onTap: () => onShowRouteDetailsSheet(visitData),
              onToggleSelection: (_) => onToggleVisitSelection(visitData.id), // Wrapper for ID
              onShowDetails: () => onShowRouteDetailsSheet(visitData),
              hasPendingChanges: false, // Or calculate if needed
            ),
          );
        },
      ),
    );
  }
  
  static Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 10),
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF111827),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: Colors.grey[500],
            letterSpacing: 1.0,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }


  
  static Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
    Color? textColor,
  }) {
    final effectiveTextColor = textColor ?? color;
    final isLight = textColor != null;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isLight ? color : color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: isLight ? null : Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: effectiveTextColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: effectiveTextColor,
            ),
          ),
        ],
      ),
    );
  }
  
  static Widget _buildActionButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required Color color,
    required Color backgroundColor,
  }) {
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildControlPanel(
    String searchQuery,
    Function(String) onSearchChanged,
    String sortBy,
    Function(String) onSortChanged,
    bool sortDesc,
    Function() onSortDirectionChanged,
    bool isBulkMode,
    Set<String> selectedVisitIds,
    VoidCallback onToggleBulkMode,
    VoidCallback onShowAdminActivityLogs,
    VoidCallback onBulkApprove,
    VoidCallback onBulkReject,
    TextEditingController searchController,
  ) {
    return Column(
      children: [
        // Row 1: Search Bar (Full Width)
        AdminWidgets.buildSearchBar(
          controller: searchController,
          onChanged: onSearchChanged,
          hintText: 'Hledat podle názvu, místa, uživatele...',
          onClear: () {
            searchController.clear();
            onSearchChanged('');
          },
        ),
        const SizedBox(height: 12),
        
        // Row 2: Sort, Direction, and Bulk Actions
        Row(
          children: [
            // Sort Dropdown
            Expanded(
              child: AdminWidgets.buildDropdown<String>(
                value: sortBy,
                items: ['visitDate', 'points', 'state', 'userName'],
                itemText: (val) {
                  switch (val) {
                    case 'visitDate': return 'Datum';
                    case 'points': return 'Body';
                    case 'state': return 'Stav';
                    case 'userName': return 'Jméno';
                    default: return val;
                  }
                },
                onChanged: (val) {
                  if (val != null) onSortChanged(val);
                },
                hintText: 'Seřadit',
              ),
            ),
            const SizedBox(width: 8),
            
            // Sort Direction
            Container(
              height: 48,
              width: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[200]!),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: IconButton(
                onPressed: onSortDirectionChanged,
                icon: Icon(sortDesc ? Icons.south : Icons.north, color: Colors.grey[700]),
              ),
            ),
             const SizedBox(width: 8),

             // Bulk Mode Toggle
            // Bulk Mode Toggle
            AppButton(
              onPressed: onToggleBulkMode,
              text: isBulkMode ? 'Zrušit' : 'Výběr',
              icon: isBulkMode ? Icons.check_box : Icons.check_box_outline_blank,
              type: isBulkMode ? AppButtonType.destructiveOutline : AppButtonType.secondary,
              size: AppButtonSize.medium,
            ),
          ],
        ),

        // Optional Row 3: Bulk Actions (only visible when in bulk mode)
        if (isBulkMode) ...[
          const SizedBox(height: 12),
          Row(
            children: [
               Expanded(
                child: AppButton(
                  onPressed: selectedVisitIds.isEmpty ? null : onBulkApprove,
                  text: 'Schválit (${selectedVisitIds.length})',
                  icon: Icons.check,
                  type: AppButtonType.primary,
                  size: AppButtonSize.medium,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppButton(
                  onPressed: selectedVisitIds.isEmpty ? null : onBulkReject,
                  text: 'Odmítnout (${selectedVisitIds.length})',
                  icon: Icons.close,
                  type: AppButtonType.destructive,
                  size: AppButtonSize.medium,
                ),
              ),
            ],
          ),
        ],
        
        // Ensure migration button is available for fixing data issues
        const SizedBox(height: 12),
        AdminWidgets.buildMigrationButton(),

      ],
    );
  }

  static Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(
        color: Color(0xFF4CAF50),
      ),
    );
  }

  static Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(
                icon,
                size: 64,
                color: const Color(0xFF9E9E9E),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF666666),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF9E9E9E),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            AppButton(
              onPressed: onAction,
              text: actionLabel,
              icon: Icons.refresh,
              type: AppButtonType.primary,
              size: AppButtonSize.medium,
            ),
          ],
        ),
      ),
    );
  }

  static Color _getStatusColor(String state) {
    switch (state) {
      case 'APPROVED':
        return const Color(0xFF4CAF50);
      case 'PENDING_REVIEW':
        return const Color(0xFFFFA726);
      case 'REJECTED':
        return const Color(0xFFEF5350);
      case 'DRAFT':
        return const Color(0xFF9E9E9E);
      default:
        return const Color(0xFF9E9E9E);
    }
  }

  static IconData _getStatusIcon(String state) {
    switch (state) {
      case 'APPROVED':
        return Icons.check_circle_outline;
      case 'PENDING_REVIEW':
        return Icons.schedule;
      case 'REJECTED':
        return Icons.cancel_outlined;
      case 'DRAFT':
        return Icons.edit_outlined;
      default:
        return Icons.help;
    }
  }

  static String _getStatusText(String state) {
    switch (state) {
      case 'APPROVED':
        return 'Schváleno';
      case 'PENDING_REVIEW':
        return 'Čeká na schválení';
      case 'REJECTED':
        return 'Odmítnuto';
      case 'DRAFT':
        return 'Návrh';
      default:
        return 'Neznámý stav';
    }
  }


  static Future<void> _showApproveConfirmation(
    BuildContext context,
    VisitData visitData,
    VisitRepository visitRepository,
    VoidCallback onRefresh,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Schválit návštěvu?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              visitData.routeTitle ?? visitData.visitedPlaces,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${visitData.points.toStringAsFixed(1)} bodů',
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Opravdu chcete schválit tuto návštěvu?',
              style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Zrušit'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Schválit'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await visitRepository.updateVisitState(
        visitData.id,
        VisitState.APPROVED,
      );
      onRefresh();
      
      if (context.mounted) {
        AppToast.showSuccess(context, 'Návštěva byla schválena');
      }
    }
  }

  static Future<void> _showRejectConfirmation(
    BuildContext context,
    VisitData visitData,
    VisitRepository visitRepository,
    VoidCallback onRefresh,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.cancel, color: Color(0xFFEF4444), size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Odmítnout návštěvu?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              visitData.routeTitle ?? visitData.visitedPlaces,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${visitData.points.toStringAsFixed(1)} bodů',
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Opravdu chcete odmítnout tuto návštěvu?',
              style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Zrušit'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Odmítnout'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await visitRepository.updateVisitState(
        visitData.id,
        VisitState.REJECTED,
        rejectionReason: 'Odmítnuto adminem',
      );
      onRefresh();
      
      if (context.mounted) {
        // Red toast for rejection action
        AppToast.showError(context, 'Návštěva byla odmítnuta');
      }
    }
  }

  // Map and photos preview widget
  static Widget _buildMapAndPhotosPreview(VisitData visitData) {
    // Extract route points
    final track = (visitData.route?['trackPoints'] as List?) ?? 
                  (visitData.route?['points'] as List?) ?? 
                  (visitData.route?['path'] as List?) ?? [];
    final List<LatLng> pts = [];
    if (track is List) {
      for (final item in track) {
        if (item is Map) {
          final lat = TypeConverter.toDouble(item['latitude'] ?? item['lat'] ?? item['y']);
          final lon = TypeConverter.toDouble(item['longitude'] ?? item['lng'] ?? item['lon'] ?? item['x']);
          if (lat != null && lon != null) {
            pts.add(LatLng(lat.toDouble(), lon.toDouble()));
          }
        }
      }
    }

    // Extract photos - combine legacy photos and place photos
    final legacy = visitData.photos ?? [];
    final placePhotos = visitData.places
        .expand((p) => p.photos)
        .map((ph) => ph.url)
        .toList();
    
    final allPhotos = [
      ...legacy.map((m) => (m['url'] ?? '').toString()),
      ...placePhotos,
    ].where((u) {
      if (u.isEmpty) return false;
      // Accept http://, https://, file://, or absolute paths (/data/...)
      return u.startsWith('http://') || 
             u.startsWith('https://') || 
             u.startsWith('file://') || 
             u.startsWith('/');
    }).toList();

    final hasMap = pts.isNotEmpty;
    final hasPhotos = allPhotos.isNotEmpty;
    
    // Check if first photo is a screenshot (from web upload)
    final firstPhoto = legacy.isNotEmpty ? legacy.first : null;
    final isScreenshot = firstPhoto != null && (
      (firstPhoto['title']?.toString().toLowerCase().contains('screenshot') ?? false) ||
      (firstPhoto['title']?.toString().toLowerCase().contains('watch') ?? false) ||
      (firstPhoto['description']?.toString().toLowerCase().contains('screenshot') ?? false)
    );

    if (!hasMap && !hasPhotos) {
      return const SizedBox.shrink();
    }

    return Row(
      children: [
        // Mini map preview OR screenshot preview
        if (hasMap)
          Expanded(
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE0E0E0)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  children: [
                    FlutterMap(
                      options: MapOptions(
                        initialCenter: _calculateCenter(pts),
                        initialZoom: _calculateZoom(pts),
                        interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.none,
                        ),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'cz.strakata.turistika.strakataturistikaandroidapp',
                        ),
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: pts,
                              strokeWidth: 3,
                              color: const Color(0xFF4CAF50),
                            ),
                          ],
                        ),
                        if (pts.isNotEmpty)
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: pts.first,
                                width: 12,
                                height: 12,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF4CAF50),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                ),
                              ),
                              if (pts.length > 1)
                                Marker(
                                  point: pts.last,
                                  width: 12,
                                  height: 12,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2E7D32),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                      ],
                    ),
                    // Map badge
                    Positioned(
                      top: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.map, size: 12, color: Colors.white),
                            SizedBox(width: 3),
                            Text(
                              'Mapa',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else if (!hasMap && isScreenshot && allPhotos.isNotEmpty)
          // Screenshot preview when no GPS data
          Expanded(
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE0E0E0)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      allPhotos.first,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: const Color(0xFFF5F6F7),
                        child: const Icon(Icons.broken_image, color: Color(0xFF9E9E9E)),
                      ),
                    ),
                    // Screenshot badge
                    Positioned(
                      top: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2196F3).withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.watch, size: 12, color: Colors.white),
                            SizedBox(width: 3),
                            Text(
                              'GPS Screenshot',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if ((hasMap || (!hasMap && isScreenshot)) && hasPhotos && allPhotos.length > 1) 
          const SizedBox(width: 8),
        // Mini photos preview - REVAMPED (skip first if it's a screenshot and no map)
        if (hasPhotos && (hasMap || !isScreenshot || allPhotos.length > 1))
          Expanded(
            child: _buildPhotosPreview(
              hasMap || !isScreenshot ? allPhotos : allPhotos.skip(1).toList()
            ),
          ),
      ],
    );
  }

  // Build photos preview widget - REVAMPED for better reliability
  static Widget _buildPhotosPreview(List<String> photos) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE0E0E0)),
        color: const Color(0xFFF5F6F7),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            // Photo grid
            Row(
              children: [
                for (int i = 0; i < (photos.length > 3 ? 3 : photos.length); i++)
                  Expanded(
                    child: Container(
                      margin: EdgeInsets.only(right: i < 2 && photos.length > 1 ? 2 : 0),
                      child: _buildSinglePhoto(photos[i]),
                    ),
                  ),
              ],
            ),
            // Badge with photo count
            Positioned(
              top: 4,
              left: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.photo_library, size: 14, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      '${photos.length}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Build single photo with proper error handling
  static Widget _buildSinglePhoto(String photoUrl) {
    // Remove file:// prefix if present
    final cleanPath = photoUrl.startsWith('file://') 
        ? photoUrl.substring(7) 
        : photoUrl;
    
    final isLocalFile = cleanPath.startsWith('/');
    final isValidUrl = photoUrl.startsWith('http://') || photoUrl.startsWith('https://');

    // Local file - load from device using Image.file()
    if (isLocalFile) {
      final file = File(cleanPath);
      return Image.file(
        file,
        fit: BoxFit.cover,
        width: double.infinity,
        height: 120,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: const Color(0xFFFFEBEE),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 36, color: Color(0xFFE53935)),
                  const SizedBox(height: 6),
                  Text(
                    'Soubor\nnenalezen',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 10, color: Color(0xFFE53935)),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    // Invalid URL - show error
    if (!isValidUrl) {
      return Container(
        color: const Color(0xFFFFEBEE),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 36, color: Color(0xFFE53935)),
              SizedBox(height: 6),
              Text(
                'Neplatné\nURL',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, color: Color(0xFFE53935)),
              ),
            ],
          ),
        ),
      );
    }

    // Valid URL - try to load image from network
    return Image.network(
      photoUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      height: 120,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        final progress = loadingProgress.expectedTotalBytes != null
            ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
            : null;
        return Container(
          color: const Color(0xFFF5F6F7),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 3,
                    color: const Color(0xFF4CAF50),
                  ),
                ),
                if (progress != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${(progress * 100).toInt()}%',
                    style: const TextStyle(fontSize: 10, color: Color(0xFF666666)),
                  ),
                ],
              ],
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: const Color(0xFFFFF3E0),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.broken_image, size: 36, color: Color(0xFFFF9800)),
                SizedBox(height: 6),
                Text(
                  'Chyba\nnačítání',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10, color: Color(0xFFFF9800)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static LatLng _calculateCenter(List<LatLng> pts) {
    if (pts.isEmpty) return const LatLng(49.8175, 15.4730);
    double minLat = pts.first.latitude, maxLat = pts.first.latitude;
    double minLng = pts.first.longitude, maxLng = pts.first.longitude;
    for (final p in pts) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    return LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);
  }

  static double _calculateZoom(List<LatLng> pts) {
    if (pts.isEmpty) return 13.0;
    double minLat = pts.first.latitude, maxLat = pts.first.latitude;
    double minLng = pts.first.longitude, maxLng = pts.first.longitude;
    for (final p in pts) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    final spanLat = (maxLat - minLat).abs();
    final spanLng = (maxLng - minLng).abs();
    final span = spanLat > spanLng ? spanLat : spanLng;
    if (span > 0.1) return 10.0;
    if (span > 0.05) return 11.0;
    if (span > 0.01) return 12.0;
    if (span > 0.005) return 13.0;
    return 14.0;
  }

}
