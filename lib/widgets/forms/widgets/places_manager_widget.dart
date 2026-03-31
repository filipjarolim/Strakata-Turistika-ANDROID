import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/forms/form_config.dart';
import '../../../models/forms/form_context.dart';
import '../../../models/visit_data.dart';
import '../../../models/place_type_config.dart';
import '../../../widgets/ui/app_button.dart';

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
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.field.label,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
              ),
              if (formContext.places.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${formContext.places.length}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
                  ),
                ),
            ],
          ),
        ),
        
        if (formContext.places.isEmpty)
           Container(
             width: double.infinity,
             padding: const EdgeInsets.all(24),
             decoration: BoxDecoration(
               color: const Color(0xFFF9FAFB),
               borderRadius: BorderRadius.circular(16),
               border: Border.all(color: const Color(0xFFE5E7EB), style: BorderStyle.solid),
             ),
             child: Column(
               children: [
                 const Icon(Icons.add_location_alt_outlined, color: Color(0xFF9CA3AF), size: 32),
                 const SizedBox(height: 8),
                 Text('Zatím žádná místa', style: TextStyle(color: Colors.grey[500])),
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
          ...formContext.places.map((place) => _buildPlaceItem(context, place, formContext)).toList(),
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF3F4F6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: config.color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(config.icon, color: config.color, size: 20),
        ),
        title: Text(place.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${config.label} • ${place.photos.length} fotek',
          style: TextStyle(color: Colors.grey[500], fontSize: 12),
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                existingPlace == null ? 'Přidat místo' : 'Upravit místo',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Název místa',
                  hintText: 'Např. Sněžka',
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_isLoadingTypes)
                const LinearProgressIndicator()
              else
                DropdownButtonFormField<String>(
                  value: selectedTypeName,
                  decoration: InputDecoration(
                    labelText: 'Typ místa',
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
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
              const SizedBox(height: 24),
              AppButton(
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
                    photos: existingPlace?.photos ?? [], // Preserve photos for now
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
                text: existingPlace == null ? 'Přidat místo' : 'Uložit změny',
                type: AppButtonType.primary,
                expand: true,
              )
            ],
          ),
        ),
      ),
    );
  }
}
