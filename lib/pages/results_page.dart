import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../repositories/visit_repository.dart';
import '../models/leaderboard_entry.dart';
import '../services/error_recovery_service.dart';
import 'user_visits_page.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_colors.dart';
import '../config/app_theme.dart';
import '../config/strakata_design_tokens.dart';
import '../widgets/strakata_editorial_background.dart';
import '../widgets/ui/strakata_primitives.dart';

class ResultsPage extends StatefulWidget {
  const ResultsPage({super.key});

  @override
  State<ResultsPage> createState() => _ResultsPageState();
}

class _ResultsPageState extends State<ResultsPage> with TickerProviderStateMixin, WidgetsBindingObserver {
  // Data
  final VisitRepository _visitRepository = VisitRepository();
  List<int> availableSeasons = [];
  int? selectedSeason;

  // Leaderboard data for the selected season
  final List<LeaderboardEntry> _leaders = [];

  bool _hasMore = true;
  bool _isInitialLoading = true;
  bool _isLoadingMore = false;
  String _searchQuery = '';
  Timer? _searchDebounce;
  bool _sortLeaderboardByVisits = false;
  
  // Network state
  bool _isOnline = true;
  Timer? _networkTimer;

  // UI
  late final ScrollController _scrollController;
  AnimationController? _animationController;
  Animation<double>? _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    // Add lifecycle observer
    WidgetsBinding.instance.addObserver(this);
    
