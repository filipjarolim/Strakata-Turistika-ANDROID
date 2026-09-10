import 'package:flutter/material.dart';

class WebMobileSectionCard extends StatelessWidget {
  const WebMobileSectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.margin,
    this.width,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double? width;

  static BoxDecoration decoration() {
    return BoxDecoration(
      color: const Color(0xFFFFFBF7),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0xFFE8E4DC)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      // Material under ListTile so ink/selection aren't hidden by DecoratedBox.
      child: Material(
        color: const Color(0xFFFFFBF7),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFFE8E4DC)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}
