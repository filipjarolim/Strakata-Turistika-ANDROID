import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../config/app_colors.dart';
import '../../../models/forms/form_config.dart';
import '../../../models/forms/form_context.dart';
import '../form_design.dart';

class RouteSummaryWidget extends StatelessWidget {
  final FormFieldWidget field;

  const RouteSummaryWidget({Key? key, required this.field}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final formContext = Provider.of<FormContext>(context);
    final summary = formContext.trackingSummary;

    if (summary == null) {
      return const FormSectionCard(
        title: 'Souhrn trasy',
        icon: Icons.summarize_rounded,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text('Žádná data k zobrazení'),
        ),
      );
    }

    return FormSectionCard(
      title: field.label,
      subtitle: 'Přehled metrik před finálním uložením.',
      icon: Icons.summarize_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatRow(Icons.straighten, 'Vzdálenost', '${(summary.totalDistance / 1000).toStringAsFixed(2)} km'),
          _buildStatRow(Icons.timer_outlined, 'Doba trvání', _formatDuration(summary.duration)),
          _buildStatRow(Icons.speed, 'Průměrná rychlost', '${(summary.averageSpeed * 3.6).toStringAsFixed(1)} km/h'),
          const Divider(height: 28),
          _buildStatRow(Icons.place_outlined, 'Navštívená místa', '${formContext.places.length}'),
        ],
      ),
    );
  }

  Widget _buildStatRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Text(
            label,
            style: GoogleFonts.libreFranklin(
              color: AppColors.textTertiary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.libreFranklin(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(d.inMinutes.remainder(60));
    return "${twoDigits(d.inHours)}:$twoDigitMinutes";
  }
}