    _scrollController = ScrollController()..addListener(_onScroll);
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController!, curve: Curves.easeOut),
    );
    
    // Start network monitoring
    _startNetworkMonitor();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadSeasons();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    _searchDebounce?.cancel();
    _networkTimer?.cancel();
    _animationController?.dispose();
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // When app returns to foreground, reload seasons if we have no data
    if (state == AppLifecycleState.resumed) {
      if (availableSeasons.isEmpty && !_isInitialLoading) {
        print('📱 App resumed in ResultsPage, reloading seasons...');
        _loadSeasons();
      }
    }
  }

  void _startNetworkMonitor() {
    // Initial check
    ErrorRecoveryService().isNetworkAvailable().then((available) {
      if (mounted) {
        _updateOnlineState(available);
      }
    });
    _networkTimer?.cancel();
    _networkTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      final available = await ErrorRecoveryService().isNetworkAvailable();
      if (mounted) {
        _updateOnlineState(available);
      }
    });
  }

  void _updateOnlineState(bool online) {
    if (_isOnline == online) return;
    setState(() {
      _isOnline = online;
    });
    
    // When coming back online, reload data if we have no data
    if (online && _leaders.isEmpty) {
      _loadSeasons();
    }
  }

  Future<void> _loadSeasons() async {
    if (!mounted) return;
    setState(() {
      _isInitialLoading = true;
    });
    try {
      final seasons = await _visitRepository.getAvailableSeasons();
      if (!mounted) return;
      setState(() {
        availableSeasons = seasons;
        selectedSeason = seasons.isNotEmpty ? seasons.first : null;
      });
      if (_animationController != null) {
        _animationController!.forward();
      }
      if (selectedSeason != null) {
        await _reloadForCurrentFilters(resetScroll: true);
      } else {
        setState(() {
          _isInitialLoading = false;
        });
      }
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error loading seasons: $e');
      if (!mounted) return;
      setState(() {
        _isInitialLoading = false;
      });
      // Don't show snackbar immediately, network might be flaky
      // _showErrorSnackBar('Chyba načítání sezón');
    }
  }

  void _onScroll() {
    // Leaderboard loads all data at once, no pagination needed
    return;
  }

  Future<void> _reloadForCurrentFilters({bool resetScroll = false}) async {
    if (selectedSeason == null) return;
    setState(() {
      _isInitialLoading = true;
      _leaders.clear();
      _hasMore = true;
    });
    if (resetScroll) {
      if (_scrollController.hasClients) {
        await _scrollController.animateTo(0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut);
      }
    }
    await _loadNextLeaderboardPage();
    if (!mounted) return;
    setState(() {
      _isInitialLoading = false;
    });
  }


  Future<void> _loadNextLeaderboardPage() async {
    if (_isLoadingMore || selectedSeason == null) return;
    setState(() {
      _isLoadingMore = true;
    });
    try {
      final result = await _visitRepository.getLeaderboard(
        season: selectedSeason!,
        page: 1,
        limit: 10000, // Velký limit pro načtení všech záznamů
        searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
        sortByVisits: _sortLeaderboardByVisits,
      );
      final raw = (result['data'] as List<dynamic>).cast<Map<String, dynamic>>();
      final data = raw.map((m) => LeaderboardEntry.fromMap(m)).toList();
      if (!mounted) return;

      setState(() {
        _leaders.clear(); // Vymazat existující data
        _leaders.addAll(data);
        _hasMore = false; // Už nejsou další data k načtení
        _isLoadingMore = false;
      });
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error loading leaderboard: $e');
      if (!mounted) return;
      setState(() {
        _isLoadingMore = false;
      });
      // _showErrorSnackBar('Chyba načítání žebříčku');
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
            toolbarHeight: 78,
            title: Padding(
              padding: const EdgeInsets.fromLTRB(StrakataLayout.pageHorizontalInset, 12, 8, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Žebříček',
                    style: AppTheme.editorialHeadline(
                      color: AppColors.textPrimary,
                      fontSize: 26,
                    ).copyWith(fontWeight: FontWeight.w700),
                  ),
                  if (selectedSeason != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(100),
                              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                            ),
                            child: Text(
                              'Sezóna $selectedSeason',
                              style: GoogleFonts.libreFranklin(
                                color: AppColors.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(
                            '• Nejlepší turisti',
                            style: GoogleFonts.libreFranklin(
                              color: AppColors.textTertiary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            scrolledUnderElevation: 0,
            elevation: 0,
            centerTitle: false,
            actions: [
              TextButton.icon(
                onPressed: () async {
                  final url = Uri.parse('https://strakataturistika.vercel.app/pravidla');
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  }
                },
                icon: Icon(Icons.description_outlined, size: 20, color: AppColors.textPrimary),
                label: Text(
                  'Pravidla',
                  style: GoogleFonts.libreFranklin(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  backgroundColor: Colors.white.withValues(alpha: 0.85),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.9)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0EBE3),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
                ),
                child: IconButton(
                  onPressed: () => _showFilterSheet(),
                  icon: Icon(Icons.tune_rounded, color: AppColors.textPrimary, size: 22),
                  tooltip: 'Filtrovat',
                  style: IconButton.styleFrom(
                    padding: const EdgeInsets.all(8),
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ],
          ),
          body: _isInitialLoading
              ? _buildInitialSkeleton()
              : availableSeasons.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: () async {
                        await _reloadForCurrentFilters(resetScroll: false);
                      },
                      color: AppColors.brand,
                      backgroundColor: Colors.white,
                      child: _buildLeaderboardList(),
                    ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBF7),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE8E4DC)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Icon(
                Icons.emoji_events_outlined,
                size: 56,
                color: AppColors.brand.withValues(alpha: 0.85),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'Žádné výsledky',
              textAlign: TextAlign.center,
              style: AppTheme.editorialHeadline(
                color: AppColors.textPrimary,
                fontSize: 22,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Buďte první a zaznamenejte svůj výlet!',
              style: GoogleFonts.libreFranklin(
                fontSize: 15,
                color: AppColors.textTertiary,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildLeaderboardList() {
    return _fadeAnimation != null
        ? FadeTransition(
            opacity: _fadeAnimation!,
            child: ListView.builder(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                StrakataLayout.pageHorizontalInset,
                20,
                StrakataLayout.pageHorizontalInset,
                120,
              ),
              itemCount: _leaders.isEmpty ? 1 : _leaders.length + 1,
              itemBuilder: (context, index) {
                if (index < _leaders.length) {
                  return _buildLeaderCard(index + 1, _leaders[index]);
                }
                if (_isLoadingMore) return _buildLoadMoreSkeleton();
                if (!_hasMore && _leaders.isNotEmpty) return _buildEndOfList();
                
                 // Empty state for leaderboard
                if (_leaders.isEmpty && !_isInitialLoading && !_isLoadingMore) {
                   return SizedBox(
                    height: MediaQuery.of(context).size.height * 0.6,
                    child: _buildEmptyState(),
                  );
                }
                
                return const SizedBox.shrink();
              },
            ),
          )
        : Center(
            child: CircularProgressIndicator(color: AppColors.brand),
          );
  }






  Widget _buildLeaderCard(int rank, LeaderboardEntry entry) {
    final Color badgeColor = rank == 1
        ? const Color(0xFFFFD700)
        : rank == 2
            ? const Color(0xFFC0C0C0)
            : rank == 3
                ? const Color(0xFFCD7F32)
                : const Color(0xFFE0E0E0);
    
    final Color rankTextColor = rank <= 3 ? Colors.white : const Color(0xFF6B7280);
    final Color rankBgColor = rank <= 3 ? badgeColor : Colors.transparent;
    final BoxBorder? rankBorder = rank <= 3 ? null : Border.all(color: const Color(0xFFE5E7EB), width: 2);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF7),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: const Color(0xFFE8E4DC)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => _showUserVisitsFromLeaderboard(entry),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Rank badge
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: rankBgColor,
                    shape: BoxShape.circle,
                    border: rankBorder,
                    boxShadow: rank <= 3 
                      ? [BoxShadow(color: badgeColor.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 4))] 
                      : null,
                  ),
                  child: Text(
                    '$rank',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: rankTextColor,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                
                // Avatar with premium border
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: rank <= 3 
                      ? LinearGradient(colors: [badgeColor, badgeColor.withValues(alpha: 0.5)], begin: Alignment.topLeft, end: Alignment.bottomRight)
                      : null,
                  ),
                  child: CircleAvatar(
                    radius: 24,
                    backgroundColor: const Color(0xFFF3F4F6),
                    backgroundImage: entry.userImage != null ? NetworkImage(entry.userImage!) : null,
                    child: entry.userImage == null
                        ? Icon(Icons.person_rounded, color: Colors.grey[400], size: 24)
                        : null,
                  ),
                ),
                const SizedBox(width: 16),
                
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.userName.isEmpty ? 'Neznámý uživatel' : entry.userName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.libreFranklin(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (entry.dogName != null && entry.dogName!.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.pets, size: 10, color: AppColors.primary),
                                  const SizedBox(width: 4),
                                  Text(
                                    entry.dogName!,
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
                                  ),
                                ],
                              ),
                            ),
                          if (entry.dogName != null && entry.dogName!.isNotEmpty) const SizedBox(width: 8),
                          if (entry.visitsCount > 0)
                            Text(
                              '${entry.visitsCount} výletů',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey[500]),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Points
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0EBE3),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.85)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded, color: Color(0xFFFFC107), size: 18),
                          const SizedBox(width: 4),
                          Text(
                            entry.totalPoints.toStringAsFixed(0),
                            style: GoogleFonts.libreFranklin(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.4,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'bodů',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey[400]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildInitialSkeleton() {
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
        StrakataLayout.pageHorizontalInset,
        16,
        StrakataLayout.pageHorizontalInset,
        120,
      ),
      itemCount: 8,
      itemBuilder: (context, index) => _skeletonCard(),
    );
  }

  Widget _buildLoadMoreSkeleton() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          _skeletonCard(),
          _skeletonCard(),
        ],
      ),
    );
  }

  Widget _buildEndOfList() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(
        '— Konec seznamu —',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.grey[600]),
      ),
    );
  }

  Widget _skeletonCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF7),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE8E4DC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _skeletonBox(height: 16, width: 180),
                    const SizedBox(height: 8),
                    _skeletonBox(height: 12, width: 120),
                  ],
                ),
              ),
              _skeletonBox(height: 22, width: 80),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _skeletonBox(height: 18, width: 90),
              const SizedBox(width: 12),
              _skeletonBox(height: 12, width: 100),
            ],
          ),
        ],
      ),
    );
  }

  Widget _skeletonBox({required double height, required double width}) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: const Color(0xFFE8E4DC).withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }








  void _showUserVisitsFromLeaderboard(LeaderboardEntry entry) {
    final userId = entry.userId;
    if (userId.isEmpty) return;
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => UserVisitsPage(
          userId: userId,
          userName: entry.userName,
        ),
      ),
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBF7),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: const Color(0xFFE8E4DC)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 32,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: StrakataSheetHandle(
                height: 5,
                borderRadius: 2.5,
                color: Colors.grey[300],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Filtrovat výsledky',
                  style: AppTheme.editorialHeadline(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.close, size: 20, color: Color(0xFF6B7280)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            const Text(
              'Vyberte sezónu',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF374151),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: availableSeasons.map((season) {
                final isSelected = season == selectedSeason;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : Colors.white,
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : Colors.grey[300]!,
                      width: 1.5,
                    ),
                    boxShadow: isSelected 
                      ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))]
                      : null,
                  ),
                  child: InkWell(
                    onTap: () async {
                      if (season != selectedSeason) {
                        setState(() => selectedSeason = season);
                        Navigator.pop(context);
                        await _reloadForCurrentFilters(resetScroll: true);
                      }
                    },
                    borderRadius: BorderRadius.circular(100),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Text(
                        'Sezóna $season',
                        style: TextStyle(
                          color: isSelected ? Colors.white : const Color(0xFF4B5563),
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
} 