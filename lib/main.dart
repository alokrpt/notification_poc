import 'dart:math';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  tz.initializeTimeZones();

  showNotification(
    message.notification?.title,
    message.notification?.body,
  );
  debugPrint("Handling a background message: ${message.toString()}");
}

void main() {
  initiliseFirebase();
  runApp(const MyApp());
}

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();
const AndroidNotificationChannelGroup channelGroup =
    AndroidNotificationChannelGroup(
  'channel_id',
  'channel_name',
  description: 'for grouped notifications',
);
const groupKeyName = 'some_key';

Future<void> initiliseFirebase() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await FirebaseMessaging.instance.setAutoInitEnabled(true);
  tz.initializeTimeZones();

  final fcmToken = await FirebaseMessaging.instance.getToken();
  debugPrint('fcmToken: $fcmToken');
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannelGroup(channelGroup);

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
  const InitializationSettings initializationSettings = InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
  );

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    debugPrint('Got a message whilst in the foreground!');
    debugPrint('Message data: ${message.data}');

    if (message.notification != null) {
      showNotification(
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
      contentTitle: "${activeNotifications.length - 1} Updates",
      summaryText: "${activeNotifications.length - 1} Updates",
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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
            seedColor: const Color.fromARGB(255, 55, 53, 60)),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'You have pushed the button this many times:',
            ),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
