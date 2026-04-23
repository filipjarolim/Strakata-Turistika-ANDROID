import 'package:flutter/material.dart';
import '../../config/app_colors.dart';

enum AppButtonType {
  primary,
  secondary,
  outline,
  ghost,
  destructive,
  destructiveOutline,
}

enum AppButtonSize {
  medium,
  large,
  small,
}

class AppButton extends StatelessWidget {
  final String? text;
  final VoidCallback? onPressed;
  final AppButtonType type;
  final AppButtonSize size;
  final IconData? icon;
  final Widget? leading;
  final bool isLoading;
  final bool expand;
  final double? width;

  const AppButton({
    super.key,
    this.text,
    required this.onPressed,
    this.type = AppButtonType.primary,
    this.size = AppButtonSize.medium,
    this.icon,
    this.leading,
    this.isLoading = false,
    this.expand = false,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: expand ? double.infinity : width,
      height: _getHeight(),
      child: _buildButton(),
    );
  }
  
  Widget _buildButton() {
    final style = _getStyle();
    final isGradientPrimary = type == AppButtonType.primary;

    if (isGradientPrimary) {
      return DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary,
              AppColors.primary.withValues(alpha: 0.88),
            ],
          ),
          borderRadius: BorderRadius.circular(100),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.32),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: style.copyWith(
            backgroundColor: WidgetStateProperty.all(Colors.transparent),
            shadowColor: WidgetStateProperty.all(Colors.transparent),
          ),
          child: _buildContent(),
        ),
      );
    }

    if (type == AppButtonType.outline || type == AppButtonType.destructiveOutline) {
      return OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: style,
        child: _buildContent(),
      );
    } else if (type == AppButtonType.ghost) {
      return TextButton(
        onPressed: isLoading ? null : onPressed,
        style: style,
        child: _buildContent(),
      );
    }
    
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: style,
      child: _buildContent(),
    );
  }
  
  Widget _buildContent() {
    if (isLoading) {
      return SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: _getContentColor(),
        ),
      );
    }
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (leading != null) ...[
          leading!,
          const SizedBox(width: 8),
        ] else if (icon != null) ...[
          Icon(icon, size: _getIconSize(), color: _getContentColor()),
          const SizedBox(width: 8),
        ],
        if (text != null)
          Text(
            text!,
            style: TextStyle(
              fontSize: _getFontSize(),
              fontWeight: FontWeight.w700,
              color: _getContentColor(),
              letterSpacing: 0.0,
            ),
          ),
      ],
    );
  }
  
  ButtonStyle _getStyle() {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );
    final padding = _getPadding();
    
    switch (type) {
      case AppButtonType.primary:
        return ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: shape,
          padding: padding,
        );
      case AppButtonType.secondary:
        return ElevatedButton.styleFrom(
          backgroundColor: AppColors.surfaceMuted,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          shape: shape,
          padding: padding,
        );
      case AppButtonType.destructive:
        return ElevatedButton.styleFrom(
          backgroundColor: AppColors.error,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: shape,
          padding: padding,
        );
      case AppButtonType.outline:
        return OutlinedButton.styleFrom(
          foregroundColor: AppColors.textSecondary,
          side: BorderSide(color: AppColors.border, width: 1.5),
          shape: shape,
          padding: padding,
        );
      case AppButtonType.destructiveOutline:
        return OutlinedButton.styleFrom(
          foregroundColor: AppColors.error,
          side: BorderSide(color: AppColors.error.withValues(alpha: 0.35), width: 1.5),
          shape: shape,
          padding: padding,
          backgroundColor: AppColors.errorContainer,
        );
      case AppButtonType.ghost:
        return TextButton.styleFrom(
          foregroundColor: AppColors.textSecondary,
          shape: shape,
          padding: padding,
        );
    }
  }

  Color _getContentColor() {
    if (onPressed == null) return Colors.grey[400]!;
    
    switch (type) {
      case AppButtonType.primary:
      case AppButtonType.destructive:
        return Colors.white;
      case AppButtonType.secondary:
        return AppColors.textPrimary;
      case AppButtonType.outline:
        return AppColors.textSecondary;
      case AppButtonType.destructiveOutline:
        return AppColors.error;
      case AppButtonType.ghost:
        return AppColors.textSecondary;
    }
  }
  
  double _getHeight() {
    switch (size) {
      case AppButtonSize.small: return 44;
      case AppButtonSize.medium: return 52;
      case AppButtonSize.large: return 56;
    }
  }
  
  double _getFontSize() {
    switch (size) {
      case AppButtonSize.small: return 13;
      case AppButtonSize.medium: return 15;
      case AppButtonSize.large: return 17;
    }
  }
  
  double _getIconSize() {
      switch (size) {
      case AppButtonSize.small: return 16;
      case AppButtonSize.medium: return 20;
      case AppButtonSize.large: return 24;
    }
  }
  
  EdgeInsetsGeometry _getPadding() {
    switch (size) {
      case AppButtonSize.small: 
        return const EdgeInsets.symmetric(horizontal: 16, vertical: 0);
      case AppButtonSize.medium: 
        return const EdgeInsets.symmetric(horizontal: 24, vertical: 0);
      case AppButtonSize.large: 
        return const EdgeInsets.symmetric(horizontal: 32, vertical: 0);
    }
  }
}
