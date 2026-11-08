import 'package:flutter_test/flutter_test.dart';
import 'package:strakataturistikaandroidapp/services/local_notification_guard.dart';

void main() {
  test('schování notifikace spolkne pád pluginu', () async {
    var called = false;
    await cancelLocalNotification((id) async {
      called = true;
      expect(id, 2001);
      throw Exception('Missing type parameter.');
    }, 2001);
    expect(called, isTrue);
  });

  test('schování notifikace projde, když plugin notifikaci smaže', () async {
    final seen = <int>[];
    await cancelLocalNotification((id) async {
      seen.add(id);
    }, 7);
    expect(seen, [7]);
  });
}
