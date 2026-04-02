import 'package:flutter/material.dart';

import '../config/app_colors.dart';
import '../config/strakata_design_tokens.dart';

/// Pale yellow-to-white wash matching Domů — use behind transparent scaffolds.
class StrakataEditorialBackground extends StatelessWidget {
  const StrakataEditorialBackground({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.strakataTokens;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            tokens?.heroOverlayTop ?? AppColors.heroOverlayTop,
            const Color(0xFFFFFCF5),
            Colors.white,
          ],
        ),
      ),
      child: child,
    );
  }
}
