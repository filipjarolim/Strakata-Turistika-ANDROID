import 'dart:ui';
import 'package:flutter/material.dart';
import '../../config/admin_theme.dart';

class BackgroundDecoration extends StatelessWidget {
  const BackgroundDecoration({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(color: AdminColors.zinc50),
        Positioned(
          top: -100,
          left: -100,
          child: _Orb(
            color: AdminColors.blue500.withValues(alpha: 0.15),
            size: 400,
          ),
        ),
        Positioned(
          bottom: 100,
          right: -50,
          child: _Orb(
            color: AdminColors.purple500.withValues(alpha: 0.1),
            size: 350,
          ),
        ),
        Positioned(
          top: 200,
          right: 50,
          child: _Orb(
            color: AdminColors.emerald500.withValues(alpha: 0.08),
            size: 300,
          ),
        ),
      ],
    );
  }
}

class _Orb extends StatelessWidget {
  final Color color;
  final double size;

  const _Orb({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color,
            color.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}

class AdminPageTemplate extends StatelessWidget {
  final Widget title;
  final Widget? subtitle;
  final Widget? icon;
  final List<Widget>? actions;
  final Widget child;
  final bool showHeader;

  const AdminPageTemplate({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.actions,
    required this.child,
    this.showHeader = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const BackgroundDecoration(),
          SafeArea(
            child: Column(
              children: [
                if (showHeader) _buildHeader(context),
                Expanded(
                  child: ContentContainer(
                    child: child,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(AdminSpacing.lg),
      padding: const EdgeInsets.all(AdminSpacing.xxl),
      decoration: BoxDecoration(
        color: AdminColors.white,
        borderRadius: BorderRadius.circular(AdminRadius.huge),
        boxShadow: AdminShadows.elevation3,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (Navigator.canPop(context)) ...[
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(AdminSpacing.md),
                    decoration: BoxDecoration(
                      color: AdminColors.zinc100,
                      borderRadius: BorderRadius.circular(AdminRadius.medium),
                    ),
                    child: const Icon(Icons.arrow_back_rounded, color: AdminColors.zinc900, size: 20),
                  ),
                ),
                const SizedBox(width: AdminSpacing.lg),
              ],
              if (icon != null) ...[
                Container(
                  padding: const EdgeInsets.all(AdminSpacing.lg),
                  decoration: BoxDecoration(
                    color: AdminColors.indigo500.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AdminRadius.icon),
                  ),
                  child: icon,
                ),
                const SizedBox(width: AdminSpacing.lg),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    title,
                    if (subtitle != null) ...[
                      const SizedBox(height: AdminSpacing.xs),
                      subtitle!,
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (actions != null && actions!.isNotEmpty) ...[
            const SizedBox(height: AdminSpacing.xl),
            Container(
              padding: const EdgeInsets.all(AdminSpacing.xs + 2),
              decoration: BoxDecoration(
                color: AdminColors.zinc100,
                borderRadius: BorderRadius.circular(AdminRadius.large),
              ),
              child: Row(
                children: actions!,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class ContentContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;

  const ContentContainer({
    super.key,
    required this.child,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AdminSpacing.lg),
      decoration: BoxDecoration(
        color: AdminColors.glassLow,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AdminRadius.massive),
        ),
        border: Border.all(
          color: AdminColors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AdminRadius.massive),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: padding ?? const EdgeInsets.all(AdminSpacing.xxl),
            child: child,
          ),
        ),
      ),
    );
  }
}
