import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotiService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static bool _isInitialized = false;

  static bool get isInitialized => _isInitialized;

  static final StreamController<String?> selectNotificationStream =
      StreamController<String?>.broadcast();

  static Future<void> initNotification() async {
    if (_isInitialized) return;

    const initSettingsAndroid = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const initSettingsIOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: initSettingsAndroid,
      iOS: initSettingsIOS,
    );

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse notificationResponse) async {
        selectNotificationStream.add(notificationResponse.payload);
      },
    );
    _isInitialized = true;
  }

  static NotificationDetails _notificationDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        'daily_channel_id',
        'Daily Notifications',
        channelDescription: 'Daily notifications for the app',
        importance: Importance.max,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );
  }

  static Future<void> showDailyNotification({
    int id = 0,
    String? title,
    String? body,
    String? payload,
  }) async {
    if (!_isInitialized) {
      print("NotiService not initialized before showing notification");
      return;
    }
    await _notificationsPlugin.show(
      id,
      title,
      body,
      _notificationDetails(),
      payload: payload,
    );
  }

  static void dispose() {
    selectNotificationStream.close();
  }
}
