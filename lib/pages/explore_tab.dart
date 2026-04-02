import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/app_colors.dart';
import '../config/app_theme.dart';
import '../config/strakata_design_tokens.dart';
import '../services/auth_service.dart';
import '../pages/dynamic_upload_page.dart';
import '../repositories/visit_repository.dart';
import '../models/visit_data.dart';
import '../widgets/tab_switch.dart';
import '../widgets/ui/app_button.dart';
import '../widgets/strakata_editorial_background.dart';

/// Domů — editorial layout: pale wash background, large rounded story cards.
class ExploreTab extends StatelessWidget {
  const ExploreTab({super.key});

  static const double _cardRadius = 28;
  static const String _dogAsset = 'aidrop/dog.png';
  static const String _mountainsAsset = 'aidrop/mountains.png';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: StrakataEditorialBackground(
        child: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              StrakataLayout.pageHorizontalInset,
              20,
              StrakataLayout.pageHorizontalInset,
              120,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _HomeTitleBlock(),
                const SizedBox(height: 28),
                _HeroCompetitionCard(radius: _cardRadius, dogAsset: _dogAsset),
                const SizedBox(height: 20),
                _AboutUsCard(radius: _cardRadius, mountainsAsset: _mountainsAsset),
                const SizedBox(height: 28),
                const _HomeQuickNavRow(),
                const SizedBox(height: 28),
                const RecentActivitySection(),
                const SizedBox(height: 28),
                const ManualUploadSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeTitleBlock extends StatelessWidget {
  const _HomeTitleBlock();

  @override
  Widget build(BuildContext context) {
    final user = AuthService.currentUser;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Strakatá Turistika',
          textAlign: TextAlign.center,
          style: AppTheme.editorialHeadline(
            color: AppColors.textPrimary,
            fontSize: 26,
          ).copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          'Poznávajte Česko se svým psím parťákem',
          textAlign: TextAlign.center,
          style: GoogleFonts.libreFranklin(
            fontSize: 15,
            height: 1.35,
            fontWeight: FontWeight.w500,
            color: AppColors.textTertiary,
          ),
        ),
        if (user != null) ...[
          const SizedBox(height: 14),
          Text(
            'Ahoj, ${user.name.split(' ').first}!',
            textAlign: TextAlign.center,
            style: GoogleFonts.libreFranklin(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}

class _HeroCompetitionCard extends StatelessWidget {
  const _HeroCompetitionCard({
    required this.radius,
    required this.dogAsset,
  });

  final double radius;
  final String dogAsset;

  static const Color _tan = Color(0xFFE8D4BC);
  static const Color _tanDeep = Color(0xFFD4B896);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_tan, _tanDeep.withValues(alpha: 0.85)],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 112, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Objevujte svět tlapku v tlapce.',
                    style: AppTheme.editorialHeadline(
                      color: AppColors.textPrimary,
                      fontSize: 22,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Stačí ujít 3 km, ulovit vrchol nebo památku a body do žebříčku jsou vaše. Každý kilometr se počítá!',
                    style: GoogleFonts.libreFranklin(
                      fontSize: 14,
                      height: 1.45,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF3D3D3D),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _CompetitionPillButton(
                    onTap: () => TabSwitch.of(context)?.switchTo(2),
                  ),
                ],
              ),
            ),
            // Larger dog, nudged past card edges — ClipRRect crops for a “peek” effect.
            Positioned(
              right: -28,
              bottom: -18,
              child: Image.asset(
                dogAsset,
                height: 268,
                fit: BoxFit.contain,
                alignment: Alignment.bottomRight,
                errorBuilder: (_, __, ___) => const SizedBox(
                  height: 268,
                  width: 120,
                  child: Icon(Icons.pets, size: 88, color: Color(0xFF8D6B4A)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompetitionPillButton extends StatelessWidget {
  const _CompetitionPillButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 0,
      borderRadius: BorderRadius.circular(999),
      shadowColor: Colors.black26,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.explore_rounded, size: 22, color: Colors.black),
              const SizedBox(width: 10),
              Text(
                'Soutěžit',
                style: GoogleFonts.libreFranklin(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AboutUsCard extends StatelessWidget {
  const _AboutUsCard({
    required this.radius,
    required this.mountainsAsset,
  });

  final double radius;
  final String mountainsAsset;

  static const Color _tintWhite = Color(0xB8FFFFFF);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                mountainsAsset,
                fit: BoxFit.cover,
                alignment: Alignment.center,
                errorBuilder: (_, __, ___) => const ColoredBox(
                  color: Color(0xFFA8CFE8),
                  child: Center(child: Icon(Icons.landscape_rounded, size: 48, color: Colors.white70)),
                ),
              ),
            ),
            Positioned.fill(
              child: ColoredBox(color: _tintWhite),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Kdo jsme?',
                    style: AppTheme.editorialHeadline(
                      color: AppColors.textPrimary,
                      fontSize: 22,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Jsme komunita milovníků turistiky a psích parťáků. '
                    'Společně objevujeme českou krajinu, sbíráme vrcholy a památky '
                    'a těšíme se z každého kilometru v terénu — soutěžně i jen tak pro radost.',
                    style: GoogleFonts.libreFranklin(
                      fontSize: 14,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF2C2C2C),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeQuickNavRow extends StatelessWidget {
  const _HomeQuickNavRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _TintedHomeCard(
            label: 'Moje data',
            icon: Icons.bar_chart_rounded,
            tint: const Color(0xFFE3EDF8),
            iconColor: const Color(0xFF2563EB),
            onTap: () => TabSwitch.of(context)?.switchTo(1),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _TintedHomeCard(
            label: 'Mapa',
            icon: Icons.map_rounded,
            tint: const Color(0xFFF0EBE3),
            iconColor: const Color(0xFFB45309),
            onTap: () => TabSwitch.of(context)?.switchTo(2),
          ),
        ),
      ],
    );
  }
}

class _TintedHomeCard extends StatelessWidget {
  const _TintedHomeCard({
    required this.label,
    required this.icon,
    required this.tint,
    required this.iconColor,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color tint;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const r = 24.0;
    return Material(
      color: tint,
      borderRadius: BorderRadius.circular(r),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(r),
            border: Border.all(color: Colors.white.withValues(alpha: 0.65), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.85),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 26),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                textAlign: TextAlign.center,
                style: GoogleFonts.libreFranklin(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTheme.editorialHeadline(
        color: AppColors.textPrimary,
        fontSize: 20,
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
        onlyApproved: false,
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
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const _SectionTitle('Poslední aktivita'),
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
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: CircularProgressIndicator(color: AppColors.brand),
            ),
          )
        else if (_recent.isEmpty)
          _EmptyHomePanel(
            message: 'Zatím žádná aktivita.',
          )
        else
          Column(
            children: _recent.map((v) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ActivityItem(v),
                )).toList(),
          ),
      ],
    );
  }
}

class _EmptyHomePanel extends StatelessWidget {
  const _EmptyHomePanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F4EF),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Center(
        child: Text(
          message,
          style: GoogleFonts.libreFranklin(
            color: AppColors.textTertiary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class ActivityItem extends StatelessWidget {
  final VisitData visit;
  const ActivityItem(this.visit, {super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFFFBF7),
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => TabSwitch.of(context)?.switchTo(1),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE8E4DC)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2F0),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.terrain_rounded, color: Color(0xFF5C5C5C)),
            ),
            title: Text(
              visit.routeTitle ?? visit.visitedPlaces,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.libreFranklin(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: AppColors.textPrimary,
              ),
            ),
            subtitle: Text(
              '${visit.points.toStringAsFixed(0)} bodů',
              style: GoogleFonts.libreFranklin(
                color: AppColors.brand,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey[500]),
          ),
        ),
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
        const _SectionTitle('Ruční nahrání'),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _UploadHomeCard(
                label: 'GPX soubor',
                icon: Icons.upload_file_rounded,
                tint: const Color(0xFFE8F0FC),
                iconColor: const Color(0xFF1D4ED8),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const DynamicUploadPage(slug: 'gpx-upload')),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _UploadHomeCard(
                label: 'Screenshot',
                icon: Icons.add_photo_alternate_rounded,
                tint: const Color(0xFFF3E8FF),
                iconColor: const Color(0xFF7C3AED),
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

class _UploadHomeCard extends StatelessWidget {
  const _UploadHomeCard({
    required this.label,
    required this.icon,
    required this.tint,
    required this.iconColor,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color tint;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const r = 24.0;
    return Material(
      color: tint,
      borderRadius: BorderRadius.circular(r),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(r),
            border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(icon, color: iconColor, size: 30),
              const SizedBox(height: 12),
              Text(
                label,
                textAlign: TextAlign.center,
                style: GoogleFonts.libreFranklin(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
