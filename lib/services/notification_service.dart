import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(iOS: ios);
    await _plugin.initialize(settings);
    _initialized = true;
  }

  Future<bool> requestPermission() async {
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios == null) return false;
    final granted = await ios.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
    if (kDebugMode) debugPrint('[Notifications] permission granted: $granted');
    return granted ?? false;
  }

  Future<bool> isPermissionGranted() async {
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios == null) return false;
    final status = await ios.checkPermissions();
    return status?.isEnabled ?? false;
  }
}
