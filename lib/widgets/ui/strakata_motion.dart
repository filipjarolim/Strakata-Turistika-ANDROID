import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../config/season_theme.dart';
import '../../animations/app_animations.dart';

/// Brand-aligned loading indicator with a soft pulse — only animates while visible.
class StrakataLoader extends StatefulWidget {
  const StrakataLoader({
    super.key,
    this.size = 36,
    this.strokeWidth = 3,
    this.color,
    this.label,
  });

  final double size;
  final double strokeWidth;
  final Color? color;
  final String? label;

  @override
  State<StrakataLoader> createState() => _StrakataLoaderState();
}

class _StrakataLoaderState extends State<StrakataLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppAnimations.durationLoaderPulse,
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: AppAnimations.curveStandard),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ??
        Theme.of(context).colorScheme.primary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ScaleTransition(
          scale: _pulse,
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: CircularProgressIndicator(
              strokeWidth: widget.strokeWidth,
              color: color,
              strokeCap: StrokeCap.round,
            ),
          ),
        ),
        if (widget.label != null) ...[
          const SizedBox(height: 12),
          FadeTransition(
            opacity: _pulse,
            child: Text(
              widget.label!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textTertiary,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Compact inline loader for buttons / list tiles.
class StrakataInlineLoader extends StatelessWidget {
  const StrakataInlineLoader({
    super.key,
    this.size = 18,
    this.color,
  });

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: 2.2,
        strokeCap: StrokeCap.round,
        color: color ?? Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

/// Press feedback — scale down while finger is down (active animation only).
class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    this.onTap,
    this.enabled = true,
    this.minScale = 0.96,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool enabled;
  final double minScale;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppAnimations.durationPress,
      reverseDuration: AppAnimations.durationShort,
      lowerBound: widget.minScale,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _down(PointerDownEvent _) {
    if (!widget.enabled) return;
    _controller.reverse();
  }

  void _up(PointerUpEvent _) {
    _controller.forward();
  }

  void _cancel(PointerCancelEvent _) {
    _controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _down,
      onPointerUp: _up,
      onPointerCancel: _cancel,
      child: GestureDetector(
        onTap: widget.enabled ? widget.onTap : null,
        behavior: HitTestBehavior.opaque,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.scale(
              scale: _controller.value,
              child: child,
            );
          },
          child: widget.child,
        ),
      ),
    );
  }
}

/// Entrance fade+slide once when first built (active, short).
class EntranceFadeSlide extends StatefulWidget {
  const EntranceFadeSlide({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = const Offset(0, 0.06),
  });

  final Widget child;
  final Duration delay;
  final Offset offset;

  @override
  State<EntranceFadeSlide> createState() => _EntranceFadeSlideState();
}

class _EntranceFadeSlideState extends State<EntranceFadeSlide>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppAnimations.durationStandard,
    );
    _opacity = CurvedAnimation(
      parent: _controller,
      curve: AppAnimations.curveDecelerate,
    );
    _slide = Tween<Offset>(begin: widget.offset, end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: AppAnimations.curveDecelerate),
    );
    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future<void>.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

/// Season chip preview used in settings.
class SeasonChip extends StatelessWidget {
  const SeasonChip({
    super.key,
    required this.season,
    required this.selected,
    required this.onTap,
  });

  final AppSeason season;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = SeasonPalette.forSeason(season);
    return PressableScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppAnimations.durationShort,
        curve: AppAnimations.curveStandard,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? palette.brand.withValues(alpha: 0.14)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? palette.brand : AppColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(season.icon, size: 18, color: palette.brand),
            const SizedBox(width: 8),
            Text(
              season.labelCs,
              style: TextStyle(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
