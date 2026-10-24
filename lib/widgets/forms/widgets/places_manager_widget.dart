import 'dart:async';
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
import '../../../models/place_type_config.dart';
import '../../../models/visit_data.dart';
import '../../../services/cloudinary_service.dart';
import '../../../services/nominatim_service.dart';
import '../../../utils/place_label.dart';
import '../../../widgets/maps/shared_map_widget.dart';
import '../../../widgets/photo_viewer.dart';
import '../../../widgets/ui/app_button.dart';
import '../form_design.dart';

/// Bodovaná místa — stejná data jako web (`Place`: name, type, photos, description, lat, lng).
/// Poloha jen z mapy / vyhledávání / GPS — bez ručního zadávání souřadnic.
class PlacesManagerWidget extends StatefulWidget {
  final FormFieldWidget field;

  const PlacesManagerWidget({Key? key, required this.field}) : super(key: key);

  @override
  State<PlacesManagerWidget> createState() => _PlacesManagerWidgetState();
}

class _PlacesManagerWidgetState extends State<PlacesManagerWidget> {
  List<PlaceTypeConfig> _placeTypes = [];
  bool _isLoadingTypes = true;

  static const Set<String> _quickChipTypeNames = {
    'PEAK',
    'rozhledny',
    'TOWER',
    'TREE',
    'CAVE',
    'RUINS',
    'UNUSUAL_NAME',
  };

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
    } catch (_) {
      if (mounted) setState(() => _isLoadingTypes = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final formContext = Provider.of<FormContext>(context);

    return FormSectionCard(
      title: widget.field.label,
      subtitle: 'Vyhledejte místo nebo klepněte do mapy a přidejte fotku.',
      icon: Icons.place_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (formContext.places.isEmpty)
            _EmptyPlacesCard(
              onAdd: () => _showPlaceDialog(context, formContext, null),
            )
          else ...[
            ...formContext.places.map(
              (place) => _buildPlaceItem(context, place, formContext),
            ),
            const SizedBox(height: 8),
            AppButton(
              onPressed: () => _showPlaceDialog(context, formContext, null),
              text: 'Přidat místo',
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

  Widget _buildPlaceItem(
    BuildContext context,
    Place place,
    FormContext formContext,
  ) {
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

    final hasCoords = place.lat != null && place.lng != null;
    final subtitleParts = <String>[
      config.label,
      if (config.points > 0) '+${config.points} b',
      if (place.photos.isNotEmpty) '${place.photos.length} foto',
      if (!hasCoords) 'bez polohy',
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8E4DC)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: config.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(config.icon, color: config.color, size: 20),
          ),
          title: Text(
            place.name.isEmpty ? 'Bez názvu' : friendlyPlaceTitle(place.name),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.libreFranklin(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          subtitle: Text(
            subtitleParts.join(' · '),
            style: GoogleFonts.libreFranklin(
              color: AppColors.textTertiary,
              fontSize: 12,
            ),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.grey),
            onPressed: () {
              final newPlaces = List<Place>.from(formContext.places)
                ..remove(place);
              formContext.updatePlaces(newPlaces);
            },
          ),
          onTap: () => _showPlaceDialog(context, formContext, place),
        ),
      ),
    );
  }

  Future<LatLng?> _resolveUserLocation() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 6),
      );
      return LatLng(pos.latitude, pos.longitude);
    } catch (_) {
      return null;
    }
  }

  void _showPlaceDialog(
    BuildContext context,
    FormContext formContext,
    Place? existingPlace,
  ) {
    final nameController = TextEditingController(text: existingPlace?.name ?? '');
    final descriptionController =
        TextEditingController(text: existingPlace?.description ?? '');
    final searchController = TextEditingController();

    String selectedTypeName = existingPlace?.type ??
        (_placeTypes.isNotEmpty ? _placeTypes.first.name : 'OTHER');
    if (_placeTypes.isNotEmpty &&
        !_placeTypes.any((t) => t.name == selectedTypeName)) {
      selectedTypeName = _placeTypes.first.name;
    }

    List<PlacePhoto> draftPhotos =
        List<PlacePhoto>.from(existingPlace?.photos ?? []);
    // Preserve proofType from existing web data without exposing confusing UI.
    final existingProofType = existingPlace?.proofType;

    bool uploadingPhoto = false;
    bool searchLoading = false;
    bool locating = false;
    bool reverseLoading = false;
    String? searchError;
    String? saveError;
    List<NominatimSearchHit> searchHits = [];

    double? pickLat = existingPlace?.lat;
    double? pickLng = existingPlace?.lng;
    LatLng mapCenter = (pickLat != null && pickLng != null)
        ? LatLng(pickLat, pickLng)
        : const LatLng(49.8175, 15.4730);
    double mapZoom = (pickLat != null && pickLng != null) ? 15.0 : 13.0;
    var didScheduleGpsBootstrap = false;
    var searchListenReady = false;
    Timer? searchTimer;

    showFormModalSheet(
      context: context,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          Future<void> centerOnUser({bool placeMarker = false}) async {
            setSheetState(() => locating = true);
            final loc = await _resolveUserLocation();
            if (!context.mounted) return;
            setSheetState(() {
              locating = false;
              if (loc != null) {
                mapCenter = loc;
                mapZoom = 15.5;
                if (placeMarker || (pickLat == null && pickLng == null)) {
                  pickLat = loc.latitude;
                  pickLng = loc.longitude;
                }
              }
            });
            if (loc == null && sheetContext.mounted) {
              ScaffoldMessenger.of(sheetContext).showSnackBar(
                const SnackBar(
                  content: Text('Nepodařilo se zjistit aktuální polohu.'),
                ),
              );
            }
          }

          if (!didScheduleGpsBootstrap && existingPlace?.lat == null) {
            didScheduleGpsBootstrap = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              centerOnUser(placeMarker: false);
            });
          }

          Future<void> runSearch() async {
            final q = searchController.text.trim();
            if (q.length < 2) {
              setSheetState(() {
                searchError = null;
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
                  searchError = 'Nic nenalezeno — zkuste mapu nebo GPS.';
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

          if (!searchListenReady) {
            searchListenReady = true;
            searchController.addListener(() {
              searchTimer?.cancel();
              searchTimer = Timer(const Duration(milliseconds: 280), () {
                if (!sheetContext.mounted) return;
                runSearch();
              });
            });
          }

          void applyHit(NominatimSearchHit h) {
            setSheetState(() {
              nameController.text = h.label;
              pickLat = h.lat;
              pickLng = h.lng;
              mapCenter = LatLng(h.lat, h.lng);
              mapZoom = 15.5;
              searchHits = [];
              searchError = null;
              saveError = null;
            });
          }

          Future<void> onMapTap(LatLng p) async {
            setSheetState(() {
              pickLat = p.latitude;
              pickLng = p.longitude;
              mapCenter = p;
              reverseLoading = true;
              saveError = null;
            });
            final label =
                await NominatimService.reverseGeocode(p.latitude, p.longitude);
            if (!context.mounted) return;
            setSheetState(() {
              reverseLoading = false;
              final current = nameController.text.trim();
              if (current.isEmpty || isHouseLikeLabel(current) || current.startsWith('Místo na mapě')) {
                nameController.text = label;
              }
            });
          }

          Future<void> useCurrentAsPlace() async {
            setSheetState(() => locating = true);
            final loc = await _resolveUserLocation();
            if (!context.mounted) return;
            if (loc == null) {
              setSheetState(() => locating = false);
              if (sheetContext.mounted) {
                ScaffoldMessenger.of(sheetContext).showSnackBar(
                  const SnackBar(
                    content: Text('Povolte přístup k poloze a zkuste znovu.'),
                  ),
                );
              }
              return;
            }
            setSheetState(() {
              locating = false;
              pickLat = loc.latitude;
              pickLng = loc.longitude;
              mapCenter = loc;
              mapZoom = 16;
              reverseLoading = true;
              saveError = null;
            });
            final label = await NominatimService.reverseGeocode(
              loc.latitude,
              loc.longitude,
            );
            if (!context.mounted) return;
            setSheetState(() {
              reverseLoading = false;
              final current = nameController.text.trim();
              if (current.isEmpty || isHouseLikeLabel(current) || current.startsWith('Místo na mapě')) {
                nameController.text = label;
              }
            });
          }

          Future<void> addPhoto() async {
            final source = await showModalBottomSheet<ImageSource>(
              context: sheetContext,
              builder: (ctx) => SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.photo_library_outlined),
                      title: const Text('Vybrat z galerie'),
                      onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                    ),
                    ListTile(
                      leading: const Icon(Icons.photo_camera_outlined),
                      title: const Text('Pořídit fotografii'),
                      onTap: () => Navigator.pop(ctx, ImageSource.camera),
                    ),
                  ],
                ),
              ),
            );
            if (source == null) return;
            setSheetState(() => uploadingPhoto = true);
            try {
              final x = await ImagePicker().pickImage(
                source: source,
                maxWidth: 2560,
                maxHeight: 2560,
                imageQuality: 90,
                requestFullMetadata: false,
              );
              if (x == null) return;
              final response =
                  await CloudinaryService.uploadImageResponse(File(x.path));
              if (response == null) {
                if (sheetContext.mounted) {
                  ScaffoldMessenger.of(sheetContext).showSnackBar(
                    const SnackBar(content: Text('Nahrání fotky se nepodařilo.')),
                  );
                }
                return;
              }
              final title = response.originalFilename.trim().isEmpty
                  ? 'foto_${draftPhotos.length + 1}'
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

          void save() {
            final name = nameController.text.trim();
            if (name.isEmpty) {
              setSheetState(() => saveError = 'Zadejte název místa.');
              return;
            }
            if (pickLat == null || pickLng == null) {
              setSheetState(
                () => saveError =
                    'Vyberte polohu na mapě, vyhledáním nebo aktuální polohou.',
              );
              return;
            }

            final newPlace = Place(
              id: existingPlace?.id ??
                  DateTime.now().millisecondsSinceEpoch.toString(),
              name: name,
              type: selectedTypeName,
              photos: draftPhotos,
              description: descriptionController.text.trim(),
              createdAt: existingPlace?.createdAt ?? DateTime.now(),
              lat: pickLat,
              lng: pickLng,
              proofType: existingProofType,
            );

            final updatedList = List<Place>.from(formContext.places);
            if (existingPlace != null) {
              final idx =
                  updatedList.indexWhere((p) => p.id == existingPlace.id);
              if (idx != -1) {
                updatedList[idx] = newPlace;
              } else {
                updatedList.add(newPlace);
              }
            } else {
              updatedList.add(newPlace);
            }
            formContext.updatePlaces(updatedList);
            Navigator.pop(context);
          }

          final hasPick = pickLat != null && pickLng != null;

          return LayoutBuilder(
            builder: (ctx, constraints) {
              final maxH = MediaQuery.of(ctx).size.height * 0.92;
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
                        style: GoogleFonts.libreFranklin(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // --- Name ---
                      TextField(
                        controller: nameController,
                        textInputAction: TextInputAction.next,
                        decoration: FormDesign.inputDecoration(
                          label: 'Název',
                          hint: 'Doplní se z mapy nebo vyhledávání',
                        ),
                      ),
                      const SizedBox(height: 12),

                      // --- Type chips (primary UI; matches place_type_configs) ---
                      Text(
                        'Typ',
                        style: GoogleFonts.libreFranklin(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_isLoadingTypes)
                        const LinearProgressIndicator()
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ..._placeTypes
                                .where(
                                  (t) => _quickChipTypeNames.contains(t.name),
                                )
                                .map(
                                  (t) => ChoiceChip(
                                    selected: selectedTypeName == t.name,
                                    label: Text(
                                      t.points > 0
                                          ? '${t.label} (+${t.points})'
                                          : t.label,
                                    ),
                                    avatar: Icon(
                                      t.icon,
                                      size: 14,
                                      color: t.color,
                                    ),
                                    onSelected: (_) => setSheetState(
                                      () => selectedTypeName = t.name,
                                    ),
                                  ),
                                ),
                            ..._placeTypes
                                .where(
                                  (t) => !_quickChipTypeNames.contains(t.name),
                                )
                                .map(
                                  (t) => ChoiceChip(
                                    selected: selectedTypeName == t.name,
                                    label: Text(
                                      t.points > 0
                                          ? '${t.label} (+${t.points})'
                                          : t.label,
                                    ),
                                    avatar: Icon(
                                      t.icon,
                                      size: 14,
                                      color: t.color,
                                    ),
                                    onSelected: (_) => setSheetState(
                                      () => selectedTypeName = t.name,
                                    ),
                                  ),
                                ),
                          ],
                        ),
                      const SizedBox(height: 16),

                      // --- Search ---
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: searchController,
                              textInputAction: TextInputAction.search,
                              decoration: FormDesign.inputDecoration(
                                label: 'Vyhledat',
                                hint: 'Název nebo adresa',
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
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
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
                            style: GoogleFonts.libreFranklin(
                              fontSize: 12,
                              color: Colors.red.shade700,
                            ),
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
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.place_outlined, size: 18),
                                title: Text(
                                  h.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.libreFranklin(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                subtitle: h.detail.isEmpty
                                    ? null
                                    : Text(
                                        h.detail,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.libreFranklin(fontSize: 12),
                                      ),
                                onTap: () => applyHit(h),
                              );
                            },
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),

                      // --- Map (always visible) ---
                      Row(
                        children: [
                          Text(
                            'Poloha na mapě',
                            style: GoogleFonts.libreFranklin(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: locating ? null : useCurrentAsPlace,
                            icon: locating
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.my_location, size: 16),
                            label: const Text('Moje poloha'),
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 240,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Stack(
                            children: [
                              SharedMapWidget(
                                center: mapCenter,
                                zoom: mapZoom,
                                onTap: onMapTap,
                                markers: [
                                  if (hasPick)
                                    Marker(
                                      width: 40,
                                      height: 40,
                                      point: LatLng(pickLat!, pickLng!),
                                      child: const Icon(
                                        Icons.place,
                                        color: Color(0xFFDC2626),
                                        size: 40,
                                      ),
                                    ),
                                ],
                              ),
                              Positioned(
                                left: 10,
                                right: 72,
                                bottom: 10,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.94),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 7,
                                    ),
                                    child: Text(
                                      reverseLoading
                                          ? 'Hledám název…'
                                          : hasPick
                                              ? (nameController.text.trim().isEmpty
                                                  ? 'Poloha vybraná'
                                                  : friendlyPlaceTitle(nameController.text))
                                              : 'Klepněte do mapy',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.libreFranklin(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: hasPick
                                            ? const Color(0xFF166534)
                                            : AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // --- Photos as proof (replaces confusing "typ důkazu") ---
                      Row(
                        children: [
                          Text(
                            'Fotky',
                            style: GoogleFonts.libreFranklin(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: uploadingPhoto ? null : addPhoto,
                            icon: uploadingPhoto
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    Icons.add_a_photo_outlined,
                                    size: 18,
                                  ),
                            label: Text(
                              uploadingPhoto ? 'Nahrávám…' : 'Přidat foto',
                            ),
                          ),
                        ],
                      ),
                      if (draftPhotos.isEmpty)
                        GestureDetector(
                          onTap: uploadingPhoto ? null : addPhoto,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8F4EE),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFE8E4DC)),
                            ),
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.add_photo_alternate_outlined,
                                  color: Color(0xFF9CA3AF),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Přidejte fotku jako důkaz návštěvy',
                                  style: GoogleFonts.libreFranklin(
                                    fontSize: 12,
                                    color: AppColors.textTertiary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        SizedBox(
                          height: 92,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: draftPhotos.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 8),
                            itemBuilder: (_, i) {
                              final ph = draftPhotos[i];
                              return SizedBox(
                                width: 92,
                                height: 92,
                                child: PhotoThumb(
                                  url: ph.url,
                                  onTap: () => showPhotoViewer(
                                    sheetContext,
                                    images: draftPhotos
                                        .map((p) => photoProviderFromUrl(p.url))
                                        .toList(),
                                    initialIndex: i,
                                  ),
                                  onRemove: () => setSheetState(
                                    () => draftPhotos = draftPhotos
                                        .where((e) => e.id != ph.id)
                                        .toList(),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      const SizedBox(height: 12),

                      // --- Optional description ---
                      TextField(
                        controller: descriptionController,
                        minLines: 1,
                        maxLines: 3,
                        decoration: FormDesign.inputDecoration(
                          label: 'Poznámka (volitelné)',
                        ),
                      ),

                      if (saveError != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          saveError!,
                          style: GoogleFonts.libreFranklin(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.red.shade700,
                          ),
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
                              onPressed: save,
                              text: existingPlace == null ? 'Přidat' : 'Uložit',
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

class _EmptyPlacesCard extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyPlacesCard({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8E4DC)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.add_location_alt_outlined,
            color: Color(0xFF9CA3AF),
            size: 32,
          ),
          const SizedBox(height: 8),
          Text(
            'Zatím žádná místa',
            style: GoogleFonts.libreFranklin(color: AppColors.textTertiary),
          ),
          const SizedBox(height: 12),
          AppButton(
            onPressed: onAdd,
            text: 'Přidat místo',
            type: AppButtonType.secondary,
            size: AppButtonSize.small,
            icon: Icons.add,
          ),
        ],
      ),
    );
  }
}
