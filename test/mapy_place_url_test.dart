import 'package:flutter_test/flutter_test.dart';
import 'package:strakataturistikaandroidapp/utils/mapy_place_url.dart';

void main() {
  test('místo se otevírá na turistické mapě', () {
    final url = mapyPlaceUrl(lat: 49.937, lng: 14.186, name: 'Karlštejn');
    expect(url.startsWith('https://mapy.com/cs/turisticka?'), isTrue);
    expect(url, contains('y=49.937'));
    expect(url, contains('x=14.186'));
    expect(url, isNot(contains('zakladni')));
  });

  test('bez souřadnic hledá název na turistické mapě', () {
    expect(
      mapyPlaceUrl(name: 'Karlštejn'),
      'https://mapy.com/cs/turisticka?q=Karl%C5%A1tejn',
    );
  });
}
