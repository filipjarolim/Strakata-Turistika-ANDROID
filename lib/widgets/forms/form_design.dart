import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/app_colors.dart';
import '../ui/app_button.dart';
import '../strakata_editorial_background.dart';

class FormDesign {
  const FormDesign._();

  static const EdgeInsets pagePadding = EdgeInsets.fromLTRB(16, 10, 16, 32);
  static const EdgeInsets cardPadding = EdgeInsets.all(16);

  static BoxDecoration cardDecoration() {
    return BoxDecoration(
      color: Colors.white.withValues(alpha: 0.96),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 22,
          offset: const Offset(0, 10),
        ),
      ],
    );
  }

  static InputDecoration inputDecoration({
    required String label,
    String? hint,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      labelStyle: GoogleFonts.libreFranklin(
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary,
      ),
      hintStyle: GoogleFonts.libreFranklin(
        color: AppColors.textTertiary.withValues(alpha: 0.8),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.12)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.12)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.black, width: 1.7),
      ),
    );
  }
}

class FormPageShell extends StatelessWidget {
  const FormPageShell({
    super.key,
    required this.title,
    required this.body,
    this.leading,
    this.bottomBar,
  });

  final String title;
  final Widget body;
  final Widget? leading;
  final Widget? bottomBar;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const Positioned.fill(child: StrakataEditorialBackground()),
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: Text(
              title,
              style: GoogleFonts.libreFranklin(
                fontWeight: FontWeight.w700,
                fontSize: 17,
                color: AppColors.textPrimary,
              ),
            ),
            centerTitle: false,
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            scrolledUnderElevation: 0,
            elevation: 0,
            foregroundColor: AppColors.textPrimary,
            leading: leading,
          ),
          body: body,
          bottomNavigationBar: bottomBar,
        ),
      ],
    );
  }
}

class FormSectionCard extends StatelessWidget {
  const FormSectionCard({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.icon,
    this.padding = FormDesign.cardPadding,
  });

  final Widget child;
  final String? title;
  final String? subtitle;
  final IconData? icon;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: FormDesign.cardDecoration(),
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Row(
              children: [
                if (icon != null) ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0EBE3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, size: 18, color: AppColors.textSecondary),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Text(
                    title!,
                    style: GoogleFonts.libreFranklin(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                style: GoogleFonts.libreFranklin(
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
            const SizedBox(height: 12),
          ],
          child,
        ],
      ),
    );
  }
}

class FormStepHeaderCard extends StatelessWidget {
  const FormStepHeaderCard({
    super.key,
    required this.title,
    required this.stepIndex,
    required this.totalSteps,
    this.subtitle,
  });

  final String title;
  final int stepIndex;
  final int totalSteps;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return FormSectionCard(
      title: title,
      subtitle: subtitle,
      icon: Icons.assignment_rounded,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F4F5),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'Krok $stepIndex z $totalSteps',
              style: GoogleFonts.libreFranklin(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Mobilní varianta stejná jako web.',
              style: GoogleFonts.libreFranklin(
                color: AppColors.textTertiary,
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class FormBottomActionBar extends StatelessWidget {
  const FormBottomActionBar({
    super.key,
    required this.primaryLabel,
    required this.onPrimaryPressed,
    this.secondaryLabel,
    this.onSecondaryPressed,
    this.isLoading = false,
  });

  final String primaryLabel;
  final VoidCallback? onPrimaryPressed;
  final String? secondaryLabel;
  final VoidCallback? onSecondaryPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + MediaQuery.paddingOf(context).bottom),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.98),
        border: Border(
          top: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Row(
        children: [
          if (secondaryLabel != null) ...[
            Expanded(
              child: OutlinedButton(
                onPressed: onSecondaryPressed,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  side: BorderSide(color: Colors.black.withValues(alpha: 0.14)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  foregroundColor: AppColors.textPrimary,
                  backgroundColor: Colors.white,
                ),
                child: Text(
                  secondaryLabel!,
                  style: GoogleFonts.libreFranklin(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: ElevatedButton(
              onPressed: isLoading ? null : onPrimaryPressed,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.black.withValues(alpha: 0.22),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      primaryLabel,
                      style: GoogleFonts.libreFranklin(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<T?> showFormModalSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFFFFFBF7),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 18,
        bottom: MediaQuery.of(ctx).viewInsets.bottom + 18,
      ),
      child: builder(ctx),
    ),
  );
}

Future<void> showFormLoadingDialog(BuildContext context, {String message = 'Ukládám formulář...'}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => Dialog(
      backgroundColor: const Color(0xFFFFFBF7),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 14),
            Text(
              message,
              style: GoogleFonts.libreFranklin(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> showFormStatusDialog(
  BuildContext context, {
  required String title,
  required String message,
  String buttonText = 'Pokračovat',
  VoidCallback? onConfirm,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFFFFFBF7),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        title,
        style: GoogleFonts.libreFranklin(
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
        ),
      ),
      content: Text(
        message,
        style: GoogleFonts.libreFranklin(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w500,
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
      actions: [
        AppButton(
          onPressed: () {
            Navigator.of(ctx).pop();
            onConfirm?.call();
          },
          text: buttonText,
          type: AppButtonType.primary,
        ),
      ],
    ),
  );
}
