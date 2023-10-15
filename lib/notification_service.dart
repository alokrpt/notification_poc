import 'dart:math';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:test_3_13_5/main.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class NotificationService {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final AndroidNotificationChannelGroup channelGroup =
      const AndroidNotificationChannelGroup(
    'channel_id',
    'channel_name',
    description: 'for grouped notifications',
  );
  final groupKeyName = 'some_key';

  Future<void> initiliseNotificationServices() async {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp();
    await FirebaseMessaging.instance.setAutoInitEnabled(true);
    tz.initializeTimeZones();

    final fcmToken = await FirebaseMessaging.instance.getToken();
    debugPrint('fcmToken: $fcmToken');
    await notificationService.flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannelGroup(notificationService.channelGroup);

    NotificationSettings settings =
        await FirebaseMessaging.instance.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    debugPrint('User granted permission: ${settings.authorizationStatus}');
    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );

    await notificationService.flutterLocalNotificationsPlugin
        .initialize(initializationSettings);
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Got a message whilst in the foreground!');
      debugPrint('Message data: ${message.data}');

      if (message.notification != null) {
        notificationService.showNotification(
          message.notification!.title,
          message.notification!.body,
        );
        debugPrint(
            'Message also contained a notification: ${message.notification}');
      }
    });
  }

  Future<void> showNotification(
    String? title,
    String? body,
  ) async {
    var id = Random().nextInt(1000);
    await flutterLocalNotificationsPlugin
        .zonedSchedule(
          id,
          title,
          body,
          androidScheduleMode: AndroidScheduleMode.exact,
          tz.TZDateTime.now(tz.local).add(const Duration(seconds: 5)),
          NotificationDetails(
            android: AndroidNotificationDetails(
              channelGroup.id,
              channelGroup.name,
              channelDescription: channelGroup.description,
              importance: Importance.max,
              priority: Priority.max,
              groupKey: groupKeyName,
            ),
          ),
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          androidAllowWhileIdle: true,
        )
        .then(
          (value) => groupNotifications(),
        );
  }

  void groupNotifications() async {
    List<ActiveNotification> activeNotifications =
        (await flutterLocalNotificationsPlugin
                .resolvePlatformSpecificImplementation<
                    AndroidFlutterLocalNotificationsPlugin>()
                ?.getActiveNotifications()) ??
            [];

    activeNotifications
        .removeWhere((element) => element.groupKey != groupKeyName);

    if (activeNotifications.isNotEmpty) {
      List<String> lines =
          activeNotifications.map((e) => e.title.toString()).toList();
      InboxStyleInformation inboxStyleInformation = InboxStyleInformation(
        lines,
        contentTitle: "${activeNotifications.length} Updates",
        summaryText: "${activeNotifications.length} Updates",
      );
      AndroidNotificationDetails groupNotificationDetails =
          AndroidNotificationDetails(
        channelGroup.id,
        channelGroup.name,
        channelDescription: channelGroup.description,
        styleInformation: inboxStyleInformation,
        setAsGroupSummary: true,
        groupKey: groupKeyName,
        onlyAlertOnce: true,
      );
      NotificationDetails groupNotificationDetailsPlatformSpefics =
          NotificationDetails(android: groupNotificationDetails);
      await flutterLocalNotificationsPlugin.show(
        0,
        '_',
        '_',
        groupNotificationDetailsPlatformSpefics,
      );
    }
  }
}
