import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Top-level background message handler (must be a top-level function).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[NotificationService] Background message: ${message.messageId}');
  // Show local notification for background messages
  await NotificationService._showLocalNotification(message);
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'chatku_messages',
    'Chat Messages',
    description: 'Notifications for new chat messages and calls',
    importance: Importance.high,
    playSound: true,
  );

  /// Initialize Firebase Messaging and local notifications.
  /// Call this from main() after Firebase.initializeApp().
  static Future<void> initialize() async {
    final messaging = FirebaseMessaging.instance;

    // Request permission (iOS and Android 13+)
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    debugPrint(
        '[NotificationService] Permission status: ${settings.authorizationStatus}');

    // Register background handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Set foreground notification presentation options
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Initialize local notifications plugin
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _localNotifications.initialize(initSettings);

    // Create notification channel for Android
    final androidPlugin =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(_channel);
    }

    // Get and log FCM token
    try {
      final token = await messaging.getToken();
      debugPrint('[NotificationService] FCM Token: $token');
    } catch (e) {
      debugPrint('[NotificationService] Failed to get FCM token: $e');
    }
  }

  /// Set up foreground message listener.
  /// Call this after user is authenticated and navigated to HomePage.
  static void setupForegroundListener() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint(
          '[NotificationService] Foreground message: ${message.messageId}');
      _showLocalNotification(message);
    });
  }

  /// Save FCM token to the user's Firestore document.
  /// Call after login so the server can target this device.
  static Future<void> saveTokenToFirestore(String uid) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'fcmToken': token,
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        });
        debugPrint('[NotificationService] FCM token saved for user $uid');
      }
    } catch (e) {
      debugPrint('[NotificationService] Failed to save FCM token: $e');
    }

    // Listen for token refreshes
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      try {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'fcmToken': newToken,
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        });
        debugPrint('[NotificationService] FCM token refreshed for user $uid');
      } catch (e) {
        debugPrint('[NotificationService] Failed to update refreshed token: $e');
      }
    });
  }

  /// Display a local notification from a RemoteMessage.
  static Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    const androidDetails = AndroidNotificationDetails(
      'chatku_messages',
      'Chat Messages',
      channelDescription: 'Notifications for new chat messages and calls',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const details = NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      notification.hashCode,
      notification.title ?? 'ChatKu',
      notification.body ?? '',
      details,
    );
  }
}
