import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../config/app_colors.dart';
import '../../../models/forms/form_config.dart';
import '../../../models/forms/form_context.dart';
import '../../../services/competition_dashboard_service.dart';
import '../form_design.dart';

class StrakataRouteSelectorWidget extends StatefulWidget {
  final FormFieldWidget field;

  const StrakataRouteSelectorWidget({super.key, required this.field});

  @override
  State<StrakataRouteSelectorWidget> createState() =>
      _StrakataRouteSelectorWidgetState();
}

class _StrakataRouteSelectorWidgetState
    extends State<StrakataRouteSelectorWidget> {
  List<StrakataRouteData> _routes = const [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRoutes();
  }

  Future<void> _loadRoutes() async {
    final routes = await CompetitionDashboardService().getActiveStrakataRoutes();
    if (!mounted) return;
    setState(() {
      _routes = routes;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final formContext = context.watch<FormContext>();
    final selectedId = formContext.extraData['strakataRouteId']?.toString();

    return FormSectionCard(
      title: widget.field.label,
      subtitle: 'Vyberte kategorii Strakaté trasy stejně jako na webu.',
      icon: Icons.route_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isLoading) const LinearProgressIndicator(),
          if (!_isLoading && _routes.isEmpty)
            Text(
              'Žádné aktivní Strakaté trasy.',
              style: GoogleFonts.libreFranklin(
                color: AppColors.textTertiary,
                fontWeight: FontWeight.w500,
              ),
            ),
          if (_routes.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _routes.map((r) {
                final selected = selectedId == r.id;
                return ChoiceChip(
                  selected: selected,
                  avatar: Text(r.icon),
                  label: Text(r.label),
                  onSelected: (_) {
                    formContext.updateField('strakataRouteId', r.id);
                    formContext.updateField('strakataRouteLabel', r.label);
                  },
                  selectedColor: const Color(0xFFD5F8E4),
                  labelStyle: GoogleFonts.libreFranklin(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}
