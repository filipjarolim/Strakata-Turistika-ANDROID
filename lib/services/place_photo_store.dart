import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Fotka z foťáku v aplikaci je jen dočasný soubor. Kopie v dokumentech
/// přežije zavření foťáku i další krok formuláře.
Future<File> persistPlacePhoto(File source) async {
  final root = await getApplicationDocumentsDirectory();
  final folder = Directory('${root.path}/place-photos');
  return copyPlacePhoto(source, folder);
}

Future<File> copyPlacePhoto(File source, Directory folder) async {
  if (!await folder.exists()) {
    await folder.create(recursive: true);
  }
  final stamp = DateTime.now().microsecondsSinceEpoch;
  final dest = File('${folder.path}/place-$stamp.jpg');
  return source.copy(dest.path);
}
