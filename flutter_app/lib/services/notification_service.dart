import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'api_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(android: androidSettings, iOS: iosSettings);
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onTap,
    );
    await _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  void _onTap(NotificationResponse response) {
    // Handle notification tap — navigate based on payload
    debugPrint('Notification tapped: ${response.payload}');
  }

  Future<void> show({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'pharmalink_channel',
      'PharmaLink Notifications',
      channelDescription: 'PharmaLink app notifications',
      importance: Importance.high,
      priority: Priority.high,
      color: Color(0xFF2E7D32),
      icon: '@mipmap/ic_launcher',
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);
    await _plugin.show(id, title, body, details, payload: payload);
  }

  Future<void> showOrderUpdate(String status, String orderId) async {
    final messages = {
      'confirmed': 'Your order has been confirmed by the pharmacy!',
      'preparing': 'Your order is being prepared.',
      'out_for_delivery': 'Your order is on the way! Track your driver.',
      'delivered': 'Your order has been delivered successfully!',
      'cancelled': 'Your order was cancelled.',
    };
    await show(
      id: orderId.hashCode,
      title: 'Order Update',
      body: messages[status] ?? 'Your order status has changed to $status',
      payload: 'order:$orderId',
    );
  }

  Future<void> showNewMessage(String senderName, String message) async {
    await show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: senderName,
      body: message,
      payload: 'chat',
    );
  }

  Future<void> showAppointmentReminder(String doctorName, String time) async {
    await show(
      id: 999,
      title: 'Appointment Reminder',
      body: 'You have an appointment with Dr. $doctorName at $time',
      payload: 'appointment',
    );
  }

  Future<void> scheduleReminder({
    required int id,
    required String medicationName,
    required String dosage,
    required TimeOfDay time,
  }) async {
    // Schedule daily local notification for medication reminder
    const androidDetails = AndroidNotificationDetails(
      'pharmalink_reminders',
      'Medication Reminders',
      channelDescription: 'Daily medication reminders',
      importance: Importance.high,
      priority: Priority.high,
      color: Color(0xFF2E7D32),
    );
    const details = NotificationDetails(android: androidDetails);
    await _plugin.show(
      id,
      'Medication Reminder 💊',
      'Time to take $medicationName — $dosage',
      details,
      payload: 'reminder:$medicationName',
    );
  }

  /// Register FCM token with the backend
  Future<void> registerFcmToken(String token) async {
    try {
      await ApiService().post('/push/fcm-token', data: {'token': token});
    } catch (_) {}
  }

  Future<void> cancelAll() => _plugin.cancelAll();
  Future<void> cancel(int id) => _plugin.cancel(id);
}
