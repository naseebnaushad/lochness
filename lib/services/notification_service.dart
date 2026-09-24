import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Thin wrapper around flutter_local_notifications used for arrival/
/// departure alerts and "your location is being shared" foreground notices.
class NotificationService {
  NotificationService() : _plugin = FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  Future<void> init() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );
  }

  Future<void> showGeofenceNotification({
    required String personName,
    required String placeName,
    required bool isArrival,
  }) {
    final title = isArrival ? 'Arrived' : 'Left';
    return _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      '$personName $title $placeName',
      isArrival ? '$personName just got to $placeName' : '$personName just left $placeName',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'geofence_events',
          'Arrivals & departures',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  Future<void> showSharingActiveNotification({required String circleName}) {
    return _plugin.show(
      0,
      'Sharing your location',
      'Your location is visible to $circleName',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'active_sharing',
          'Active location sharing',
          importance: Importance.low,
          priority: Priority.low,
          ongoing: true,
        ),
        iOS: DarwinNotificationDetails(presentBanner: false),
      ),
    );
  }

  Future<void> cancelSharingActiveNotification() => _plugin.cancel(0);
}
