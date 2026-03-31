import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/visit_data.dart';
import '../models/tracking_summary.dart';
import '../widgets/route_thumbnail.dart';
import '../widgets/ui/app_button.dart';
import '../widgets/ui/app_toast.dart';
import '../widgets/ui/strakata_primitives.dart';
import '../config/strakata_design_tokens.dart';
import '../services/logging_service.dart';
import '../repositories/visit_repository.dart';
import '../services/auth_service.dart';
import '../services/database/database_service.dart';
import '../services/cloudinary_service.dart';
import 'dynamic_form_page.dart';
import '../services/vector_tile_provider.dart';
import '../services/mapy_cz_download_service.dart';
import 'package:latlong2/latlong.dart';
import 'package:image_picker/image_picker.dart';

class UserProfilePage extends StatefulWidget {
  const UserProfilePage({Key? key}) : super(key: key);

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  final VisitRepository _visitRepository = VisitRepository();
  List<VisitData> _userVisits = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserVisits();
  }

  Future<void> _loadUserVisits() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final currentUser = AuthService.currentUser;
      if (currentUser != null) {
        final visits = await _visitRepository.getVisitsByUserId(currentUser.id);
        // Sort by visitDate desc then createdAt desc, include all states
        visits.sort((a, b) {
          final ad = a.visitDate ?? a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bd = b.visitDate ?? b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bd.compareTo(ad);
        });
        if (mounted) {
          setState(() {
            _userVisits = visits;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      if (mounted) {
        AppToast.showError(context, 'Chyba načítání návštěv: $e');
      }
    }
  }

  double _getTotalPoints() {
    return _userVisits.fold(0.0, (sum, visit) => sum + visit.points);
  }

  double _getTotalDistance() {
    return _userVisits.fold(0.0, (sum, visit) {
          if (visit.route != null && visit.route!['totalDistance'] != null) {
            return sum + (visit.route!['totalDistance'] as num);
          }
          return sum;
        });
  }

  @override
  Widget build(BuildContext context) {
    // Removed embedded login check as it is now gated in main.dart
    final currentUser = AuthService.currentUser;
    // Fallback if somehow reached without auth (e.g. direct link in future)
    if (currentUser == null) {
       return const SizedBox(); // Or a "Not Authorized" placeholder
    }

    final totalPoints = _getTotalPoints();
    final totalDistance = _getTotalDistance() / 1000; // Convert to km

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.05),
        title: Padding(
          padding: const EdgeInsets.fromLTRB(StrakataLayout.pageHorizontalInset, 14, 8, 14),
          child: const Text(
            'Můj Profil',
            style: TextStyle(
              color: Color(0xFF111827),
              fontWeight: FontWeight.w800,
              fontSize: 24,
              letterSpacing: -0.5,
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF2E7D32),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadUserVisits,
              color: const Color(0xFF2E7D32),
              backgroundColor: Colors.white,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  StrakataLayout.pageHorizontalInset,
                  28,
                  StrakataLayout.pageHorizontalInset,
                  24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Header Card
                    _buildProfileHeaderCard(currentUser),
                    const SizedBox(height: 24),

                    // Stats Section
                    Container(
                      decoration: StrakataSurface.cardDecoration(),
                      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildStatItem('Celkem body', totalPoints.toStringAsFixed(1), Icons.star_rounded, Colors.amber[700]!),
                          ),
                          Container(width: 1, height: 40, color: Colors.grey[200]),
                          Expanded(
                            child: _buildStatItem('Najeto km', totalDistance.toStringAsFixed(1), Icons.route_rounded, Colors.blue[700]!),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // "Mé trasy" section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const StrakataSectionTitle('Moje Trasy'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _userVisits.isEmpty
                        ? _buildEmptyRoutesState()
                        : SizedBox(
                            height: 248,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: _userVisits.length > 5 ? 5 : _userVisits.length,
                              separatorBuilder: (context, index) => const SizedBox(width: 16),
                              itemBuilder: (context, index) {
                                final visit = _userVisits[index];
                                return _buildRouteCard(visit);
                              },
                            ),
                          ),

                    const SizedBox(height: 32),

                    // Menu Section
                    const StrakataSectionTitle('Nastavení a Akce'),
                    const SizedBox(height: 16),
                    Container(
                      decoration: StrakataSurface.cardDecoration(),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          _buildMenuItem(Icons.edit_outlined, 'Upravit profil', _showEditProfileSheet),
                          _buildDivider(),
                          _buildMenuItem(Icons.download_for_offline_outlined, 'Offline mapy', _showOfflineMapsSheet),
                          _buildDivider(),
                          _buildMenuItem(Icons.help_outline_rounded, 'O aplikaci a podpora', _showHelpAndAboutSheet),
                          if ((AuthService.currentUser?.role ?? '') == 'ADMIN') ...[
                            _buildDivider(),
                            _buildMenuItem(Icons.admin_panel_settings_outlined, 'Admin kontrola', () {
                              Navigator.of(context).pushNamed('/admin-review');
                            }, iconColor: Colors.purple[700]),
                            _buildDivider(),
                            _buildMenuItem(Icons.delete_forever_rounded, 'Resetovat aplikaci', _showResetConfirmation, iconColor: Colors.red[700]),
                          ],
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                     // Logout Button
                    SizedBox(
                      width: double.infinity,
                      child: AppButton(
                        onPressed: _showLogoutConfirmation,
                        icon: Icons.logout_rounded,
                        text: 'Odhlásit se',
                        type: AppButtonType.destructiveOutline,
                        size: AppButtonSize.medium,
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    Center(
                      child: AppButton(
                        onPressed: _showDeleteAccountConfirmation,
                        text: 'Smazat účet',
                        type: AppButtonType.ghost,
                        size: AppButtonSize.small,
                      ),
                    ),
                    
                    const SizedBox(height: 150),
                  ],
                ),
              ),
            ),
    );
  }

  // --- UI Builders ---

  Widget _buildProfileHeaderCard(User? user) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      // No decoration needed as it's just text info above stats, keeping it clean
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            user?.name ?? 'Uživatel',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
              letterSpacing: -0.5,
            ),
          ),
          if (user?.email != null)
            Text(
              user!.email,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color iconColor) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 28),
        ),
        const SizedBox(height: 12),
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[500],
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItem(IconData icon, String title, VoidCallback onTap, {Color? iconColor}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (iconColor ?? const Color(0xFF2E7D32)).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor ?? const Color(0xFF2E7D32), size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF374151),
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.grey[400], size: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(height: 1, thickness: 1, color: Colors.grey[100], indent: 70);
  }

  Widget _buildEmptyRoutesState() {
    return Container(
      width: double.infinity,
      decoration: StrakataSurface.cardDecoration(),
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.hiking_rounded, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text(
            'Žádné trasy',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Vyrazte na výlet a začněte objevovat!',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500], fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteCard(VisitData visit) {
    return Container(
      width: 280, // Slightly wider
      decoration: StrakataSurface.cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showRouteDetailsSheet(visit),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Hero Image / Map Preview
              RouteThumbnail(
                visit: visit,
                height: 120,
                borderRadius: 0,
              ),
              
              // 2. Content
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // State Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getStatusColor(visit.state).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _getStatusText(visit.state),
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _getStatusColor(visit.state)),
                          ),
                        ),
                        
                        // Date
                        if (visit.visitDate != null)
                          Text(
                            '${visit.visitDate!.day}.${visit.visitDate!.month}.${visit.visitDate!.year}',
                            style: TextStyle(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w500),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    
                    // Title
                    Text(
                      visit.routeTitle ?? visit.visitedPlaces,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Stats Row
                    Row(
                      children: [
                        _buildMiniStat(Icons.star_rounded, '${visit.points.toStringAsFixed(0)} b', Colors.amber[700]!),
                        const SizedBox(width: 16),
                        if (visit.route != null && visit.route!['totalDistance'] != null)
                           _buildMiniStat(Icons.directions_walk, '${((visit.route!['totalDistance'] as num) / 1000).toStringAsFixed(1)} km', Colors.blue[600]!),
                      ],
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

  Widget _buildMiniStat(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.grey[700])),
      ],
    );
  }

  // --- Logic Helpers (Bottom Sheets, Dialogs, etc.) ---

  void _showHelpAndAboutSheet() {
    showStrakataModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(child: StrakataSheetHandle()),
            const SizedBox(height: 24),
            const StrakataSheetTitle('O aplikaci a podpora'),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.info_outline, color: Colors.blue)),
              title: const Text('O aplikaci', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              onTap: () {
                Navigator.pop(ctx);
                showAboutDialog(
                  context: context,
                  applicationName: 'Strakatá Turistika',
                  applicationVersion: '1.1.0',
                  applicationIcon: const Icon(Icons.hiking, size: 48, color: Color(0xFF2E7D32)),
                );
              },
            ),
            const Divider(height: 1),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.help_outline, color: Colors.green)),
              title: const Text('Pomoc a podpora', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              onTap: () {
                Navigator.pop(ctx);
                _showSupportContact();
              },
            ),
          ],
        ),
      ),
    );
  }
  
  void _showSupportContact() {
    showStrakataModalBottomSheet(
      context: context,
      builder: (ctx2) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.support_agent_rounded, size: 48, color: Color(0xFF2E7D32)),
            const SizedBox(height: 16),
            const StrakataSheetTitle('Kontaktujte nás'),
            const SizedBox(height: 8),
            const Text('Máte dotaz nebo problém? Napište nám.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.email_outlined, size: 20, color: Colors.black87),
                  SizedBox(width: 10),
                  Text('info@strakata.cz', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _showOfflineMapsSheet() {
    showStrakataModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(child: StrakataSheetHandle()),
              const SizedBox(height: 20),
              const StrakataSheetTitle('Offline mapy'),
              const SizedBox(height: 16),
              
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50], 
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blue[100]!),
                ),
                child: FutureBuilder<Map<String, dynamic>>(
                future: VectorTileProvider.getDetailedStats(),
                builder: (context, snap) {
                  final stats = snap.data ?? {};
                  final total = stats['totalTiles'] ?? 0;
                  final bytes = stats['totalCompressedBytes'] ?? 0;
                  final mb = (bytes is int) ? (bytes / 1024 / 1024).toStringAsFixed(1) : '0.0';
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                       Column(
                         children: [
                           Text(total.toString(), style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.blue[900])),
                           Text('Dlaždic', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blue[700])),
                         ],
                       ),
                       Container(width: 1, height: 40, color: Colors.blue[200]),
                       Column(
                         children: [
                           Text('$mb MB', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.blue[900])),
                           Text('Velikost', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blue[700])),
                         ],
                       ),
                    ],
                  );
                },
              ),
              ),

              const SizedBox(height: 24),
              const Text('Stáhnout oblast', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 12),
              
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      onPressed: () async {
                        final sw = const LatLng(48.9, 12.3);
                        final ne = const LatLng(50.6, 16.0);
                        await MapyCzDownloadService.downloadBounds(
                          southwest: sw, northeast: ne, minZoom: 8, maxZoom: 12, concurrency: 24, batchSize: 800,
                        );
                        if (mounted) Navigator.of(ctx).pop();
                      },
                      icon: Icons.public,
                      text: 'ČR (Základ)',
                      type: AppButtonType.outline,
                      size: AppButtonSize.medium,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppButton(
                      onPressed: () async {
                        final sw = const LatLng(49.95, 14.15);
                        final ne = const LatLng(50.25, 14.75);
                        await MapyCzDownloadService.downloadBounds(
                          southwest: sw, northeast: ne, minZoom: 10, maxZoom: 15, concurrency: 24, batchSize: 800,
                        );
                        if (mounted) Navigator.of(ctx).pop();
                      },
                      icon: Icons.location_city,
                      text: 'Praha (Detail)',
                      type: AppButtonType.outline,
                      size: AppButtonSize.medium,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  onPressed: () async {
                    await MapyCzDownloadService.clearCache();
                    if (mounted) Navigator.of(ctx).pop();
                  },
                  icon: Icons.delete_outline,
                  text: 'Vymazat stažené mapy',
                  type: AppButtonType.destructiveOutline,
                  size: AppButtonSize.medium,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getStatusColor(VisitState state) {
    switch (state) {
      case VisitState.APPROVED: return const Color(0xFF10B981);
      case VisitState.PENDING_REVIEW: return const Color(0xFFF59E0B);
      case VisitState.REJECTED: return const Color(0xFFEF4444);
      case VisitState.DRAFT: return const Color(0xFF6B7280);
    }
  }

  IconData _getStatusIcon(VisitState state) {
    switch (state) {
      case VisitState.APPROVED: return Icons.check_circle_rounded;
      case VisitState.PENDING_REVIEW: return Icons.schedule_rounded;
      case VisitState.REJECTED: return Icons.cancel_rounded;
      case VisitState.DRAFT: return Icons.edit_note_rounded;
    }
  }

  String _getStatusText(VisitState state) {
    switch (state) {
      case VisitState.APPROVED: return 'Schváleno';
      case VisitState.PENDING_REVIEW: return 'Čeká na kontrolu';
      case VisitState.REJECTED: return 'Zamítnuto';
      case VisitState.DRAFT: return 'Rozpracováno';
    }
  }

  void _showRouteDetailsSheet(VisitData visit) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const StrakataSheetHandle(margin: EdgeInsets.only(top: 12)),
            
            // Header
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 56, height: 56,
                    decoration: BoxDecoration(
                      color: _getStatusColor(visit.state).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(_getStatusIcon(visit.state), color: _getStatusColor(visit.state), size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          visit.routeTitle ?? visit.visitedPlaces,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF111827), height: 1.2),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                             color: _getStatusColor(visit.state).withValues(alpha: 0.1),
                             borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _getStatusText(visit.state),
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _getStatusColor(visit.state)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFF3F4F6)),
                      ),
                      child: Column(
                        children: [
                           _buildDetailRow(Icons.star_outline, 'Body', '${visit.points.toStringAsFixed(1)} b'),
                           const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),
                           if (visit.route != null && visit.route!['totalDistance'] != null)
                              _buildDetailRow(Icons.route_outlined, 'Vzdálenost', '${((visit.route!['totalDistance'] as num) / 1000).toStringAsFixed(1)} km'),
                           if (visit.visitDate != null)
                              _buildDetailRow(Icons.calendar_today_outlined, 'Datum', '${visit.visitDate!.day}.${visit.visitDate!.month}.${visit.visitDate!.year}'),
                           if (visit.dogName != null && visit.dogName!.isNotEmpty)
                              _buildDetailRow(Icons.pets, 'Pes', visit.dogName!),
                        ],
                      ),
                    ),
                    
                    if (visit.places.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      const Align(alignment: Alignment.centerLeft, child: Text('Navštívená místa', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
                      const SizedBox(height: 12),
                      ...visit.places.map((place) => Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2))],
                        ),
                        child: Row(
                          children: [
                            Icon(_getPlaceTypeIcon(place.type), color: const Color(0xFF4B5563), size: 20),
                            const SizedBox(width: 12),
                            Expanded(child: Text(place.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)))),
                          ],
                        ),
                      )),
                    ],
                  ],
                ),
              ),
            ),
            
            if (visit.state == VisitState.DRAFT) ...[
               Container(
                 padding: const EdgeInsets.all(24),
                 decoration: BoxDecoration(
                   color: Colors.white,
                   border: Border(top: BorderSide(color: Colors.grey[200]!)),
                 ),
                 child: Row(
                   children: [
                     Expanded(
                       child: OutlinedButton(
                         onPressed: () async {
                           final confirm = await showDialog<bool>(
                             context: context,
                             builder: (c) => AlertDialog(
                                title: const Text('Smazat?'), content: const Text('Opravdu smazat tento návrh?'),
                                actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Zrušit')), TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Smazat', style: TextStyle(color: Colors.red)))],
                             ),
                           );
                           if (confirm == true) {
                             await _visitRepository.deleteVisit(visit.id);
                             if (mounted) { Navigator.pop(context); _loadUserVisits(); }
                           }
                         },
                         style: OutlinedButton.styleFrom(
                           padding: const EdgeInsets.symmetric(vertical: 16),
                           foregroundColor: Colors.red,
                           side: const BorderSide(color: Colors.red),
                           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                         ),
                         child: const Text('Smazat'),
                       ),
                     ),
                     const SizedBox(width: 16),
                     Expanded(
                       child: ElevatedButton(
                         onPressed: () {
                           Navigator.pop(context);
                            Navigator.of(context).push(MaterialPageRoute(builder: (_) => DynamicFormPage(
                              slug: 'gps-tracking',
                              trackingSummary: TrackingSummary(
                                  isTracking: false,
                                  startTime: visit.createdAt ?? DateTime.now(),
                                  duration: Duration(seconds: visit.route?['duration'] ?? 0),
                                  totalDistance: (visit.route?['totalDistance'] as num?)?.toDouble() ?? 0,
                                  averageSpeed: 0, maxSpeed: 0, totalElevationGain: 0, totalElevationLoss: 0, minAltitude: null, maxAltitude: null,
                                  trackPoints: (visit.route?['trackPoints'] as List?)?.map((p) => TrackPoint(
                                    latitude: (p['latitude'] as num).toDouble(),
                                    longitude: (p['longitude'] as num).toDouble(),
                                    timestamp: DateTime.parse(p['timestamp']),
                                    speed: (p['speed'] as num?)?.toDouble() ?? 0,
                                    accuracy: (p['accuracy'] as num?)?.toDouble() ?? 0,
                                  )).toList() ?? [],
                           ))));
                         },
                         style: ElevatedButton.styleFrom(
                           padding: const EdgeInsets.symmetric(vertical: 16),
                           backgroundColor: const Color(0xFF2E7D32),
                           foregroundColor: Colors.white,
                           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                         ),
                         child: const Text('Pokračovat'),
                       ),
                     ),
                   ],
                 ),
               ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: Colors.grey[500]),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500)),
            ],
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF111827))),
        ],
      ),
    );
  }

  IconData _getPlaceTypeIcon(PlaceType type) {
    switch (type) {
      case PlaceType.PEAK: return Icons.landscape_rounded;
      case PlaceType.TOWER: return Icons.location_city_rounded;
      case PlaceType.TREE: return Icons.park_outlined;
      case PlaceType.OTHER: return Icons.place_outlined;
    }
  }

  void _showEditProfileSheet() {
    final user = AuthService.currentUser;
    final nameController = TextEditingController(text: user?.name ?? '');
    final dogNameController = TextEditingController(text: user?.dogName ?? '');
    String? selectedImageUrl = user?.image;
    File? selectedImageFile;
    bool isUploadingImage = false;

    showStrakataModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const StrakataSheetHandle(),
                  const SizedBox(height: 20),
                  const StrakataSheetTitle('Upravit profil'),
                  const SizedBox(height: 24),
                  
                  GestureDetector(
                    onTap: isUploadingImage ? null : () => _pickProfileImage(setModalState, (File imageFile) {
                      selectedImageFile = imageFile;
                      selectedImageUrl = null;
                    }),
                    child: Container(
                      width: 100, height: 100,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey[200]!, width: 2),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                           ClipOval(
                             child: selectedImageFile != null 
                                ? Image.file(selectedImageFile!, width: 100, height: 100, fit: BoxFit.cover)
                                : selectedImageUrl != null
                                   ? Image.network(selectedImageUrl!, width: 100, height: 100, fit: BoxFit.cover)
                                   : const Icon(Icons.person, size: 50, color: Colors.grey),
                           ),
                           if (isUploadingImage) const CircularProgressIndicator(color: Color(0xFF2E7D32)),
                           if (!isUploadingImage) 
                             Positioned(bottom: 0, right: 0, child: Container(padding: const EdgeInsets.all(6), decoration: const BoxDecoration(color: Color(0xFF2E7D32), shape: BoxShape.circle), child: const Icon(Icons.camera_alt, color: Colors.white, size: 14))),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Jméno',
                      filled: true,
                      fillColor: const Color(0xFFF9FAFB),
                      prefixIcon: const Icon(Icons.person_outline_rounded, color: Colors.grey),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2E7D32), width: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: dogNameController,
                    decoration: InputDecoration(
                      labelText: 'Jméno psa',
                      filled: true,
                      fillColor: const Color(0xFFF9FAFB),
                      prefixIcon: const Icon(Icons.pets_rounded, color: Colors.grey),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2E7D32), width: 1.5)),
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: AppButton(
                      onPressed: isUploadingImage ? null : () async {
                           final u = AuthService.currentUser;
                           if (u == null) { Navigator.pop(ctx); return; }
                           final newName = nameController.text.trim();
                           final newDogName = dogNameController.text.trim();
                           
                           setModalState(() => isUploadingImage = true);
                           
                           try {
                             if (selectedImageFile != null) {
                               final url = await CloudinaryService.uploadImage(selectedImageFile!);
                               if (url != null) await _updateUserImage(u.id, url);
                             }
                             await _updateUserName(u.id, newName.isEmpty ? u.name : newName);
                             await AuthService.updateUserDogName(u.id, newDogName);
                             
                             if (mounted) { Navigator.pop(ctx); setState(() {}); }
                           } catch (e) {
                             LoggingService().log('Error updating profile: $e', level: 'ERROR');
                           } finally {
                             setModalState(() => isUploadingImage = false);
                           }
                      },
                      text: 'Uložit změny',
                      type: AppButtonType.primary,
                      size: AppButtonSize.large,
                      isLoading: isUploadingImage,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _pickProfileImage(StateSetter setModalState, Function(File) onImageSelected) async {
    final ImagePicker picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
         ListTile(leading: const Icon(Icons.photo_library), title: const Text('Galerie'), onTap: () => Navigator.pop(context, ImageSource.gallery)),
         ListTile(leading: const Icon(Icons.camera_alt), title: const Text('Fotoaparát'), onTap: () => Navigator.pop(context, ImageSource.camera)),
      ])),
    );

    if (source != null) {
      final image = await picker.pickImage(source: source, maxWidth: 800, maxHeight: 800, imageQuality: 85);
      if (image != null) {
        setModalState(() { onImageSelected(File(image.path)); });
      }
    }
  }

  Future<void> _updateUserImage(String userId, String imageUrl) async {
    final users = await DatabaseService().getCollection('users');
    if (users != null) await users.updateOne({'_id': userId}, {'\$set': {'image': imageUrl, 'updatedAt': DateTime.now().toIso8601String()}});
    final u = AuthService.currentUser;
    if (u != null) {
       final updated = User(id: u.id, email: u.email, name: u.name, image: imageUrl, isOAuth: u.isOAuth, provider: u.provider, providerAccountId: u.providerAccountId, role: u.role, isTwoFactorEnabled: u.isTwoFactorEnabled, dogName: u.dogName);
       final prefs = await SharedPreferences.getInstance();
       await prefs.setString('user_session', jsonEncode(updated.toMap()));
       AuthService.updateCurrentUser(updated);
    }
  }

  Future<void> _updateUserName(String userId, String name) async {
    final users = await DatabaseService().getCollection('users');
    if (users != null) await users.updateOne({'_id': userId}, {'\$set': {'name': name, 'updatedAt': DateTime.now().toIso8601String()}});
    final u = AuthService.currentUser;
    if (u != null) {
       final updated = User(id: u.id, email: u.email, name: name, image: u.image, isOAuth: u.isOAuth, provider: u.provider, providerAccountId: u.providerAccountId, role: u.role, isTwoFactorEnabled: u.isTwoFactorEnabled, dogName: u.dogName);
       final prefs = await SharedPreferences.getInstance();
       await prefs.setString('user_session', jsonEncode(updated.toMap()));
       AuthService.updateCurrentUser(updated);
    }
  }

  void _showLogoutConfirmation() {
    showDialog(context: context, builder: (c) => AlertDialog(
      title: const Text('Odhlásit se'), content: const Text('Opravdu se chcete odhlásit?'),
      actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Zrušit')), TextButton(onPressed: () async { Navigator.pop(c); await AuthService.signOut(); if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/login', (r) => false); }, child: const Text('Odhlásit', style: TextStyle(color: Colors.red)))],
    ));
  }

  void _showResetConfirmation() {
    showDialog(context: context, builder: (c) => AlertDialog(
      title: const Text('Resetovat aplikaci'), 
      content: const Text('Opravdu chcete vymazat všechna lokální data a nastavení? Aplikace se uvede do stavu po instalaci a budete odhlášeni.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Zrušit')), 
        TextButton(onPressed: () async { 
          Navigator.pop(c); 
          final prefs = await SharedPreferences.getInstance();
          await prefs.clear();
          await AuthService.signOut(); 
          if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/login', (r) => false); 
        }, child: const Text('RESETOVAT', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)))
      ],
    ));
  }

  void _showDeleteAccountConfirmation() {
    showDialog(context: context, builder: (c) => AlertDialog(
      title: const Text('Smazat účet'), content: const Text('Tato akce je nevratná. Opravdu chcete smazat účet?'),
      actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Zrušit')), TextButton(onPressed: () async { Navigator.pop(c); await _deleteAccount(); }, child: const Text('SMAZAT', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)))],
    ));
  }

  Future<void> _deleteAccount() async {
     try {
       final u = AuthService.currentUser;
       if (u == null) return;
       final users = await DatabaseService().getCollection('users');
       if (users != null) await users.deleteOne({'_id': u.id});
       final visits = await DatabaseService().getCollection('visits');
       if (visits != null) await visits.deleteMany({'userId': u.id});
       await AuthService.signOut();
       if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/login', (r) => false);
     } catch (e) {
       AppToast.showError(context, 'Chyba: $e');
     }
  }
}