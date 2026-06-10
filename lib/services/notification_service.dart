import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Background handler moved to main.dart

class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'chatku_messages', // id
    'Chat Messages', // title
    description: 'Notifications for new chat messages and calls', // description
    importance: Importance.max, // Set to max for heads-up notifications
    playSound: true,
  );

  /// Initialize Firebase Messaging and local notifications.
  /// Call this from main() after Firebase.initializeApp().
  static Future<void> initialize() async {
    debugPrint('[NotificationService] Initializing...');
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
    
    final initialized = await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('[NotificationService] onDidReceiveNotificationResponse: ${response.payload}');
      },
    );
    debugPrint('[NotificationService] Local notifications initialized: $initialized');

    // Create notification channel for Android
    final androidPlugin =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(_channel);
      debugPrint('[NotificationService] Android notification channel created: ${_channel.id}');
    }

    // Background handler registration moved to main.dart

    // Handle initial message (when app is launched from terminated state via notification)
    messaging.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        debugPrint('[NotificationService] getInitialMessage received: ${message.messageId}');
      }
    });

    // Handle message opened app (when app is in background and user taps notification)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('[NotificationService] onMessageOpenedApp received: ${message.messageId}');
    });

    // Get and log FCM token
    try {
      final token = await messaging.getToken();
      debugPrint('[NotificationService] Initial FCM Token: $token');
    } catch (e) {
      debugPrint('[NotificationService] Failed to get initial FCM token: $e');
    }
  }

  /// Set up foreground message listener.
  /// Call this after user is authenticated and navigated to HomePage.
  static void setupForegroundListener() {
    debugPrint('[NotificationService] Setting up foreground listener...');
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint(
          '[NotificationService] onMessage (foreground) received: ${message.messageId}');
      debugPrint('[NotificationService] Notification title: ${message.notification?.title}, body: ${message.notification?.body}');
      showLocalNotification(message);
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
        debugPrint('[NotificationService] FCM token saved to Firestore for user $uid');
        debugPrint('[NotificationService] Token: $token');
      } else {
        debugPrint('[NotificationService] Warning: FCM token is null when trying to save.');
      }
    } catch (e) {
      debugPrint('[NotificationService] Failed to save FCM token to Firestore: $e');
    }

    // Listen for token refreshes
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      try {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'fcmToken': newToken,
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        });
        debugPrint('[NotificationService] FCM token refreshed and saved for user $uid');
        debugPrint('[NotificationService] New Token: $newToken');
      } catch (e) {
        debugPrint('[NotificationService] Failed to update refreshed token: $e');
      }
    });
  }

  /// Display a local notification from a RemoteMessage.
  static Future<void> showLocalNotification(RemoteMessage message) async {
    debugPrint('[NotificationService] Triggering local notification show()...');
    
    // Sometimes FCM messages send data but no notification object.
    // If you want to show notifications for data-only messages, you need to extract from message.data
    final title = message.notification?.title ?? message.data['title'] ?? 'New Message';
    final body = message.notification?.body ?? message.data['body'] ?? '';

    // Must match the channel ID exactly
    const androidDetails = AndroidNotificationDetails(
      'chatku_messages', // Must match _channel.id
      'Chat Messages', // Must match _channel.name
      channelDescription: 'Notifications for new chat messages and calls', // Must match _channel.description
      importance: Importance.max, // High importance for heads-up
      priority: Priority.high, // High priority
      icon: '@mipmap/ic_launcher',
    );
    const details = NotificationDetails(android: androidDetails);

    try {
      await _localNotifications.show(
        message.hashCode, // Unique ID for the notification
        title,
        body,
        details,
        payload: message.data.toString(), // Optional payload
      );
      debugPrint('[NotificationService] Local notification show() succeeded.');
    } catch (e) {
      debugPrint('[NotificationService] Error showing local notification: $e');
    }
  }
}
