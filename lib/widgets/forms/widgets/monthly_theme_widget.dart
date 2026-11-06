import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../config/app_colors.dart';
import '../../../models/forms/form_config.dart';
import '../../../models/forms/form_context.dart';
import '../../../services/competition_dashboard_service.dart';
import '../form_design.dart';

/// Přehled tématu měsíce. Slova se nezaškrtávají — píšou se do místa.
class MonthlyThemeWidget extends StatefulWidget {
  final FormFieldWidget field;

  const MonthlyThemeWidget({super.key, required this.field});

  @override
  State<MonthlyThemeWidget> createState() => _MonthlyThemeWidgetState();
}

class _MonthlyThemeWidgetState extends State<MonthlyThemeWidget> {
  final CompetitionDashboardService _dashboard = CompetitionDashboardService();
  Future<MonthlyThemeData?>? _future;
  // Rok+měsíc data návštěvy, pro který je _future načtené.
  int? _loadedYearMonth;
  int? _appliedKeywordLen;

  /// Téma se načítá podle data návštěvy (ne podle dneška), aby dodatečné
  /// doplnění staršího výletu nabídlo téma správného měsíce.
  Future<MonthlyThemeData?> _futureFor(FormContext ctx) {
    final date = ctx.visitDate;
    final ym = date.year * 100 + date.month;
    if (_future == null || _loadedYearMonth != ym) {
      _loadedYearMonth = ym;
      _appliedKeywordLen = null;
      _future = _dashboard.getCurrentMonthlyTheme(forDate: date);
    }
    return _future!;
  }

  void _syncKeywordCountIfNeeded(FormContext ctx, int len) {
    if (_appliedKeywordLen == len) return;
    _appliedKeywordLen = len;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ctx.setMonthlyThemeKeywordCount(len);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FormContext>(
      builder: (context, formContext, _) {
        return FutureBuilder<MonthlyThemeData?>(
          future: _futureFor(formContext),
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
              final d = formContext.visitDate;
              final missingMonthLabel =
                  '${d.month.toString().padLeft(2, '0')}/${d.year}';
              return FormSectionCard(
                title: widget.field.label,
                subtitle:
                    'Pro měsíc $missingMonthLabel není v databázi nastaveno žádné klíčové slovo. Pole můžete přeskočit.',
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

            return FormSectionCard(
              title: widget.field.label,
              subtitle:
                  'Přehled tématu $monthLabel. Přidejte místo typu Téma měsíce a slovo napište do názvu nebo poznámky. První nové slovo v měsíci je 1. část.',
              icon: Icons.palette_outlined,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: keywords.map((kw) {
                  return Chip(
                    label: Text(kw),
                    backgroundColor: AppColors.brand.withValues(alpha: 0.12),
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
