import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}
  debugPrint('>>> FCM Background Message: ${message.messageId}');
}

class PushNotificationService {
  static final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'goblin_park_high_channel',
    'Goblin Park Alertas y Notificaciones',
    description: 'Canal prioritario de alertas, proyectos y reportes de Goblin Park.',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  static Future<void> initialize({Function(String?)? onNotificationTap}) async {
    // 1. Configuración de flutter_local_notifications
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    await _localNotificationsPlugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (onNotificationTap != null) {
          onNotificationTap(response.payload);
        }
      },
    );

    // 2. Crear canal de alta importancia en Android
    final androidPlugin = _localNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(_channel);
      await androidPlugin.requestNotificationsPermission();
    }

    // 3. Inicializar Firebase Messaging de forma segura
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // Suscribir al canal temático del parque
      try {
        await messaging.subscribeToTopic('goblin_park_general');
      } catch (_) {}

      // Escuchar mensajes en primer plano y mostrarlos con alta prioridad
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        final notification = message.notification;
        if (notification != null) {
          showNotification(
            title: notification.title ?? 'Goblin Park',
            body: notification.body ?? '',
            payload: message.data.isNotEmpty ? message.data.toString() : null,
          );
        }
      });

      // Manejo de apertura desde notificación
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        if (onNotificationTap != null) {
          onNotificationTap(message.data.toString());
        }
      });
    } catch (e) {
      debugPrint('>>> Nota: Firebase Messaging inicializado con fallback local: $e');
    }
  }

  // Disparar una notificación local con sonido, vibración y prioridad máxima
  static Future<void> showNotification({
    int? id,
    required String title,
    required String body,
    String? payload,
  }) async {
    final notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        _channel.id,
        _channel.name,
        channelDescription: _channel.description,
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _localNotificationsPlugin.show(
      id: id ?? (DateTime.now().millisecondsSinceEpoch % 100000),
      title: title,
      body: body,
      notificationDetails: notificationDetails,
      payload: payload,
    );
  }
}
