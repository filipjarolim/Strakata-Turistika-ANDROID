import 'package:flutter/material.dart';
import '../../config/admin_theme.dart';
import 'admin_common_widgets.dart';

class HubDashboardCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String count;
  final VoidCallback onTap;

  const HubDashboardCard({
    super.key,
    required this.icon,
    required this.title,
    required this.count,
    required this.onTap,
  });

  @override
  State<HubDashboardCard> createState() => _HubDashboardCardState();
}

class _HubDashboardCardState extends State<HubDashboardCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(0, _isHovered ? -4 : 0, 0),
          padding: const EdgeInsets.all(AdminSpacing.lg),
          decoration: BoxDecoration(
            color: AdminColors.white,
            borderRadius: BorderRadius.circular(AdminRadius.xxLarge),
            boxShadow: _isHovered ? AdminShadows.elevation4 : AdminShadows.elevation2,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(AdminSpacing.md),
                decoration: BoxDecoration(
                  color: AdminColors.indigo500.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AdminRadius.large),
                ),
                child: Icon(widget.icon, color: AdminColors.indigo500, size: 24),
              ),
              const SizedBox(height: AdminSpacing.lg),
              Text(
                widget.title,
                style: AdminTextStyles.headingLarge,
              ),
              const SizedBox(height: AdminSpacing.xs),
              Text(
                widget.count,
                style: AdminTextStyles.body,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NewsCard extends StatelessWidget {
  final String title;
  final String date;
  final String content;
  final Widget badge;
  final String? imageUrl;
  final List<Widget>? actions;

  const NewsCard({
    super.key,
    required this.title,
    required this.date,
    required this.content,
    required this.badge,
    this.imageUrl,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AdminColors.white,
        borderRadius: BorderRadius.circular(AdminRadius.large),
        boxShadow: AdminShadows.elevation2,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (imageUrl != null && imageUrl!.isNotEmpty)
            SizedBox(
              height: 140,
              width: double.infinity,
              child: Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: AdminColors.zinc100,
                  child: const Center(
                    child: Icon(Icons.image_not_supported, color: AdminColors.zinc300),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(AdminSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(date, style: AdminTextStyles.small),
                    badge,
                  ],
                ),
                const SizedBox(height: AdminSpacing.md),
                Text(title, style: AdminTextStyles.heading),
                const SizedBox(height: AdminSpacing.sm),
                Text(
                  content,
                  style: AdminTextStyles.body,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                if (actions != null) ...[
                  const SizedBox(height: AdminSpacing.lg),
                  const Divider(color: AdminColors.zinc100, height: 1),
                  const SizedBox(height: AdminSpacing.lg),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: actions!,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class VisitDataCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final List<StatBox> stats;
  final List<String> images;
  final Widget? map;
  final List<Widget>? actions;

  const VisitDataCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.stats,
    required this.images,
    this.map,
    this.actions,
  });

  @override
  State<VisitDataCard> createState() => _VisitDataCardState();
}

class _VisitDataCardState extends State<VisitDataCard> {
  bool _mapExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AdminColors.white,
        borderRadius: BorderRadius.circular(AdminRadius.huge),
        boxShadow: AdminShadows.elevation3,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.map != null) ...[
            GestureDetector(
              onTap: () => setState(() => _mapExpanded = !_mapExpanded),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: _mapExpanded ? 450 : 220,
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(AdminRadius.huge)),
                ),
                clipBehavior: Clip.antiAlias,
                child: widget.map,
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.all(AdminSpacing.xxl + 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.title, style: AdminTextStyles.headingLarge),
                Text(widget.subtitle, style: AdminTextStyles.body),
                const SizedBox(height: AdminSpacing.xl),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: AdminSpacing.md,
                  crossAxisSpacing: AdminSpacing.md,
                  // Taller cells than 1.2 — StatBox (icon + label + value) needs vertical room
                  childAspectRatio: 0.98,
                  children: widget.stats,
                ),
                if (widget.images.isNotEmpty) ...[
                  const SizedBox(height: AdminSpacing.xl),
                  SizedBox(
                    height: 100,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: widget.images.length,
                      separatorBuilder: (_, __) => const SizedBox(width: AdminSpacing.md),
                      itemBuilder: (context, index) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(AdminRadius.medium),
                          child: Image.network(
                            widget.images[index],
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 100,
                              height: 100,
                              color: AdminColors.zinc100,
                              child: const Icon(Icons.image_not_supported, color: AdminColors.zinc400),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
                if (widget.actions != null && widget.actions!.isNotEmpty) ...[
                  const SizedBox(height: AdminSpacing.xl),
                  const Divider(color: AdminColors.zinc100),
                  const SizedBox(height: AdminSpacing.lg),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: widget.actions!,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
