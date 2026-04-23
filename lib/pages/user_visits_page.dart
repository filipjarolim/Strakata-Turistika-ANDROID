import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../repositories/visit_repository.dart';
import '../models/visit_data.dart';
import '../widgets/ui/app_toast.dart';
import '../config/app_colors.dart';
import '../config/app_theme.dart';
import '../config/strakata_design_tokens.dart';
import '../widgets/strakata_editorial_background.dart';
import '../widgets/ui/web_mobile_section_card.dart';
import 'results_visit_detail_page.dart';

class UserVisitsPage extends StatefulWidget {
  final String userId;
  final String userName;
  final int? seasonYear;

  const UserVisitsPage({
    super.key,
    required this.userId,
    required this.userName,
    this.seasonYear,
  });

  @override
  State<UserVisitsPage> createState() => _UserVisitsPageState();
}

class _UserVisitsPageState extends State<UserVisitsPage> {
  final VisitRepository _visitRepository = VisitRepository();
  List<VisitData> _visits = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserVisits();
  }

  Future<void> _loadUserVisits() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Get all visits for this user
      // Assuming this page is for public viewing of a user's approved visits?
      // Since it's parameterized with userId, it implies looking at another user.
      const onlyApproved = true;

      final result = await _visitRepository.getVisits(
         page: 1,
         limit: 1000,
         userId: widget.userId,
         seasonYear: widget.seasonYear,
         onlyApproved: onlyApproved,
      );

      if (mounted) {
        setState(() {
          _visits = (result['data'] as List<dynamic>).cast<VisitData>();
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error loading user visits: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        AppToast.showError(context, 'Chyba načítání návštěv uživatele');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const Positioned.fill(child: StrakataEditorialBackground()),
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: Text(
              'Návštěvy — ${widget.userName}',
              style: GoogleFonts.libreFranklin(
                fontWeight: FontWeight.w700,
                fontSize: 17,
                color: AppColors.textPrimary,
              ),
            ),
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            scrolledUnderElevation: 0,
            elevation: 0,
            foregroundColor: AppColors.textPrimary,
          ),
          body: _isLoading
              ? Center(
                  child: CircularProgressIndicator(color: AppColors.brand),
                )
              : RefreshIndicator(
                  onRefresh: _loadUserVisits,
                  color: AppColors.brand,
                  backgroundColor: Colors.white,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      StrakataLayout.pageHorizontalInset,
                      8,
                      StrakataLayout.pageHorizontalInset,
                      120,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildProfileSeasonHeader(),
                        const SizedBox(height: 16),
                        _buildStatsGrid(),
                        const SizedBox(height: 16),
                        _buildHistoryCard(),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildProfileSeasonHeader() {
    return WebMobileSectionCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: const Color(0xFFF0EBE3),
            child: Text(
              widget.userName.isNotEmpty ? widget.userName.trim().characters.first.toUpperCase() : '?',
              style: GoogleFonts.libreFranklin(
                fontWeight: FontWeight.w800,
                fontSize: 22,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.seasonYear != null ? 'Sezóna ${widget.seasonYear}' : 'Sezóna',
                  style: GoogleFonts.libreFranklin(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textTertiary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.userName,
                  style: AppTheme.editorialHeadline(
                    color: AppColors.textPrimary,
                    fontSize: 24,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'Statistiky a historie výprav ve Strakaté turistice.',
                  style: GoogleFonts.libreFranklin(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    final totalPoints = _visits.fold<double>(0.0, (sum, v) => sum + v.points);
    final totalDistance = _visits.fold<double>(0.0, (sum, v) => sum + _distanceFromVisit(v));
    final uniqueDays = _visits
        .map((v) => v.visitDate)
        .whereType<DateTime>()
        .map((d) => '${d.year}-${d.month}-${d.day}')
        .toSet()
        .length;

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.55,
      children: [
        _buildMiniStatCard('Celkem bodů', totalPoints.toStringAsFixed(0), Icons.emoji_events_outlined),
        _buildMiniStatCard('Výlety', _visits.length.toString(), Icons.map_outlined),
        _buildMiniStatCard('Naplánováno', '${totalDistance.round()} km', Icons.trending_up_rounded),
        _buildMiniStatCard('Aktivních dní', uniqueDays.toString(), Icons.calendar_month_outlined),
      ],
    );
  }

  Widget _buildMiniStatCard(String label, String value, IconData icon) {
    return WebMobileSectionCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.libreFranklin(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.libreFranklin(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard() {
    final sorted = [..._visits]..sort((a, b) {
      final ad = a.visitDate ?? a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bd = b.visitDate ?? b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bd.compareTo(ad);
    });

    return WebMobileSectionCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: const Color(0xFFE8E4DC).withValues(alpha: 0.7),
                  width: 1,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Historie výprav',
                  style: GoogleFonts.libreFranklin(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Chronologicky seřazené schválené výlety.',
                  style: GoogleFonts.libreFranklin(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          if (sorted.isEmpty)
            Padding(
              padding: const EdgeInsets.all(22),
              child: Center(
                child: Text(
                  'Zatím žádné výpravy v této sezóně.',
                  style: GoogleFonts.libreFranklin(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
              child: Column(
                children: sorted.map(_buildVisitRow).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVisitRow(VisitData visit) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: WebMobileSectionCard.decoration(),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => _openVisitDetail(visit),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getShortVisitTitle(visit),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.libreFranklin(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatDate(visit.visitDate),
                        style: GoogleFonts.libreFranklin(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0EBE3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '+${visit.points.toStringAsFixed(0)}',
                    style: GoogleFonts.libreFranklin(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  double _distanceFromVisit(VisitData visit) {
    final dynamic raw = visit.extraPoints['distanceKm'] ??
        visit.extraPoints['distance'] ??
        visit.extraPoints['DistanceKm'] ??
        visit.extraPoints['Vzdálenost'];
    if (raw is num) return raw.toDouble();
    if (raw is String) return double.tryParse(raw.replaceAll(',', '.')) ?? 0.0;
    return 0.0;
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Datum neznámé';
    return '${date.day}.${date.month}.${date.year}';
  }

  String _getShortVisitTitle(VisitData visit) {
    if (visit.routeTitle != null && visit.routeTitle!.isNotEmpty && visit.routeTitle!.length <= 50) {
      return visit.routeTitle!;
    }
    
    final places = visit.visitedPlaces.split(',').map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
    if (places.isEmpty) return 'Bez názvu trasy';
    
    if (places.length <= 3) {
      return places.join(', ');
    } else {
      return '${places.take(3).join(', ')}...';
    }
  }

  void _openVisitDetail(VisitData visit) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ResultsVisitDetailPage(
          visit: visit,
          seasonYear: widget.seasonYear ?? visit.year,
          userName: widget.userName,
        ),
      ),
    );
  }
}
