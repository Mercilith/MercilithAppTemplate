import 'dart:convert';
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Key embedded in a Windows action button's `arguments` string to carry the
/// action id alongside the notification payload — see [NotificationService]'s
/// doc comment for why. Unwrap this key in your app's notification-response
/// handler before treating the rest of the decoded JSON as your payload.
const String kWindowsActionKey = 'winAction';

/// A Windows/Android local-notification wrapper: scheduling, permissions,
/// and action buttons. Construct one instance per app (the host app
/// typically holds it as its own singleton) with your app's channel
/// identity, Windows app identity, and action-button list.
///
/// The background-response entry point cannot be supplied generically —
/// Dart isolate entry points must be real top-level functions annotated
/// `@pragma('vm:entry-point')` — so pass your own top-level function as
/// [onBackgroundResponse].
class NotificationService {
  NotificationService({
    required this.channelId,
    required this.channelName,
    required this.channelDescription,
    required this.windowsAppName,
    required this.windowsAppUserModelId,
    required this.windowsGuid,
    required this.actions,
    required this.onBackgroundResponse,
    this.androidIcon = '@mipmap/ic_launcher',
  });

  final String channelId;
  final String channelName;
  final String channelDescription;

  /// Stable per-app identity for Windows toast notifications. Only needs to
  /// be stable per install, not globally meaningful.
  final String windowsAppName;
  final String windowsAppUserModelId;
  final String windowsGuid;

  /// (action id, button label) pairs — becomes both the Android quick-action
  /// buttons and the Windows toast action buttons, in order.
  final List<(String id, String label)> actions;

  final void Function(NotificationResponse) onBackgroundResponse;
  final String androidIcon;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _inited = false;

  FlutterLocalNotificationsPlugin get plugin => _plugin;

  /// Idempotent — safe to call from both the UI isolate and a background one.
  Future<void> init({
    void Function(NotificationResponse)? onForegroundResponse,
  }) async {
    if (_inited) return;

    tzdata.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      // Fall back to UTC if the platform timezone can't be resolved.
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    final androidInit = AndroidInitializationSettings(androidIcon);
    final initSettings = InitializationSettings(
      android: androidInit,
      windows: Platform.isWindows
          ? WindowsInitializationSettings(
              appName: windowsAppName,
              appUserModelId: windowsAppUserModelId,
              guid: windowsGuid,
            )
          : null,
    );
    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: onForegroundResponse,
      onDidReceiveBackgroundNotificationResponse: onBackgroundResponse,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
      AndroidNotificationChannel(
        channelId,
        channelName,
        description: channelDescription,
        importance: Importance.high,
      ),
    );

    _inited = true;
  }

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  /// Requests POST_NOTIFICATIONS (Android 13+). Returns whether granted.
  Future<bool> requestNotificationPermission() async {
    return await _android?.requestNotificationsPermission() ?? true;
  }

  /// Requests SCHEDULE_EXACT_ALARM. Returns whether exact alarms are allowed.
  Future<bool> requestExactAlarmPermission() async {
    await _android?.requestExactAlarmsPermission();
    return canScheduleExact();
  }

  Future<bool> canScheduleExact() async {
    return await _android?.canScheduleExactNotifications() ?? false;
  }

  AndroidNotificationDetails _androidDetails() {
    return AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      actions: [
        for (final (id, label) in actions)
          AndroidNotificationAction(
            id,
            label,
            showsUserInterface: false,
            cancelNotification: true,
          ),
      ],
    );
  }

  /// Windows action buttons carry their own `arguments` string, and the
  /// plugin's Windows implementation reuses that same string for both
  /// `NotificationResponse.actionId` and `.payload` — there's no separate
  /// channel for a generic payload plus a distinct action id like Android
  /// has. So each button's `arguments` embeds the action id alongside the
  /// full payload; your background handler must unwrap [kWindowsActionKey]
  /// before treating the rest as your payload.
  WindowsNotificationDetails _windowsDetails(
      Map<String, dynamic> payloadJson) {
    String argsFor(String action) =>
        jsonEncode({...payloadJson, kWindowsActionKey: action});
    return WindowsNotificationDetails(
      actions: [
        for (final (id, label) in actions)
          WindowsAction(content: label, arguments: argsFor(id)),
      ],
    );
  }

  /// Schedules a notification at [fireAt] (local). Uses an exact alarm when
  /// permitted, otherwise a battery-friendly inexact one.
  Future<void> schedule({
    required int androidId,
    required String title,
    required String body,
    required DateTime fireAt,
    required Map<String, dynamic> payloadJson,
    required bool exact,
  }) async {
    final tzTime = tz.TZDateTime.from(fireAt, tz.local);
    await _plugin.zonedSchedule(
      androidId,
      title,
      body,
      tzTime,
      NotificationDetails(
        android: _androidDetails(),
        windows: Platform.isWindows ? _windowsDetails(payloadJson) : null,
      ),
      androidScheduleMode: exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      payload: jsonEncode(payloadJson),
    );
  }

  /// Cancels a scheduled/shown notification.
  ///
  /// On Windows, `cancel()`/`cancelAll()` are documented no-ops for apps
  /// without package identity (i.e. not MSIX-packaged) — a plain build
  /// artifact (no installer) may leave a stale toast lingering after this
  /// call. This is a known limitation, not a correctness bug, provided your
  /// action handler recomputes state from your own data on every action
  /// rather than trusting the notification alone.
  Future<void> cancel(int androidId) => _plugin.cancel(androidId);

  Future<void> cancelAll() => _plugin.cancelAll();
}
