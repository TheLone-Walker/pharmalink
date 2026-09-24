import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../utils/constants.dart';
import '../main.dart';
import 'notification_service.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  IO.Socket? _socket;
  String? _currentUserId;
  String? _currentRole;
  String? _currentPharmacyId;
  bool _isConnected = false;

  bool get isConnected => _isConnected;

  // Broadcaster callbacks
  final Map<String, List<Function(dynamic)>> _listeners = {};

  void connect(String userId, {String? role, String? pharmacyId}) {
    _currentUserId = userId;
    _currentRole = role;
    _currentPharmacyId = pharmacyId;

    if (_socket != null && _socket!.connected) {
      // Re-join rooms if already connected
      _joinActiveRooms();
      return;
    }

    try {
      _socket = IO.io(
        AppConstants.socketUrl,
        IO.OptionBuilder()
            .setTransports(['websocket', 'polling'])
            .enableAutoConnect()
            .enableReconnection()
            .setReconnectionAttempts(999)
            .setReconnectionDelay(1500)
            .build(),
      );

      _socket!.onConnect((_) {
        _isConnected = true;
        debugPrint('⚡ Socket Connected: ${_socket?.id}');
        _joinActiveRooms();
      });

      _socket!.onDisconnect((_) {
        _isConnected = false;
        debugPrint('🔌 Socket Disconnected');
      });

      _socket!.onConnectError((err) {
        _isConnected = false;
        debugPrint('❌ Socket Connect Error: $err');
      });

      _setupGlobalListeners();
    } catch (e) {
      debugPrint('Error initializing socket: $e');
    }
  }

  void _joinActiveRooms() {
    if (_socket == null || !_socket!.connected) return;
    if (_currentUserId != null && _currentUserId!.isNotEmpty) {
      _socket!.emit('join_room', _currentUserId);
      debugPrint('👤 Socket joined room: user_$_currentUserId');
    }
    if (_currentRole != null && _currentRole!.isNotEmpty) {
      _socket!.emit('join_role', _currentRole);
      debugPrint('🏷️ Socket joined role: role_$_currentRole');
    }
    if (_currentPharmacyId != null && _currentPharmacyId!.isNotEmpty) {
      _socket!.emit('join_pharmacy', _currentPharmacyId);
      debugPrint('🏥 Socket joined pharmacy: pharmacy_$_currentPharmacyId');
    }
  }

  void _setupGlobalListeners() {
    if (_socket == null) return;

    // 1. New Order
    _socket!.on('order:new', (data) {
      debugPrint('📦 Socket Event: order:new -> $data');
      _notifyLocalAndInApp(
        title: 'New Order Received! 📦',
        body: 'A new order #${_getShortId(data)} has arrived. Tap to view.',
        icon: Icons.inventory_2_outlined,
        iconColor: const Color(0xFF2E7D32),
      );
      _dispatch('order:new', data);
    });

    // 2. Order Updated / Status Change
    _socket!.on('order:updated', (data) {
      debugPrint('🔄 Socket Event: order:updated -> $data');
      final status = data['status']?.toString().replaceAll('_', ' ').toUpperCase() ?? 'UPDATED';
      _notifyLocalAndInApp(
        title: 'Order Status Update 📦',
        body: 'Order #${_getShortId(data)} is now $status.',
        icon: Icons.local_shipping_outlined,
        iconColor: const Color(0xFF0284C7),
      );
      _dispatch('order:updated', data);
    });

    _socket!.on('order:status_change', (data) {
      debugPrint('🔄 Socket Event: order:status_change -> $data');
      _dispatch('order:status_change', data);
    });

    // 3. New Appointment
    _socket!.on('appointment:new', (data) {
      debugPrint('🩺 Socket Event: appointment:new -> $data');
      final patientName = data['patient']?['name'] ?? 'Patient';
      _notifyLocalAndInApp(
        title: 'New Appointment Booked 🩺',
        body: '$patientName booked an appointment with you.',
        icon: Icons.calendar_month_outlined,
        iconColor: const Color(0xFF0D9488),
      );
      _dispatch('appointment:new', data);
    });

    // 4. Appointment Updated
    _socket!.on('appointment:updated', (data) {
      debugPrint('🩺 Socket Event: appointment:updated -> $data');
      final status = data['status']?.toString().toUpperCase() ?? 'UPDATED';
      _notifyLocalAndInApp(
        title: 'Appointment Update 🩺',
        body: 'Your appointment is now: $status',
        icon: Icons.event_available,
        iconColor: const Color(0xFF0D9488),
      );
      _dispatch('appointment:updated', data);
    });

    // 5. New Prescription & Reminders
    _socket!.on('prescription:new', (data) {
      debugPrint('💊 Socket Event: prescription:new -> $data');
      _notifyLocalAndInApp(
        title: 'New Prescription Issued 💊',
        body: 'Your doctor issued a prescription and configured your drug reminders.',
        icon: Icons.medication_outlined,
        iconColor: const Color(0xFF7C3AED),
      );
      _dispatch('prescription:new', data);
    });

    // 6. New Delivery Assignment
    _socket!.on('delivery:new', (data) {
      debugPrint('🚚 Socket Event: delivery:new -> $data');
      _notifyLocalAndInApp(
        title: 'New Delivery Assigned 🚚',
        body: 'You have been assigned to deliver a new order.',
        icon: Icons.electric_moped_outlined,
        iconColor: const Color(0xFFEA580C),
      );
      _dispatch('delivery:new', data);
    });

    // 7. General Notification
    _socket!.on('notification:new', (data) {
      debugPrint('🔔 Socket Event: notification:new -> $data');
      final title = data['title']?.toString() ?? 'Notification';
      final body = data['body']?.toString() ?? '';
      _notifyLocalAndInApp(
        title: title,
        body: body,
        icon: Icons.notifications_active_outlined,
        iconColor: const Color(0xFF2E7D32),
      );
      _dispatch('notification:new', data);
    });

    // 8. In-App Chat
    _socket!.on('chat:message', (data) {
      debugPrint('💬 Socket Event: chat:message -> $data');
      _dispatch('chat:message', data);
    });

    // 9. Driver GPS
    _socket!.on('driver:location', (data) {
      _dispatch('driver:location', data);
    });

    // 10. Instant User Data Refresh
    _socket!.on('user:refresh', (data) {
      debugPrint('🔄 Socket Event: user:refresh -> $data');
      _dispatch('user:refresh', data);
    });
  }

  void _dispatch(String event, dynamic data) {
    if (_listeners.containsKey(event)) {
      for (final callback in List.from(_listeners[event]!)) {
        try {
          callback(data);
        } catch (e) {
          debugPrint('Error running listener for $event: $e');
        }
      }
    }
  }

  String _getShortId(dynamic data) {
    if (data is Map && data['id'] != null) {
      final str = data['id'].toString();
      return str.length >= 8 ? str.substring(0, 8).toUpperCase() : str.toUpperCase();
    }
    return '';
  }

  void _notifyLocalAndInApp({
    required String title,
    required String body,
    required IconData icon,
    required Color iconColor,
  }) {
    // Show device local notification
    NotificationService().show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
    ).catchError((_) {});

    // Show floating in-app banner
    showInAppBanner(
      title: title,
      body: body,
      icon: icon,
      iconColor: iconColor,
    );
  }

  /// Global visual banner shown at top/bottom of screen regardless of active tab
  static void showInAppBanner({
    required String title,
    required String body,
    IconData icon = Icons.notifications_active_outlined,
    Color iconColor = const Color(0xFF2E7D32),
    VoidCallback? onTap,
  }) {
    final messenger = rootScaffoldMessengerKey.currentState;
    if (messenger == null) return;

    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        elevation: 6,
        backgroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: iconColor.withOpacity(0.35), width: 1.5),
        ),
        duration: const Duration(seconds: 4),
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 8),
              TextButton(
                onPressed: () {
                  rootScaffoldMessengerKey.currentState?.hideCurrentSnackBar();
                  onTap();
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text('VIEW', style: TextStyle(color: iconColor, fontWeight: FontWeight.w700, fontSize: 12)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // --- Registration / Subscription Helpers ---

  void addListener(String event, Function(dynamic) callback) {
    _listeners.putIfAbsent(event, () => []).add(callback);
  }

  void removeListener(String event, Function(dynamic) callback) {
    _listeners[event]?.remove(callback);
  }

  void onOrderNew(Function(dynamic) callback) => addListener('order:new', callback);
  void onOrderUpdated(Function(dynamic) callback) => addListener('order:updated', callback);
  void onOrderStatus(Function(dynamic) callback) => addListener('order:status_change', callback);
  void onAppointmentNew(Function(dynamic) callback) => addListener('appointment:new', callback);
  void onAppointmentUpdated(Function(dynamic) callback) => addListener('appointment:updated', callback);
  void onPrescriptionNew(Function(dynamic) callback) => addListener('prescription:new', callback);
  void onDeliveryNew(Function(dynamic) callback) => addListener('delivery:new', callback);
  void onNewNotification(Function(dynamic) callback) => addListener('notification:new', callback);
  void onChatMessage(Function(dynamic) callback) => addListener('chat:message', callback);
  void onDriverLocation(Function(dynamic) callback) => addListener('driver:location', callback);
  void onUserRefresh(Function(dynamic) callback) => addListener('user:refresh', callback);

  void joinOrder(String orderId) {
    if (_socket != null && _socket!.connected) {
      _socket!.emit('join_order', orderId);
    }
  }

  void sendLocation(String orderId, double lat, double lng) {
    if (_socket != null && _socket!.connected) {
      _socket!.emit('driver:location_update', {'orderId': orderId, 'lat': lat, 'lng': lng});
    }
  }

  void disconnect() {
    _socket?.disconnect();
    _socket = null;
    _isConnected = false;
    _listeners.clear();
  }
}
