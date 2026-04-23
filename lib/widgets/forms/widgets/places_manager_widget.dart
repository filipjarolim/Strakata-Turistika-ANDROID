import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../config/app_colors.dart';
import '../../../models/forms/form_config.dart';
import '../../../models/forms/form_context.dart';
import '../../../models/visit_data.dart';
import '../../../models/place_type_config.dart';
import '../../../widgets/ui/app_button.dart';
import '../form_design.dart';

class PlacesManagerWidget extends StatefulWidget {
  final FormFieldWidget field;

  const PlacesManagerWidget({Key? key, required this.field}) : super(key: key);

  @override
  State<PlacesManagerWidget> createState() => _PlacesManagerWidgetState();
}

class _PlacesManagerWidgetState extends State<PlacesManagerWidget> {
  List<PlaceTypeConfig> _placeTypes = [];
  bool _isLoadingTypes = true;

  @override
  void initState() {
    super.initState();
    _loadPlaceTypes();
  }

  Future<void> _loadPlaceTypes() async {
    try {
      final configs = await PlaceTypeConfigService().getPlaceTypeConfigs();
      if (mounted) {
        setState(() {
          _placeTypes = configs;
          _isLoadingTypes = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingTypes = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final formContext = Provider.of<FormContext>(context);

    return FormSectionCard(
      title: widget.field.label,
      subtitle: 'Přidejte všechna navštívená místa z výletu.',
      icon: Icons.place_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFDBEAFE)),
            ),
            child: Text(
              'Bodovaná místa vybírejte tady v kroku míst (vrchol/rozhledna/strom).',
              style: GoogleFonts.libreFranklin(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1D4ED8),
              ),
            ),
          ),
          if (formContext.places.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF0EBE3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${formContext.places.length} míst přidáno',
                style: GoogleFonts.libreFranklin(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          if (formContext.places.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE8E4DC)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.add_location_alt_outlined, color: Color(0xFF9CA3AF), size: 32),
                  const SizedBox(height: 8),
                  Text('Zatím žádná místa', style: GoogleFonts.libreFranklin(color: AppColors.textTertiary)),
                  const SizedBox(height: 12),
                  AppButton(
                    onPressed: () => _showAddPlaceDialog(context, formContext),
                    text: 'Přidat místo',
                    type: AppButtonType.secondary,
                    size: AppButtonSize.small,
                    icon: Icons.add,
                  ),
                ],
              ),
            )
          else ...[
            ...formContext.places.map((place) => _buildPlaceItem(context, place, formContext)),
            const SizedBox(height: 12),
            AppButton(
              onPressed: () => _showAddPlaceDialog(context, formContext),
              text: 'Přidat další místo',
              type: AppButtonType.ghost,
              size: AppButtonSize.small,
              icon: Icons.add,
              expand: true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlaceItem(BuildContext context, Place place, FormContext formContext) {
    final config = _placeTypes.firstWhere(
      (c) => c.name == place.type.name,
      orElse: () => PlaceTypeConfig(
        id: 'unknown',
        name: place.type.name,
        label: place.type.name,
        icon: Icons.place,
        points: 0,
        color: Colors.grey,
        order: 99, 
        createdAt: DateTime.now(), 
        updatedAt: DateTime.now(),
      ),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8E4DC)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: config.color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(config.icon, color: config.color, size: 20),
        ),
        title: Text(
          place.name,
          style: GoogleFonts.libreFranklin(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: Text(
          '${config.label} • ${place.photos.length} fotek',
          style: GoogleFonts.libreFranklin(color: AppColors.textTertiary, fontSize: 12),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.grey),
          onPressed: () {
            final newPlaces = List<Place>.from(formContext.places)..remove(place);
            formContext.updatePlaces(newPlaces);
          },
        ),
        onTap: () => _editPlace(context, place, formContext),
      ),
    );
  }

  void _showAddPlaceDialog(BuildContext context, FormContext formContext) {
    _showPlaceDialog(context, formContext, null);
  }

  void _editPlace(BuildContext context, Place place, FormContext formContext) {
    _showPlaceDialog(context, formContext, place);
  }

  void _showPlaceDialog(BuildContext context, FormContext formContext, Place? existingPlace) {
    final nameController = TextEditingController(text: existingPlace?.name ?? '');
    String selectedTypeName = existingPlace?.type.name ?? (_placeTypes.isNotEmpty ? _placeTypes.first.name : 'PEAK');
    // List<File> newPhotos = []; // TODO: Implement photo selection

    showFormModalSheet(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD6D3CC),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              Text(
                existingPlace == null ? 'Přidat místo' : 'Upravit místo',
                style: GoogleFonts.libreFranklin(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: FormDesign.inputDecoration(label: 'Název místa', hint: 'Např. Sněžka'),
              ),
              const SizedBox(height: 16),
              if (_isLoadingTypes)
                const LinearProgressIndicator()
              else
                DropdownButtonFormField<String>(
                  value: selectedTypeName,
                  decoration: FormDesign.inputDecoration(label: 'Typ místa'),
                  items: _placeTypes.map((t) => DropdownMenuItem(
                    value: t.name,
                    child: Row(
                      children: [
                        Icon(t.icon, size: 16, color: t.color),
                        const SizedBox(width: 12),
                        Text(t.label),
                      ],
                    ),
                  )).toList(),
                  onChanged: (val) {
                    if (val != null) setSheetState(() => selectedTypeName = val);
                  },
                ),
              if (!_isLoadingTypes) ...[
                const SizedBox(height: 12),
                Text(
                  'Rychlý výběr bodovaných míst',
                  style: GoogleFonts.libreFranklin(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _placeTypes
                      .where(
                        (t) =>
                            t.name == PlaceType.PEAK.name ||
                            t.name == PlaceType.TOWER.name ||
                            t.name == PlaceType.TREE.name,
                      )
                      .map(
                        (t) => ChoiceChip(
                          selected: selectedTypeName == t.name,
                          label: Text(t.label),
                          avatar: Icon(t.icon, size: 14, color: t.color),
                          onSelected: (_) =>
                              setSheetState(() => selectedTypeName = t.name),
                        ),
                      )
                      .toList(),
                ),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      onPressed: () => Navigator.pop(context),
                      text: 'Zrušit',
                      type: AppButtonType.secondary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppButton(
                      onPressed: () {
                        if (nameController.text.trim().isEmpty) return;

                        final typeEnum = PlaceType.values.firstWhere(
                          (e) => e.name == selectedTypeName,
                          orElse: () => PlaceType.PEAK,
                        );

                        final newPlace = Place(
                          id: existingPlace?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                          name: nameController.text.trim(),
                          type: typeEnum,
                          photos: existingPlace?.photos ?? [],
                          createdAt: existingPlace?.createdAt ?? DateTime.now(),
                        );

                        List<Place> updatedList = List.from(formContext.places);
                        if (existingPlace != null) {
                          final idx = updatedList.indexWhere((p) => p.id == existingPlace.id);
                          if (idx != -1) updatedList[idx] = newPlace;
                        } else {
                          updatedList.add(newPlace);
                        }

                        formContext.updatePlaces(updatedList);
                        Navigator.pop(context);
                      },
                      text: existingPlace == null ? 'Přidat místo' : 'Uložit',
                      type: AppButtonType.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
      ),
    );
  }
}
