class NominatimAddress {
  final String? peak;
  final String? tourism;
  final String? historic;
  final String? natural;
  final String? amenity;
  final String? leisure;
  final String? hamlet;
  final String? village;
  final String? suburb;
  final String? town;
  final String? city;
  final String? municipality;
  final String? cityDistrict;
  final String? road;
  final String? pedestrian;

  const NominatimAddress({
    this.peak,
    this.tourism,
    this.historic,
    this.natural,
    this.amenity,
    this.leisure,
    this.hamlet,
    this.village,
    this.suburb,
    this.town,
    this.city,
    this.municipality,
    this.cityDistrict,
    this.road,
    this.pedestrian,
  });

  factory NominatimAddress.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const NominatimAddress();
    String? read(String key) {
      final value = map[key];
      if (value is! String) return null;
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    return NominatimAddress(
      peak: read('peak'),
      tourism: read('tourism'),
      historic: read('historic'),
      natural: read('natural'),
      amenity: read('amenity'),
      leisure: read('leisure'),
      hamlet: read('hamlet'),
      village: read('village'),
      suburb: read('suburb'),
      town: read('town'),
      city: read('city'),
      municipality: read('municipality'),
      cityDistrict: read('city_district'),
      road: read('road'),
      pedestrian: read('pedestrian'),
    );
  }
}

bool isHouseLikeLabel(String value) {
  final text = value.trim().toLowerCase();
  if (text.isEmpty) return true;
  if (RegExp(r'^\d+[a-z]?$', caseSensitive: false).hasMatch(text)) return true;
  return RegExp(
    r'^(ev|č\.?\s*ev|čp|č\.?\s*p|e\.?\s*č)\.?\s*\d+[a-z]?$',
    caseSensitive: false,
  ).hasMatch(text);
}

String _locality(NominatimAddress? address) {
  if (address == null) return '';
  return address.hamlet ??
      address.village ??
      address.suburb ??
      address.town ??
      address.city ??
      address.municipality ??
      address.cityDistrict ??
      '';
}

bool _isAdminPart(String value) {
  return RegExp(
    r'^(okres\b|kraj$|česko|cesko|czechia|czech republic|česká republika)',
    caseSensitive: false,
  ).hasMatch(value.trim());
}

String humanPlaceName({
  String? name,
  String? displayName,
  NominatimAddress? address,
}) {
  final named = name?.trim() ?? '';
  if (named.isNotEmpty && !isHouseLikeLabel(named)) return named;

  final feature = [
    address?.peak,
    address?.tourism,
    address?.historic,
    address?.natural,
    address?.amenity,
    address?.leisure,
  ].map((value) => value?.trim() ?? '').firstWhere(
        (value) => value.isNotEmpty && !isHouseLikeLabel(value),
        orElse: () => '',
      );
  final locality = _locality(address);
  final road = (address?.road ?? address?.pedestrian ?? '').trim();

  if (feature.isNotEmpty &&
      locality.isNotEmpty &&
      feature.toLowerCase() != locality.toLowerCase()) {
    return '$feature, $locality';
  }
  if (feature.isNotEmpty) return feature;
  if (road.isNotEmpty && locality.isNotEmpty && !isHouseLikeLabel(road)) {
    return '$road, $locality';
  }
  if (locality.isNotEmpty) return locality;

  final parts = (displayName ?? '')
      .split(',')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty && !isHouseLikeLabel(part) && !_isAdminPart(part));
  return parts.isEmpty ? 'Místo na mapě' : parts.first;
}

String humanPlaceDetail({
  String? name,
  String? displayName,
  NominatimAddress? address,
}) {
  final title = humanPlaceName(name: name, displayName: displayName, address: address);
  final locality = _locality(address);
  if (locality.isNotEmpty &&
      locality.toLowerCase() != title.toLowerCase() &&
      !title.contains(locality)) {
    return locality;
  }
  final rest = (displayName ?? '')
      .split(',')
      .map((part) => part.trim())
      .where(
        (part) =>
            part.isNotEmpty &&
            part != title &&
            !isHouseLikeLabel(part) &&
            !_isAdminPart(part),
      );
  return rest.isEmpty ? '' : rest.first;
}

String friendlyPlaceTitle(String stored) {
  final title = humanPlaceName(displayName: stored);
  if (title == 'Místo na mapě' && stored.trim().isNotEmpty) {
    return stored.trim().split(',').first.trim();
  }
  return title;
}
