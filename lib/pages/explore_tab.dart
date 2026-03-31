import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../config/strakata_design_tokens.dart';
import '../services/auth_service.dart';
import '../pages/dynamic_upload_page.dart';
import '../repositories/visit_repository.dart';
import '../models/visit_data.dart';
import '../widgets/tab_switch.dart';
import '../widgets/ui/app_button.dart';
import '../widgets/ui/strakata_primitives.dart';

class ExploreTab extends StatelessWidget {
  const ExploreTab({super.key});

  @override
  Widget build(BuildContext context) {
    // Get screen height to determine hero height
    final screenHeight = MediaQuery.of(context).size.height;
    final heroHeight = screenHeight * 0.42; 

    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: Stack(
        children: [
          // 1. Hero band (decorative gradient — web parity)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: heroHeight + 30,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    context.strakataTokens?.heroOverlayTop ?? AppColors.heroOverlayTop,
                    StrakataGradients.greenStart,
                    AppColors.brandMuted,
                  ],
                ),
              ),
            ),
          ),
          
          // 2. Gradient Overlay for status bar visibility
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 120,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.3),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // 3. Main Content Sheet
          Positioned.fill(
            top: heroHeight,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  StrakataLayout.pageHorizontalInset,
                  StrakataLayout.pageContentTopInset,
                  StrakataLayout.pageHorizontalInset,
                  120,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                     // Greeting Section
                    const GreetingSection(),
                    const SizedBox(height: 24),

                    // Main Start Button
                    const MainActionCard(),
                    const SizedBox(height: 20),
                    
                    // Quick Stats & Actions Row
                    const Row(
                      children: [
                        Expanded(child: QuickStatCard(label: 'Moje data', icon: Icons.bar_chart_rounded, color: Colors.blue)),
                        SizedBox(width: 16),
                        Expanded(child: QuickStatCard(label: 'Mapa', icon: Icons.map_rounded, color: Colors.orange)),
                      ],
                    ),
                    const SizedBox(height: 32),

                    const RecentActivitySection(),
                    const SizedBox(height: 32),

                    // Manual Upload Section
                    const ManualUploadSection(),
                  ],
                ),
              ),
            ),
          ),
          
          // App Bar Title (Floating)
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: StrakataLayout.pageHorizontalInset,
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Strakatá',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 24,
                    letterSpacing: -0.5,
                    shadows: [Shadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2))],
                  ),
                ),
                Text(
                  'TURISTIKA',
                  style: TextStyle(
                    color: Colors.white, // White text for hero
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    letterSpacing: 2.0,
                    shadows: [Shadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2))],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class GreetingSection extends StatelessWidget {
  const GreetingSection({super.key});

  @override
  Widget build(BuildContext context) {
    final user = AuthService.currentUser;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(bounds),
          child: Text(
            user != null ? 'Ahoj, ${user.name.split(' ')[0]}!' : 'Vítejte!',
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              color: Colors.white, // Required for ShaderMask
              letterSpacing: -1.0,
              height: 1.1,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Připraveni na nové dobrodružství?',
          style: TextStyle(
            fontSize: 17,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }
}

class MainActionCard extends StatelessWidget {
  const MainActionCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2E7D32), Color(0xFF43A047)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2E7D32).withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => TabSwitch.of(context)?.switchTo(2), // GPS
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'NOVÝ VÝLET',
                      style: TextStyle(
                        color: Color(0xFFE8F5E9),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Zaznamenat\ntrasu',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 12, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: const Icon(Icons.play_arrow_rounded, color: Color(0xFF2E7D32), size: 38),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class QuickStatCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const QuickStatCard({super.key, required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: StrakataSurface.cardDecoration(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (label.contains('data')) {
              TabSwitch.of(context)?.switchTo(1);
            } else {
              TabSwitch.of(context)?.switchTo(2);
            }
          },
          borderRadius: BorderRadius.circular(StrakataRadii.app),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 26),
                ),
                const SizedBox(height: 12),
                Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF1F2937)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class RecentActivitySection extends StatefulWidget {
  const RecentActivitySection({super.key});

  @override
  State<RecentActivitySection> createState() => _RecentActivitySectionState();
}

class _RecentActivitySectionState extends State<RecentActivitySection> {
  final VisitRepository _visitRepository = VisitRepository();
  List<VisitData> _recent = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!AuthService.isLoggedIn) {
      if (!mounted) return;
      setState(() => _loading = false);
      return;
    }

    try {
      final season = DateTime.now().year;
      final currentUser = AuthService.currentUser;
      final result = await _visitRepository.getVisits(
        page: 1, 
        limit: 3, 
        seasonYear: season, 
        userId: currentUser?.id, 
        onlyApproved: false, // Show pending/rejected for own activity too? Or usually public valid ones? Let's say user's own.
        // Actually getVisits filter is structured. Let's use it as is.
      );
      if (!mounted) return;
      setState(() {
        _recent = (result['data'] as List<dynamic>).cast<VisitData>();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!AuthService.isLoggedIn) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const StrakataSectionTitle('Poslední aktivita', fontSize: 18),
            AppButton(
              text: 'Zobrazit vše',
              onPressed: () => TabSwitch.of(context)?.switchTo(1),
              type: AppButtonType.ghost,
              size: AppButtonSize.small,
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_loading)
          const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: Color(0xFF2E7D32))))
        else if (_recent.isEmpty)
           Container(
             width: double.infinity,
             padding: const EdgeInsets.all(20),
             decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(16)),
             child: const Center(child: Text('Zatím žádná aktivita.', style: TextStyle(color: Colors.grey))),
           )
        else
          Column(
            children: _recent.map((v) => ActivityItem(v)).toList(),
          ),
      ],
    );
  }
}

class ActivityItem extends StatelessWidget {
  final VisitData visit;
  const ActivityItem(this.visit, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: StrakataSurface.cardDecoration(
        borderRadius: 16,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.terrain, color: Colors.black54),
        ),
        title: Text(
          visit.routeTitle ?? visit.visitedPlaces,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF1F2937)),
        ),
        subtitle: Text(
           '${visit.points.toStringAsFixed(0)} bodů',
           style: const TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.w600),
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
      ),
    );
  }
}

class ManualUploadSection extends StatelessWidget {
  const ManualUploadSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const StrakataSectionTitle('Ruční nahrání', fontSize: 18),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _UploadCard(
                label: 'GPX soubor',
                icon: Icons.upload_file_rounded,
                color: Colors.blue,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const DynamicUploadPage(slug: 'gpx-upload')),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _UploadCard(
                label: 'Screenshot',
                icon: Icons.add_photo_alternate_rounded,
                color: Colors.purple,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const DynamicUploadPage(slug: 'screenshot-upload')),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _UploadCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _UploadCard({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: StrakataSurface.cardDecoration(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(StrakataRadii.app),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Icon(icon, color: color, size: 28),
                const SizedBox(height: 12),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF1F2937)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
