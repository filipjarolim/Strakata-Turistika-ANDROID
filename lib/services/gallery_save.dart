import 'package:flutter/foundation.dart';
import 'package:gal/gal.dart';

/// Kopie snímku pořízeného foťákem v aplikaci do systémové galerie telefonu.
/// Výběr z galerie se neukládá znovu. Selhání nesmí shodit odeslání výletu.
Future<void> saveCameraPhotoToGallery(String path) async {
  if (path.isEmpty) return;
  try {
    if (!await Gal.hasPermission()) {
      await Gal.requestPermission();
    }
    await Gal.putImage(path);
  } catch (e) {
    debugPrint('Uložení fotky do galerie selhalo: $e');
  }
}
