import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../repositories/visit_repository.dart';
import '../models/visit_data.dart';
import '../widgets/ui/app_toast.dart';
import '../widgets/route_thumbnail.dart';
import '../widgets/ui/strakata_primitives.dart';
import '../config/app_colors.dart';
import '../config/app_theme.dart';
import '../config/strakata_design_tokens.dart';
import '../widgets/strakata_editorial_background.dart';

class UserVisitsPage extends StatefulWidget {
  final String userId;
  final String userName;

  const UserVisitsPage({
    super.key,
    required this.userId,
    required this.userName,
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
              : _visits.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.hiking_outlined,
                              size: 64,
                              color: AppColors.textTertiary.withValues(alpha: 0.4),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Žádné schválené návštěvy',
                              textAlign: TextAlign.center,
                              style: AppTheme.editorialHeadline(
                                color: AppColors.textPrimary,
                                fontSize: 22,
                              ).copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tento uživatel zatím nemá veřejné záznamy.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.libreFranklin(
                                fontSize: 15,
                                color: AppColors.textTertiary,
                                fontWeight: FontWeight.w500,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.fromLTRB(
                        StrakataLayout.pageHorizontalInset,
                        8,
                        StrakataLayout.pageHorizontalInset,
                        120,
                      ),
                      itemCount: _visits.length,
                      itemBuilder: (context, index) {
                        final visit = _visits[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBF7),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: const Color(0xFFE8E4DC)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _showRouteDetailsSheet(visit),
                              borderRadius: BorderRadius.circular(24),
                              child: Padding(
                                padding: const EdgeInsets.all(18),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            _getShortVisitTitle(visit),
                                            style: GoogleFonts.libreFranklin(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                          decoration: BoxDecoration(
                                            color: AppColors.brand.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(100),
                                          ),
                                          child: Text(
                                            '${visit.points.toStringAsFixed(1)} bodů',
                                            style: GoogleFonts.libreFranklin(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.brand,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                const SizedBox(height: 8),
                                if (visit.visitedPlaces.isNotEmpty)
                                  _buildPlaceTags(visit.visitedPlaces),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    if (visit.visitDate != null) ...[
                                      const Icon(Icons.calendar_today, size: 14, color: Color(0xFF9E9E9E)),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${visit.visitDate!.day}.${visit.visitDate!.month}.${visit.visitDate!.year}',
                                        style: const TextStyle(fontSize: 12, color: Color(0xFF666666)),
                                      ),
                                      const SizedBox(width: 12),
                                    ],
                                    if (visit.year != 0) ...[
                                      const Icon(Icons.calendar_month, size: 14, color: Color(0xFF9E9E9E)),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Sezóna ${visit.year}',
                                        style: const TextStyle(fontSize: 12, color: Color(0xFF666666)),
                                      ),
                                    ],
                                    const Spacer(),
                                    if (visit.route != null && (visit.route!['trackPoints'] as List?)?.isNotEmpty == true)
                                      Row(
                                        children: [
                                          Icon(Icons.route, size: 14, color: AppColors.brand),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Trasa',
                                            style: GoogleFonts.libreFranklin(
                                              fontSize: 12,
                                              color: AppColors.brand,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
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

  Widget _buildPlaceTags(String places) {
    final placeList = places.split(',').map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
    if (placeList.isEmpty) return const SizedBox.shrink();
    
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: placeList.map((place) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.brand.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.brand.withValues(alpha: 0.28)),
        ),
        child: Text(
          place,
          style: GoogleFonts.libreFranklin(
            fontSize: 12,
            color: AppColors.brand,
            fontWeight: FontWeight.w500,
          ),
        ),
      )).toList(),
    );
  }

  void _showRouteDetailsSheet(VisitData visit) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const StrakataSheetHandle(margin: EdgeInsets.only(top: 12)),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                   // ... (Icon logic could be better but simplified)
                  const Icon(Icons.hiking, color: Color(0xFF4CAF50), size: 28),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getShortVisitTitle(visit),
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Detailed Thumbnail
                    RouteThumbnail(
                       visit: visit,
                       height: 200,
                       borderRadius: 16,
                    ),
                    const SizedBox(height: 20),
                    
                    Text('Podrobnosti', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 10),
                    Text('Body: ${visit.points}'),
                    if (visit.visitDate != null) Text('Datum: ${visit.visitDate}'),
                    // ... More details if needed
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
