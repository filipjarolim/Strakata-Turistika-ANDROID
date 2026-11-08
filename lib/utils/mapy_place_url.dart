/// Odkaz na turistickou mapu Mapy.com. Základní mapa turistické značky neukáže.
String mapyPlaceUrl({double? lat, double? lng, String? name}) {
  if (lat != null && lng != null && lat.isFinite && lng.isFinite) {
    return 'https://mapy.com/cs/turisticka?x=${Uri.encodeComponent(lng.toString())}&y=${Uri.encodeComponent(lat.toString())}&z=16&source=coor';
  }
  final query = (name ?? '').trim();
  return 'https://mapy.com/cs/turisticka?q=${Uri.encodeComponent(query.isEmpty ? 'Místo' : query)}';
}
