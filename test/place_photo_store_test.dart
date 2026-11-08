import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:strakataturistikaandroidapp/services/place_photo_store.dart';

void main() {
  test('kopie fotky zůstane ve složce míst, ne v dočasném souboru foťáku', () async {
    final root = await Directory.systemTemp.createTemp('place-photos');
    final sourceDir = Directory('${root.path}/cache');
    await sourceDir.create();
    final source = File('${sourceDir.path}/camera.jpg');
    await source.writeAsBytes([1, 2, 3, 4]);
    final folder = Directory('${root.path}/docs');

    final stored = await copyPlacePhoto(source, folder);
    await source.delete();

    expect(stored.path.startsWith(folder.path), isTrue);
    expect(await stored.exists(), isTrue);
    expect(await stored.readAsBytes(), [1, 2, 3, 4]);
    await root.delete(recursive: true);
  });
}
