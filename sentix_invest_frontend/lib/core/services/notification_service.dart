import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../network/dio_client.dart';

/// Handles background messages when app is terminated
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('🔔 Background message received: ${message.notification?.title}');
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final DioClient _dioClient = DioClient();
  
  String? _fcmToken;
  bool _initialized = false;

  String? get fcmToken => _fcmToken;

  /// Initialize Firebase and notification services
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Initialize Firebase
      await Firebase.initializeApp();

      // Set background message handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Request notification permissions
      await _requestPermissions();

      // Initialize local notifications (for foreground)
      await _initializeLocalNotifications();

      // Get FCM token
      await _getToken();

      // Listen for token refresh
      _messaging.onTokenRefresh.listen(_onTokenRefresh);

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_onForegroundMessage);

      // Handle notification tap when app is in background
      FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);

      _initialized = true;
      debugPrint('✅ Notification service initialized');
    } catch (e) {
      debugPrint('❌ Failed to initialize notifications: $e');
    }
  }

  /// Request notification permissions from user
  Future<void> _requestPermissions() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
      announcement: false,
      carPlay: false,
      criticalAlert: false,
    );

    debugPrint('📱 Notification permission: ${settings.authorizationStatus}');
  }

  /// Initialize local notifications for foreground display
  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Create notification channel for Android
    const androidChannel = AndroidNotificationChannel(
      'price_alerts',
      'Price Alerts',
      description: 'Notifications for stock price alerts',
      importance: Importance.high,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  /// Get FCM token and store it
  Future<void> _getToken() async {
    _fcmToken = await _messaging.getToken();
    debugPrint('📱 FCM Token: $_fcmToken');

    if (_fcmToken != null) {
      await _storeToken(_fcmToken!);
      await _sendTokenToServer(_fcmToken!);
    }
  }

  /// Handle token refresh
  void _onTokenRefresh(String newToken) async {
    _fcmToken = newToken;
    debugPrint('🔄 FCM Token refreshed: $newToken');
    await _storeToken(newToken);
    await _sendTokenToServer(newToken);
  }

  /// Store token locally
  Future<void> _storeToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fcm_token', token);
  }

  /// Send token to backend server for push notification targeting
  Future<void> _sendTokenToServer(String token) async {
    try {
      await _dioClient.dio.post(
        '/users/fcm-token',
        data: {'fcmToken': token},
      );
      debugPrint('✅ FCM token sent to server');
    } catch (e) {
      debugPrint('⚠️ Failed to send FCM token to server: $e');
    }
  }

  /// Handle foreground messages
  void _onForegroundMessage(RemoteMessage message) {
    debugPrint('🔔 Foreground message: ${message.notification?.title}');
    _showLocalNotification(message);
  }

  /// Show local notification when app is in foreground
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    const androidDetails = AndroidNotificationDetails(
      'price_alerts',
      'Price Alerts',
      channelDescription: 'Notifications for stock price alerts',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      message.hashCode,
      notification.title,
      notification.body,
      details,
      payload: message.data['alertId'],
    );
  }

  /// Handle notification tap when app was in background
  void _onMessageOpenedApp(RemoteMessage message) {
    debugPrint('📱 Notification opened: ${message.notification?.title}');
    // Handle navigation based on notification data
    _handleNotificationNavigation(message.data);
  }

  /// Handle notification tap from local notification
  void _onNotificationTap(NotificationResponse response) {
    debugPrint('📱 Local notification tapped: ${response.payload}');
    // Handle navigation based on payload
    if (response.payload != null) {
      // Navigate to alert details or stock screen
    }
  }

  /// Handle navigation based on notification data
  void _handleNotificationNavigation(Map<String, dynamic> data) {
    final alertId = data['alertId'];
    final symbol = data['symbol'];

    if (alertId != null) {
      // Navigate to alert details
      debugPrint('Navigate to alert: $alertId');
    } else if (symbol != null) {
      // Navigate to stock details
      debugPrint('Navigate to stock: $symbol');
    }
  }

  /// Subscribe to a topic (e.g., for market updates)
  Future<void> subscribeToTopic(String topic) async {
    await _messaging.subscribeToTopic(topic);
    debugPrint('📢 Subscribed to topic: $topic');
  }

  /// Unsubscribe from a topic
  Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
    debugPrint('📢 Unsubscribed from topic: $topic');
  }

  /// Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    final settings = await _messaging.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized;
  }
}
