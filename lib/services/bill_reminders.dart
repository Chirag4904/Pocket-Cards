import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/wallet_card.dart';

/// Monthly bill reminders, scheduled by the phone itself. No server, no
/// network: the OS fires notifications the app queued earlier.
///
/// Instead of one "repeat monthly" rule (which can't express "5 days before
/// the 31st" across short months), we queue the next few reminders as
/// one-off notifications and refresh the queue whenever cards change or the
/// app starts. iOS allows 64 pending notifications per app, so the number
/// queued per card shrinks as more cards use reminders.
class BillReminders {
  BillReminders._();

  /// Choices offered in the UI. 0 = on the bill day itself.
  static const leadTimes = [0, 3, 5, 7, 10];

  /// Reminders go out at this local hour.
  static const hour = 10;

  static const _maxPending = 48; // well under iOS's 64 cap
  static const _channelId = 'bill_reminders';

  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static Future<void> init() async {
    try {
      tz_data.initializeTimeZones();
      try {
        tz.setLocalLocation(tz.getLocation(await FlutterTimezone.getLocalTimezone()));
      } catch (e) {
        debugPrint('Timezone not resolved, using UTC: $e');
      }
      await _plugin.initialize(const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        // Ask for permission only when the user turns a reminder on.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ));
      _ready = true;
    } catch (e) {
      debugPrint('Reminders unavailable: $e');
    }
  }

  /// Asks the OS for permission to show notifications. Returns whether
  /// reminders will be able to appear.
  static Future<bool> requestPermission() async {
    if (!_ready) return false;
    try {
      if (Platform.isAndroid) {
        final android = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        return await android?.requestNotificationsPermission() ?? true;
      }
      if (Platform.isIOS) {
        final ios = _plugin
            .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
        return await ios?.requestPermissions(alert: true, sound: true) ?? false;
      }
    } catch (e) {
      debugPrint('Notification permission request failed: $e');
    }
    return false;
  }

  static Future<void> _pending = Future.value();

  /// Replaces every queued reminder with a fresh set for [cards]. Calls are
  /// run one after another so two quick edits can't interleave.
  static Future<void> sync(List<WalletCard> cards) {
    if (!_ready) return Future.value();
    final snapshot = List<WalletCard>.of(cards);
    return _pending = _pending.then((_) => _sync(snapshot));
  }

  static Future<void> _sync(List<WalletCard> cards) async {
    try {
      // Pending only: leave reminders already in the notification centre.
      await _plugin.cancelAllPendingNotifications();
      final withReminders = cards.where((c) => c.hasReminder).toList();
      if (withReminders.isEmpty) return;
      final perCard = (_maxPending ~/ withReminders.length).clamp(1, 12);
      final now = DateTime.now();
      var id = 0;
      for (final card in withReminders) {
        for (final at in upcoming(
          billDay: card.billDay!,
          daysBefore: card.remindDaysBefore!,
          from: now,
          count: perCard,
        )) {
          final billDate = DateTime(at.year, at.month, at.day + card.remindDaysBefore!);
          await _plugin.zonedSchedule(
            id++,
            title(card),
            body(card, billDate),
            tz.TZDateTime(tz.local, at.year, at.month, at.day, at.hour),
            _details,
            // Inexact is fine for a reminder and needs no exact-alarm permission.
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          );
        }
      }
    } catch (e) {
      debugPrint('Reminders not scheduled: $e');
    }
  }

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      'Bill reminders',
      channelDescription: 'Reminders before a card\'s monthly bill date',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    ),
    iOS: DarwinNotificationDetails(),
  );

  static const _previewId = 9000; // outside the range sync() uses

  /// Shows [card]'s reminder right now, exactly as it will look, so people
  /// can see it without waiting for the date. Returns false if notifications
  /// aren't allowed.
  static Future<bool> preview(WalletCard card) async {
    if (!_ready || !card.hasReminder) return false;
    if (!await requestPermission()) return false;
    try {
      final at = upcoming(
        billDay: card.billDay!,
        daysBefore: card.remindDaysBefore!,
        from: DateTime.now(),
        count: 1,
      ).first;
      final billDate = DateTime(at.year, at.month, at.day + card.remindDaysBefore!);
      await _plugin.show(_previewId, title(card), body(card, billDate), _details);
      return true;
    } catch (e) {
      debugPrint('Preview not shown: $e');
      return false;
    }
  }

  static String title(WalletCard card) {
    final name = card.bank.isEmpty ? 'Card' : card.bank;
    final d = card.remindDaysBefore ?? 0;
    return d == 0 ? '$name bill date is today' : '$name bill in $d days';
  }

  static String body(WalletCard card, DateTime billDate) =>
      'Card ending ${card.last4} · bill date ${billDate.day} ${_months[billDate.month - 1]}';

  /// The next [count] reminder times after [from], in local wall-clock time.
  ///
  /// A bill day past the end of a month falls on that month's last day
  /// (31 → 30 Apr, 28/29 Feb). The reminder is [daysBefore] days earlier
  /// at [hour]:00, which may land in the previous month.
  @visibleForTesting
  static List<DateTime> upcoming({
    required int billDay,
    required int daysBefore,
    required DateTime from,
    int count = 6,
  }) {
    final out = <DateTime>[];
    // Start a month back: next month's bill can need a reminder this month.
    var year = from.year, month = from.month - 1;
    while (out.length < count) {
      if (month < 1) {
        month += 12;
        year--;
      } else if (month > 12) {
        month -= 12;
        year++;
      }
      final day = math.min(billDay, DateTime(year, month + 1, 0).day);
      // DateTime normalises a negative/zero day into the previous month.
      final at = DateTime(year, month, day - daysBefore, hour);
      if (at.isAfter(from)) out.add(at);
      month++;
    }
    return out;
  }

  /// "1st", "22nd", "31st" — for labels like "Bill on the 22nd".
  static String ordinal(int n) {
    if (n % 100 >= 11 && n % 100 <= 13) return '${n}th';
    return '$n${const ['th', 'st', 'nd', 'rd'][n % 10 < 4 ? n % 10 : 0]}';
  }

  static String leadLabel(int days) => days == 0 ? 'On the day' : '$days days before';

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
}
