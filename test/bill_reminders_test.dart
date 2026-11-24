import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_cards/models/wallet_card.dart';
import 'package:pocket_cards/services/bill_reminders.dart';

WalletCard _card({int? billDay, int? remind}) => WalletCard(
      id: 'c1',
      number: '9405 1188 2210 4821',
      holder: 'Aarav Mehta',
      expiry: '08/29',
      cvv: '317',
      bank: 'Nova Bank',
      skinId: 'grad:aurora',
      limit: 0,
      billDay: billDay,
      remindDaysBefore: remind,
    );

void main() {
  group('upcoming reminder times', () {
    test('5 days before the 12th, at 10 am, monthly', () {
      final r = BillReminders.upcoming(
          billDay: 12, daysBefore: 5, from: DateTime(2026, 11, 24, 9), count: 3);
      expect(r, [DateTime(2026, 12, 7, 10), DateTime(2027, 1, 7, 10), DateTime(2027, 2, 7, 10)]);
    });

    test('a reminder later today is still included', () {
      final r = BillReminders.upcoming(
          billDay: 29, daysBefore: 5, from: DateTime(2026, 11, 24, 9), count: 1);
      expect(r.single, DateTime(2026, 11, 24, 10));
    });

    test('bill day 31 uses the last day of short months', () {
      final r = BillReminders.upcoming(
          billDay: 31, daysBefore: 0, from: DateTime(2027, 1, 31, 12), count: 3);
      expect(r, [DateTime(2027, 2, 28, 10), DateTime(2027, 3, 31, 10), DateTime(2027, 4, 30, 10)]);
    });

    test('leap-year February', () {
      final r = BillReminders.upcoming(
          billDay: 30, daysBefore: 0, from: DateTime(2028, 2, 1), count: 1);
      expect(r.single, DateTime(2028, 2, 29, 10));
    });

    test('reminder rolls back into the previous month', () {
      final r = BillReminders.upcoming(
          billDay: 3, daysBefore: 10, from: DateTime(2026, 11, 24, 12), count: 2);
      expect(r, [DateTime(2026, 12, 24, 10), DateTime(2027, 1, 24, 10)]);
    });

    test('rolls back across a year boundary', () {
      final r = BillReminders.upcoming(
          billDay: 2, daysBefore: 7, from: DateTime(2026, 12, 20), count: 1);
      expect(r.single, DateTime(2026, 12, 26, 10));
    });
  });

  test('notification text names the bank and last 4 only', () {
    final c = _card(billDay: 12, remind: 5);
    expect(BillReminders.title(c), 'Nova Bank bill in 5 days');
    expect(BillReminders.body(c, DateTime(2026, 12, 12)), 'Card ending 4821 · bill date 12 Dec');
    expect(BillReminders.title(_card(billDay: 12, remind: 0)), 'Nova Bank bill date is today');
  });

  test('ordinals', () {
    expect([1, 2, 3, 4, 11, 12, 13, 21, 22, 23, 31].map(BillReminders.ordinal).toList(),
        ['1st', '2nd', '3rd', '4th', '11th', '12th', '13th', '21st', '22nd', '23rd', '31st']);
  });

  group('stored card', () {
    test('bill day and reminder survive a save/load round trip', () {
      final back = WalletCard.fromMap(_card(billDay: 22, remind: 3).toMap(), fallbackId: 'x');
      expect(back.billDay, 22);
      expect(back.remindDaysBefore, 3);
      expect(back.hasReminder, isTrue);
    });

    test('cards saved before this feature load with no reminder', () {
      final old = _card().toMap();
      expect(old.containsKey('bill_day'), isFalse);
      final back = WalletCard.fromMap(old, fallbackId: 'x');
      expect(back.billDay, isNull);
      expect(back.hasReminder, isFalse);
    });

    test('a bill date without a reminder is kept', () {
      final back = WalletCard.fromMap(_card(billDay: 5).toMap(), fallbackId: 'x');
      expect(back.billDay, 5);
      expect(back.remindDaysBefore, isNull);
    });

    test('garbage values are ignored', () {
      final m = _card().toMap()..addAll({'bill_day': '45', 'remind_before': '3'});
      final back = WalletCard.fromMap(m, fallbackId: 'x');
      expect(back.billDay, isNull);
      expect(back.remindDaysBefore, isNull);
    });

    test('clearing the bill date also clears the reminder', () {
      final c = _card(billDay: 12, remind: 5).withBilling(billDay: null, remindDaysBefore: 5);
      expect(c.billDay, isNull);
      expect(c.remindDaysBefore, isNull);
    });

    test('other edits keep the reminder', () {
      final c = _card(billDay: 12, remind: 5).copyWith(pinned: true);
      expect(c.billDay, 12);
      expect(c.remindDaysBefore, 5);
    });
  });
}
