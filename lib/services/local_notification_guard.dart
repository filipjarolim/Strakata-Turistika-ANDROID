/// `FlutterLocalNotificationsPlugin.cancel` na Androidu načte naplánované
/// notifikace. R8 u toho zahodí generický typ GSON a plugin spadne s
/// „Missing type parameter“. Schování notifikace nesmí shodit sledování.
Future<void> cancelLocalNotification(
  Future<void> Function(int id) cancel,
  int id,
) async {
  try {
    await cancel(id);
  } catch (_) {}
}
