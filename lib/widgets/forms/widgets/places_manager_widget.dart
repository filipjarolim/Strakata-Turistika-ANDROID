import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../config/app_colors.dart';
import '../../../models/forms/form_config.dart';
import '../../../models/forms/form_context.dart';
import '../../../models/visit_data.dart';
import '../../../models/place_type_config.dart';
import '../../../services/cloudinary_service.dart';
import '../../../services/nominatim_service.dart';
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

  static const Set<String> _quickChipTypeNames = {'PEAK', 'TOWER', 'TREE'};

  String _dropdownValueForTypes(List<PlaceTypeConfig> types, String current) {
    if (types.any((t) => t.name == current)) return current;
    return types.isNotEmpty ? types.first.name : current;
  }

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
      subtitle:
          'Jako na webu: vyhledání (Nominatim), výběr klikem do mapy OpenStreetMap, typ z databáze, fotky u místa.',
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
              'Místo vyhledejte níže nebo klikněte do mapy — při kliknutí doplníme souřadnice a název (reverse geocode).',
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
      (c) => c.name == place.type,
      orElse: () => PlaceTypeConfig(
        id: 'unknown',
        name: place.type,
        label: place.type,
        icon: Icons.place,
        points: 0,
        color: Colors.grey,
        order: 99,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    final coordHint = (place.lat != null && place.lng != null)
        ? ' • ${place.lat!.toStringAsFixed(5)}, ${place.lng!.toStringAsFixed(5)}'
        : '';

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
          place.name.isEmpty ? 'Bez názvu' : place.name,
          style: GoogleFonts.libreFranklin(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: Text(
          '${config.label} • ${place.photos.length} fotek$coordHint',
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

  Future<void> _fillGpsIntoControllers(
    BuildContext sheetContext,
    TextEditingController latC,
    TextEditingController lngC,
    void Function(void Function()) setSheetState,
  ) async {
    final perm = await Geolocator.checkPermission();
    LocationPermission p = perm;
    if (p == LocationPermission.denied) {
      p = await Geolocator.requestPermission();
    }
    if (p == LocationPermission.deniedForever || p == LocationPermission.denied) {
      if (sheetContext.mounted) {
        ScaffoldMessenger.of(sheetContext).showSnackBar(
          const SnackBar(content: Text('K doplnění souřadnic je potřeba povolení polohy.')),
        );
      }
      return;
    }
    final pos = await Geolocator.getCurrentPosition();
    setSheetState(() {
      latC.text = pos.latitude.toStringAsFixed(6);
      lngC.text = pos.longitude.toStringAsFixed(6);
    });
  }

  void _showPlaceDialog(BuildContext context, FormContext formContext, Place? existingPlace) {
    final nameController = TextEditingController(text: existingPlace?.name ?? '');
    final descriptionController = TextEditingController(text: existingPlace?.description ?? '');
    final latController = TextEditingController(
      text: existingPlace?.lat != null ? existingPlace!.lat!.toString() : '',
    );
    final lngController = TextEditingController(
      text: existingPlace?.lng != null ? existingPlace!.lng!.toString() : '',
    );
    final proofController = TextEditingController(text: existingPlace?.proofType ?? '');
    final searchController = TextEditingController();
    String selectedTypeName =
        existingPlace?.type ?? (_placeTypes.isNotEmpty ? _placeTypes.first.name : 'OTHER');
    if (_placeTypes.isNotEmpty && !_placeTypes.any((t) => t.name == selectedTypeName)) {
      selectedTypeName = _placeTypes.first.name;
    }
    List<PlacePhoto> draftPhotos = List<PlacePhoto>.from(existingPlace?.photos ?? []);
    bool uploadingPhoto = false;
    bool mapExpanded = false;
    bool searchLoading = false;
    String? searchError;
    List<NominatimSearchHit> searchHits = [];
    bool reverseLoading = false;
    double? mapPickLat;
    double? mapPickLng;

    showFormModalSheet(
      context: context,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          LatLng mapCenter() {
            final la = double.tryParse(latController.text.replaceAll(',', '.'));
            final ln = double.tryParse(lngController.text.replaceAll(',', '.'));
            if (la != null && ln != null && la.isFinite && ln.isFinite) {
              return LatLng(la, ln);
            }
            if (mapPickLat != null && mapPickLng != null) {
              return LatLng(mapPickLat!, mapPickLng!);
            }
            return const LatLng(49.8175, 15.4730);
          }

          Future<void> runSearch() async {
            final q = searchController.text.trim();
            if (q.length < 2) {
              setSheetState(() {
                searchError = 'Napište alespoň 2 znaky.';
                searchHits = [];
              });
              return;
            }
            setSheetState(() {
              searchLoading = true;
              searchError = null;
            });
            try {
              final hits = await NominatimService.search(q);
              setSheetState(() {
                searchHits = hits;
                if (hits.isEmpty) {
                  searchError = 'Místo se nepodařilo najít. Zkuste jiný název nebo klikněte do mapy.';
                }
              });
            } catch (_) {
              setSheetState(() {
                searchHits = [];
                searchError = 'Vyhledávání se nepodařilo.';
              });
            } finally {
              setSheetState(() => searchLoading = false);
            }
          }

          void applyHit(NominatimSearchHit h) {
            setSheetState(() {
              nameController.text = h.displayName;
              latController.text = h.lat.toStringAsFixed(6);
              lngController.text = h.lng.toStringAsFixed(6);
              mapPickLat = h.lat;
              mapPickLng = h.lng;
              searchHits = [];
              searchError = null;
            });
          }

          Future<void> onMapTap(LatLng p) async {
            setSheetState(() {
              mapPickLat = p.latitude;
              mapPickLng = p.longitude;
              latController.text = p.latitude.toStringAsFixed(6);
              lngController.text = p.longitude.toStringAsFixed(6);
              reverseLoading = true;
            });
            final label = await NominatimService.reverseGeocode(p.latitude, p.longitude);
            if (!context.mounted) return;
            setSheetState(() {
              reverseLoading = false;
              if (nameController.text.trim().isEmpty) {
                nameController.text = label;
              }
              searchController.text = label;
            });
          }

          Future<void> addPhoto() async {
            setSheetState(() => uploadingPhoto = true);
            try {
              final x = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 88);
              if (x == null) return;
              final file = File(x.path);
              final response = await CloudinaryService.uploadImageResponse(file);
              if (response == null) {
                if (sheetContext.mounted) {
                  ScaffoldMessenger.of(sheetContext).showSnackBar(
                    const SnackBar(content: Text('Nahrání fotky se nepodařilo.')),
                  );
                }
                return;
              }
              final title = response.originalFilename.trim().isEmpty
                  ? 'místo_${draftPhotos.length + 1}'
                  : response.originalFilename.trim();
              setSheetState(() {
                draftPhotos = [
                  ...draftPhotos,
                  PlacePhoto(
                    id: DateTime.now().microsecondsSinceEpoch.toString(),
                    url: response.secureUrl,
                    description: '',
                    uploadedAt: DateTime.now(),
                    title: title,
                    publicId: response.publicId,
                  ),
                ];
              });
            } finally {
              if (context.mounted) setSheetState(() => uploadingPhoto = false);
            }
          }

          void removePhoto(PlacePhoto ph) {
            setSheetState(() => draftPhotos = draftPhotos.where((e) => e.id != ph.id).toList());
          }

          double? parseCoord(TextEditingController c) {
            final t = c.text.trim();
            if (t.isEmpty) return null;
            return double.tryParse(t.replaceAll(',', '.'));
          }

          return LayoutBuilder(
            builder: (ctx, constraints) {
              final maxH = MediaQuery.of(ctx).size.height * 0.9;
              return ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxH),
                child: SingleChildScrollView(
                  child: Column(
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
                        decoration: FormDesign.inputDecoration(label: 'Název místa', hint: 'Např. z mapy nebo vyhledávání'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: descriptionController,
                        minLines: 2,
                        maxLines: 4,
                        decoration: FormDesign.inputDecoration(
                          label: 'Popis',
                          hint: 'Volitelný popis místa',
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_isLoadingTypes)
                        const LinearProgressIndicator()
                      else
                        DropdownButtonFormField<String>(
                          value: _dropdownValueForTypes(_placeTypes, selectedTypeName),
                          decoration: FormDesign.inputDecoration(label: 'Typ místa'),
                          items: _placeTypes
                              .map(
                                (t) => DropdownMenuItem(
                                  value: t.name,
                                  child: Row(
                                    children: [
                                      Icon(t.icon, size: 16, color: t.color),
                                      const SizedBox(width: 12),
                                      Text(t.label),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setSheetState(() => selectedTypeName = val);
                            }
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
                              .where((t) => _quickChipTypeNames.contains(t.name))
                              .map(
                                (t) => ChoiceChip(
                                  selected: selectedTypeName == t.name,
                                  label: Text(t.label),
                                  avatar: Icon(t.icon, size: 14, color: t.color),
                                  onSelected: (_) => setSheetState(() => selectedTypeName = t.name),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Text(
                        'Vyhledat polohu',
                        style: GoogleFonts.libreFranklin(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: searchController,
                              decoration: FormDesign.inputDecoration(
                                label: 'Nominatim (OpenStreetMap)',
                                hint: 'Adresa nebo název místa',
                              ),
                              onSubmitted: (_) => runSearch(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filledTonal(
                            onPressed: searchLoading ? null : runSearch,
                            icon: searchLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.search),
                          ),
                        ],
                      ),
                      if (searchError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            searchError!,
                            style: GoogleFonts.libreFranklin(fontSize: 12, color: Colors.red.shade700),
                          ),
                        ),
                      if (searchHits.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 140),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: searchHits.length,
                            itemBuilder: (_, i) {
                              final h = searchHits[i];
                              return ListTile(
                                dense: true,
                                title: Text(
                                  h.displayName,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.libreFranklin(fontSize: 13),
                                ),
                                onTap: () => applyHit(h),
                              );
                            },
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => setSheetState(() => mapExpanded = !mapExpanded),
                        icon: Icon(mapExpanded ? Icons.map_outlined : Icons.map_rounded),
                        label: Text(mapExpanded ? 'Skrýt mapu' : 'Vybrat na mapě'),
                      ),
                      if (mapExpanded) ...[
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 260,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Stack(
                              children: [
                                FlutterMap(
                                  options: MapOptions(
                                    initialCenter: mapCenter(),
                                    initialZoom: 14,
                                    onTap: (_, p) => onMapTap(p),
                                  ),
                                  children: [
                                    TileLayer(
                                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                      userAgentPackageName:
                                          'cz.strakata.turistika.strakataturistikaandroidapp',
                                    ),
                                    if (mapPickLat != null && mapPickLng != null)
                                      MarkerLayer(
                                        markers: [
                                          Marker(
                                            width: 36,
                                            height: 36,
                                            point: LatLng(mapPickLat!, mapPickLng!),
                                            child: const Icon(
                                              Icons.place,
                                              color: Color(0xFFDC2626),
                                              size: 36,
                                            ),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                                if (reverseLoading)
                                  Positioned.fill(
                                    child: Container(
                                      color: Colors.white.withValues(alpha: 0.55),
                                      child: const Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        if (reverseLoading)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              'Načítám název místa…',
                              style: GoogleFonts.libreFranklin(fontSize: 11, color: AppColors.textTertiary),
                            ),
                          ),
                      ],
                      const SizedBox(height: 14),
                      Text(
                        'Souřadnice (lze upravit ručně)',
                        style: GoogleFonts.libreFranklin(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: latController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                              decoration: FormDesign.inputDecoration(label: 'Zeměpisná šířka (lat)'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: lngController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                              decoration: FormDesign.inputDecoration(label: 'Zeměpisná délka (lng)'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: uploadingPhoto
                              ? null
                              : () => _fillGpsIntoControllers(sheetContext, latController, lngController, setSheetState),
                          icon: const Icon(Icons.my_location, size: 18),
                          label: const Text('Použít aktuální polohu'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: proofController,
                        decoration: FormDesign.inputDecoration(
                          label: 'Typ důkazu (volitelné)',
                          hint: 'Např. foto_rozhledna',
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Text(
                            'Fotky u místa',
                            style: GoogleFonts.libreFranklin(fontWeight: FontWeight.w800, fontSize: 14),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: uploadingPhoto ? null : addPhoto,
                            icon: uploadingPhoto
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.add_photo_alternate_outlined, size: 18),
                            label: Text(uploadingPhoto ? 'Nahrávám…' : 'Přidat'),
                          ),
                        ],
                      ),
                      if (draftPhotos.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            'Zatím žádné fotky u tohoto místa.',
                            style: GoogleFonts.libreFranklin(fontSize: 12, color: AppColors.textTertiary),
                          ),
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: draftPhotos.map((ph) {
                            return InputChip(
                              label: Text(
                                (ph.title ?? 'foto').length > 18
                                    ? '${(ph.title ?? 'foto').substring(0, 18)}…'
                                    : (ph.title ?? 'foto'),
                                style: GoogleFonts.libreFranklin(fontSize: 12),
                              ),
                              onDeleted: () => removePhoto(ph),
                            );
                          }).toList(),
                        ),
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

                                final lat = parseCoord(latController);
                                final lng = parseCoord(lngController);
                                final proof = proofController.text.trim();

                                final newPlace = Place(
                                  id: existingPlace?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                                  name: nameController.text.trim(),
                                  type: selectedTypeName,
                                  photos: draftPhotos,
                                  description: descriptionController.text.trim(),
                                  createdAt: existingPlace?.createdAt ?? DateTime.now(),
                                  lat: lat,
                                  lng: lng,
                                  proofType: proof.isEmpty ? null : proof,
                                );

                                final updatedList = List<Place>.from(formContext.places);
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
            },
          );
        },
      ),
    );
  }
}
