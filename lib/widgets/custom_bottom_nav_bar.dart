import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/app_colors.dart';
import '../services/auth_service.dart';

class _NavMetrics {
  static const double outerHorizontalPadding = 14;
  static const double bottomSpacing = 6;
  static const double compactGap = 8;
  static const double pillRadius = 999;
  static const double pillInnerPaddingX = 8;
  static const double pillInnerPaddingY = 6;
  static const double indicatorInsetY = 6;
  static const double avatarSize = 46;
  static const double itemRadius = 999;
  static const double itemMinHeight = 44;
  static const double itemGap = 2;
  static const double iconSize = 20;
  static const double labelSize = 10;
}

/// Floating pill navigation (Domů, Soutěž, Výsledky) + circular profile to the right.
class CustomBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final bool isTracking;
  final String? trackingInfo;
  final VoidCallback? onTrackingTap;

  const CustomBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.isTracking = false,
    this.trackingInfo,
    this.onTrackingTap,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final user = AuthService.currentUser;
    final screenW = MediaQuery.sizeOf(context).width;
    final showTrackingStrip = isTracking && currentIndex != 2;
    final navPillWidth = (screenW * 0.7).clamp(252.0, 340.0);
    final rowWidth =
        navPillWidth + _NavMetrics.compactGap + _NavMetrics.avatarSize;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        _NavMetrics.outerHorizontalPadding,
        0,
        _NavMetrics.outerHorizontalPadding,
        _NavMetrics.bottomSpacing + bottomInset,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: navPillWidth,
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAFAF6),
                    borderRadius: BorderRadius.circular(_NavMetrics.pillRadius),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1A0F172A),
                        blurRadius: 32,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: _NavMetrics.pillInnerPaddingX,
                      vertical: _NavMetrics.pillInnerPaddingY,
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final itemWidth = (constraints.maxWidth - (_NavMetrics.itemGap * 2)) / 3;
                        final activeSlot = currentIndex == 0 ? 0 : (currentIndex == 2 ? 1 : 2);
                        final left = (itemWidth + _NavMetrics.itemGap) * activeSlot;
                        return Stack(
                          children: [
                            AnimatedPositioned(
                              duration: const Duration(milliseconds: 260),
                              curve: Curves.easeOutCubic,
                              left: left,
                              top: 0,
                              bottom: 0,
                              child: Container(
                                width: itemWidth,
                                margin: const EdgeInsets.symmetric(vertical: _NavMetrics.indicatorInsetY - _NavMetrics.pillInnerPaddingY),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE5E5E5),
                                  borderRadius: BorderRadius.circular(_NavMetrics.itemRadius),
                                ),
                              ),
                            ),
                            Row(
                              children: [
                                _PillNavItem(
                                  label: 'Domů',
                                  icon: Icons.home_outlined,
                                  selectedIcon: Icons.home_rounded,
                                  isSelected: currentIndex == 0,
                                  onTap: () => onTap(0),
                                ),
                                const SizedBox(width: _NavMetrics.itemGap),
                                _PillNavItem(
                                  label: 'Soutěž',
                                  icon: Icons.explore_outlined,
                                  selectedIcon: Icons.explore_rounded,
                                  isSelected: currentIndex == 2,
                                  isHighlighted: isTracking && currentIndex != 2,
                                  onTap: () => onTap(2),
                                ),
                                const SizedBox(width: _NavMetrics.itemGap),
                                _PillNavItem(
                                  label: 'Výsledky',
                                  icon: Icons.bar_chart_outlined,
                                  selectedIcon: Icons.bar_chart_rounded,
                                  isSelected: currentIndex == 1,
                                  onTap: () => onTap(1),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: _NavMetrics.compactGap),
              _ProfileAvatarButton(
                isSelected: currentIndex == 3,
                imageUrl: user?.image,
                onTap: () => onTap(3),
              ),
            ],
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: showTrackingStrip
                ? Padding(
                    key: const ValueKey('tracking_strip'),
                    padding: const EdgeInsets.only(top: 8),
                    child: SizedBox(
                      width: rowWidth,
                      child: _TrackingStrip(
                        info: trackingInfo,
                        onTap: onTrackingTap ?? () => onTap(2),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _PillNavItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool isSelected;
  final bool isHighlighted;
  final VoidCallback onTap;

  const _PillNavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.isSelected,
    this.isHighlighted = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isTrackingHighlight = isHighlighted && !isSelected;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(_NavMetrics.itemRadius),
          splashColor: AppColors.primary.withValues(alpha: 0.10),
          highlightColor: AppColors.primary.withValues(alpha: 0.05),
          child: Container(
            constraints: const BoxConstraints(minHeight: _NavMetrics.itemMinHeight),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_NavMetrics.itemRadius),
              color: isTrackingHighlight ? const Color(0xFFFFF5F5) : Colors.transparent,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isSelected ? selectedIcon : icon,
                  size: _NavMetrics.iconSize,
                  color: isTrackingHighlight ? const Color(0xFFE53935) : Colors.black,
                ),
                const SizedBox(height: 1),
                Opacity(
                  opacity: isSelected ? 1.0 : 0.9,
                  child: Text(
                    label,
                    style: GoogleFonts.libreFranklin(
                      fontSize: _NavMetrics.labelSize,
                      fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                      color: Colors.black,
                      height: 1.0,
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
}

class _ProfileAvatarButton extends StatelessWidget {
  final bool isSelected;
  final String? imageUrl;
  final VoidCallback onTap;

  const _ProfileAvatarButton({
    required this.isSelected,
    required this.imageUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        scale: isSelected ? 1.02 : 1.0,
        child: Container(
          width: _NavMetrics.avatarSize,
          height: _NavMetrics.avatarSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(
              color: isSelected ? AppColors.primary : const Color(0xFFE5E7EB),
              width: isSelected ? 2.5 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
                spreadRadius: -1,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipOval(
            child: imageUrl != null && imageUrl!.isNotEmpty
                ? Image.network(
                    imageUrl!,
                    fit: BoxFit.cover,
                    width: _NavMetrics.avatarSize,
                    height: _NavMetrics.avatarSize,
                    errorBuilder: (_, __, ___) => _defaultAvatar(),
                  )
                : _defaultAvatar(),
          ),
        ),
      ),
    );
  }

  Widget _defaultAvatar() {
    return Container(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFF9FAFB),
      ),
      child: Icon(Icons.person_rounded, size: 24, color: Colors.grey[500]),
    );
  }
}

class _TrackingStrip extends StatelessWidget {
  final String? info;
  final VoidCallback onTap;

  const _TrackingStrip({required this.info, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: const Color(0xFF111827),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            children: [
              const Icon(
                Icons.radio_button_checked_rounded,
                size: 12,
                color: Colors.redAccent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  info?.isNotEmpty == true ? info! : 'Tracking bezi na pozadi',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.libreFranklin(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: Colors.white70,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
