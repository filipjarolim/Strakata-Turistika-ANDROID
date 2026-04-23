import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../config/app_colors.dart';
import '../../../models/forms/form_config.dart';
import '../../../models/forms/form_context.dart';
import '../../../services/competition_dashboard_service.dart';
import '../form_design.dart';

/// Matches web `themeKeywordsSelected` in [FormContext.extraData].
class MonthlyThemeWidget extends StatefulWidget {
  final FormFieldWidget field;

  const MonthlyThemeWidget({super.key, required this.field});

  @override
  State<MonthlyThemeWidget> createState() => _MonthlyThemeWidgetState();
}

class _MonthlyThemeWidgetState extends State<MonthlyThemeWidget> {
  final CompetitionDashboardService _dashboard = CompetitionDashboardService();
  late final Future<MonthlyThemeData?> _future;
  int? _appliedKeywordLen;

  @override
  void initState() {
    super.initState();
    _future = _dashboard.getCurrentMonthlyTheme();
  }

  void _syncKeywordCountIfNeeded(FormContext ctx, int len) {
    if (_appliedKeywordLen == len) return;
    _appliedKeywordLen = len;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ctx.setMonthlyThemeKeywordCount(len);
    });
  }

  List<String> _selectedList(FormContext ctx) {
    final raw = ctx.extraData['themeKeywordsSelected'];
    if (raw is List) {
      return raw.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
    }
    return [];
  }

  void _toggle(FormContext ctx, String keyword) {
    final next = List<String>.from(_selectedList(ctx));
    if (next.contains(keyword)) {
      next.remove(keyword);
    } else {
      next.add(keyword);
    }
    ctx.updateField('themeKeywordsSelected', next);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FormContext>(
      builder: (context, formContext, _) {
        return FutureBuilder<MonthlyThemeData?>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return FormSectionCard(
                title: widget.field.label,
                subtitle: 'Načítání z databáze…',
                icon: Icons.palette_outlined,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                ),
              );
            }

            final theme = snapshot.hasError ? null : snapshot.data;
            final keywords = theme?.keywords ?? const <String>[];
            final len = keywords.length;
            _syncKeywordCountIfNeeded(formContext, len);

            if (keywords.isEmpty) {
              return FormSectionCard(
                title: widget.field.label,
                subtitle:
                    'Pro tento měsíc zatím není v databázi nastaveno žádné klíčové slovo. Pole můžete přeskočit.',
                icon: Icons.palette_outlined,
                child: Text(
                  'Téma měsíce není k dispozici.',
                  style: GoogleFonts.libreFranklin(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              );
            }

            final monthLabel = '${theme!.month.toString().padLeft(2, '0')}/${theme.year}';
            final selected = _selectedList(formContext);

            return FormSectionCard(
              title: widget.field.label,
              subtitle:
                  'Vyberte jedno nebo více klíčových slov, která na vaší trase platí ($monthLabel). Stejně jako na webu se ukládají do návštěvy.',
              icon: Icons.palette_outlined,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: keywords.map((kw) {
                  final on = selected.contains(kw);
                  return FilterChip(
                    label: Text(kw),
                    selected: on,
                    onSelected: (_) => _toggle(formContext, kw),
                    selectedColor: AppColors.brand.withValues(alpha: 0.22),
                    checkmarkColor: AppColors.textPrimary,
                    labelStyle: GoogleFonts.libreFranklin(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppColors.textPrimary,
                    ),
                  );
                }).toList(),
              ),
            );
          },
        );
      },
    );
  }
}
