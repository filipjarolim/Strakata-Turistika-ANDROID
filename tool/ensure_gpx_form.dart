import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mongo_dart/mongo_dart.dart';

Future<void> main() async {
  await dotenv.load(fileName: '.env');
  final rawUrl = dotenv.env['DATABASE_URL'];
  if (rawUrl == null || rawUrl.isEmpty) {
    throw Exception('DATABASE_URL is missing in .env');
  }

  var url = rawUrl;
  if (!url.contains('tls=')) {
    url += (url.contains('?') ? '&' : '?') + 'tls=true';
  }
  if (!url.contains('authSource=')) {
    url += '&authSource=admin';
  }

  final db = await Db.create(url);
  await db.open(secure: true);

  try {
    final forms = db.collection('forms');
    final existing = await forms.find({}, {'slug': 1, 'name': 1}).toList();
    final existingSlugs = existing
        .map((doc) => doc['slug']?.toString() ?? '')
        .where((slug) => slug.isNotEmpty)
        .toSet();

    if (existingSlugs.contains('gpx-upload')) {
      print('gpx-upload already exists, no change needed.');
      return;
    }

    final source = await forms.findOne({'slug': 'gps-tracking'});
    if (source == null) {
      throw Exception('Source form "gps-tracking" was not found in DB.');
    }

    final newDoc = Map<String, dynamic>.from(source)
      ..remove('_id')
      ..['slug'] = 'gpx-upload'
      ..['name'] = 'Nahrání GPX souboru'
      ..['updatedAt'] = DateTime.now().toIso8601String();

    final definition = newDoc['definition'];
    if (definition is Map<String, dynamic>) {
      newDoc['definition'] = {
        ...definition,
        'name': 'Nahrání GPX souboru',
      };
    }

    await forms.insertOne(newDoc);
    print('Inserted missing form: gpx-upload');
  } finally {
    await db.close();
  }
}
