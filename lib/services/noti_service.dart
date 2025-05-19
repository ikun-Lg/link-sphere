import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

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

  static NotificationDetails _notificationDetails({
    String? imageUrl,
    bool isAdvertisement = false,
  }) {
    if (isAdvertisement && imageUrl != null) {
      return NotificationDetails(
        android: AndroidNotificationDetails(
          'advertisement_channel',
          '广告通知',
          channelDescription: '用于显示广告通知',
          importance: Importance.max,
          priority: Priority.high,
          styleInformation: BigPictureStyleInformation(
            ByteArrayAndroidBitmap.fromBase64String(imageUrl),
            hideExpandedLargeIcon: false,
            contentTitle: '广告通知',
            summaryText: '点击查看详情',
          ),
        ),
        iOS: DarwinNotificationDetails(
          attachments: [
            DarwinNotificationAttachment(imageUrl),
          ],
        ),
      );
    }

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
    String? imageUrl,
    bool isAdvertisement = false,
  }) async {
    if (!_isInitialized) {
      print("NotiService not initialized before showing notification");
      return;
    }

    // 如果是广告通知且有图片，需要先下载图片
    if (isAdvertisement && imageUrl != null) {
      try {
        final response = await http.get(Uri.parse(imageUrl));
        if (response.statusCode == 200) {
          final base64Image = base64Encode(response.bodyBytes);
          await _notificationsPlugin.show(
            id,
            title,
            body,
            _notificationDetails(
              imageUrl: base64Image,
              isAdvertisement: true,
            ),
            payload: payload,
          );
          return;
        }
      } catch (e) {
        print('下载广告图片失败: $e');
      }
    }

    // 如果下载图片失败或不是广告通知，使用普通通知
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
