import 'package:flutter/material.dart';
import '../../config/admin_theme.dart';

enum AppButtonVariant { primary, success, destructive, ghost }
enum AppButtonSize { sm, md, lg, xl }

class AppButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final IconData? icon;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.md,
    this.icon,
  });

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double height = _getHeight();
    final Color backgroundColor = _getBackgroundColor();
    final Color textColor = _getTextColor();
    final double fontSize = widget.size == AppButtonSize.sm ? 10 : 12;

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: widget.onPressed,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: AdminSpacing.lg),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(
              widget.size == AppButtonSize.sm ? AdminRadius.small : AdminRadius.medium,
            ),
            boxShadow: widget.variant == AppButtonVariant.success 
              ? AdminShadows.emeraldGlow 
              : widget.variant == AppButtonVariant.destructive 
                ? AdminShadows.roseGlow 
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, color: textColor, size: fontSize + 2),
                const SizedBox(width: AdminSpacing.sm),
              ],
              Text(
                widget.label.toUpperCase(),
                style: AdminTextStyles.micro.copyWith(
                  color: textColor,
                  fontSize: fontSize,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _getHeight() {
    switch (widget.size) {
      case AppButtonSize.sm: return 32.0;
      case AppButtonSize.md: return 36.0;
      case AppButtonSize.lg: return 40.0;
      case AppButtonSize.xl: return 44.0;
    }
  }

  Color _getBackgroundColor() {
    if (widget.onPressed == null) return AdminColors.zinc200;
    switch (widget.variant) {
      case AppButtonVariant.primary: return AdminColors.zinc900;
      case AppButtonVariant.success: return AdminColors.emerald500;
      case AppButtonVariant.destructive: return AdminColors.rose500;
      case AppButtonVariant.ghost: return Colors.transparent;
    }
  }

  Color _getTextColor() {
    if (widget.onPressed == null) return AdminColors.zinc400;
    if (widget.variant == AppButtonVariant.ghost) return AdminColors.zinc500;
    return AdminColors.white;
  }
}

class StatusBadge extends StatelessWidget {
  final String text;
  final Color color;
  final Color backgroundColor;

  const StatusBadge({
    super.key,
    required this.text,
    required this.color,
    required this.backgroundColor,
  });

  factory StatusBadge.approved() => StatusBadge(
    text: "SCHVÁLENO",
    color: AdminColors.emerald600,
    backgroundColor: AdminColors.emerald100,
  );

  factory StatusBadge.pending() => StatusBadge(
    text: "ČEKÁ",
    color: AdminColors.amber600,
    backgroundColor: AdminColors.amber100,
  );

  factory StatusBadge.rejected() => StatusBadge(
    text: "ZAMÍTNUTO",
    color: AdminColors.rose600,
    backgroundColor: AdminColors.rose100,
  );

  factory StatusBadge.published() => StatusBadge(
    text: "PUBLIKOVÁNO",
    color: AdminColors.emerald600,
    backgroundColor: AdminColors.emerald100,
  );

  factory StatusBadge.draft() => const StatusBadge(
    text: "KONCEPT",
    color: AdminColors.zinc500,
    backgroundColor: AdminColors.zinc100,
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AdminSpacing.sm,
        vertical: AdminSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AdminRadius.small),
      ),
      child: Text(
        text,
        style: AdminTextStyles.micro.copyWith(color: color),
      ),
    );
  }
}

class StatBox extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;

  const StatBox({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AdminSpacing.lg),
      decoration: BoxDecoration(
        color: AdminColors.white.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AdminRadius.xLarge),
        border: Border.all(
          color: AdminColors.white.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AdminSpacing.sm),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AdminRadius.medium),
            ),
            child: Icon(icon, color: iconColor, size: 16),
          ),
          const Spacer(),
          Text(
            label.toUpperCase(),
            style: AdminTextStyles.statLabel,
          ),
          const SizedBox(height: AdminSpacing.xs),
          Text(
            value,
            style: AdminTextStyles.statNumber,
          ),
        ],
      ),
    );
  }
}
