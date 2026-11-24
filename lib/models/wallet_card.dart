import '../theme/card_skins.dart';

enum CardNetwork { visa, mastercard, rupay, amex, unknown }

/// How the bank logo sits on the card face.
enum LogoStyle {
  boxed('Boxed'), // logo on a white pill
  plain('Plain'), // logo straight on the card
  text('Name'); // bank name in type, no logo

  const LogoStyle(this.label);
  final String label;

  static LogoStyle parse(String? v) =>
      LogoStyle.values.firstWhere((s) => s.name == v, orElse: () => LogoStyle.boxed);
}

/// A saved card. Persisted as a flat `Map<String, String>` so it stays
/// compatible with cards written by earlier versions of the app.
class WalletCard {
  const WalletCard({
    required this.id,
    required this.number,
    required this.holder,
    required this.expiry,
    required this.cvv,
    required this.bank,
    required this.skinId,
    required this.limit,
    this.pinned = false,
    this.logoStyle = LogoStyle.boxed,
    this.billDay,
    this.remindDaysBefore,
  });

  final String id;
  final String number; // may contain spaces
  final String holder;
  final String expiry;
  final String cvv;
  final String bank;
  final String skinId;
  final double limit;
  final bool pinned;
  final LogoStyle logoStyle;

  /// Day of the month the bill (statement) is generated, 1–31. Optional.
  final int? billDay;

  /// Days before [billDay] to send a reminder (0 = on the day). `null` means
  /// no reminder. Only meaningful when [billDay] is set.
  final int? remindDaysBefore;

  bool get hasReminder => billDay != null && remindDaysBefore != null;

  String get digits => number.replaceAll(RegExp(r'\D'), '');

  String get last4 =>
      digits.length >= 4 ? digits.substring(digits.length - 4) : digits;

  /// "4821 9302 1188 4821"
  String get formattedNumber => digits
      .replaceAllMapped(RegExp(r'.{4}'), (m) => '${m.group(0)} ')
      .trim();

  /// "••••  ••••  ••••  4821"
  String get maskedNumber => '••••  ••••  ••••  $last4';

  CardNetwork get network => detectNetwork(digits);

  static CardNetwork detectNetwork(String digits) {
    if (digits.isEmpty) return CardNetwork.unknown;
    if (RegExp(r'^3[47]').hasMatch(digits)) return CardNetwork.amex;
    if (RegExp(r'^(60|65|81|82|508|353|356)').hasMatch(digits)) {
      return CardNetwork.rupay;
    }
    if (digits.startsWith('4')) return CardNetwork.visa;
    if (RegExp(r'^(5[1-5]|2[2-7])').hasMatch(digits)) {
      return CardNetwork.mastercard;
    }
    return CardNetwork.unknown;
  }

  WalletCard copyWith({String? skinId, bool? pinned, LogoStyle? logoStyle}) => WalletCard(
        id: id,
        number: number,
        holder: holder,
        expiry: expiry,
        cvv: cvv,
        bank: bank,
        skinId: skinId ?? this.skinId,
        limit: limit,
        pinned: pinned ?? this.pinned,
        logoStyle: logoStyle ?? this.logoStyle,
        billDay: billDay,
        remindDaysBefore: remindDaysBefore,
      );

  /// Sets or clears the bill date and reminder (pass `null` to clear).
  WalletCard withBilling({required int? billDay, required int? remindDaysBefore}) => WalletCard(
        id: id,
        number: number,
        holder: holder,
        expiry: expiry,
        cvv: cvv,
        bank: bank,
        skinId: skinId,
        limit: limit,
        pinned: pinned,
        logoStyle: logoStyle,
        billDay: billDay,
        remindDaysBefore: billDay == null ? null : remindDaysBefore,
      );

  factory WalletCard.fromMap(Map<String, String> m, {required String fallbackId}) {
    return WalletCard(
      id: m['id'] ?? fallbackId,
      number: m['card_number'] ?? '',
      holder: m['card_holder_name'] ?? '',
      expiry: m['expiry_date'] ?? '',
      cvv: m['cvv'] ?? '',
      bank: m['bank'] ?? '',
      skinId: m['theme'] ?? CardSkins.fromLegacy(m['cardBG']),
      limit: double.tryParse(m['card_balance'] ?? '') ?? 0,
      pinned: m['pinned'] == 'true',
      logoStyle: LogoStyle.parse(m['logo_style']),
      billDay: _day(m['bill_day']),
      remindDaysBefore: _day(m['bill_day']) == null ? null : _remind(m['remind_before']),
    );
  }

  static int? _day(String? v) {
    final d = int.tryParse(v ?? '');
    return d != null && d >= 1 && d <= 31 ? d : null;
  }

  static int? _remind(String? v) {
    final d = int.tryParse(v ?? '');
    return d != null && d >= 0 && d <= 27 ? d : null;
  }

  Map<String, String> toMap() => {
        'id': id,
        'card_number': number,
        'card_holder_name': holder,
        'expiry_date': expiry,
        'cvv': cvv,
        'bank': bank,
        'theme': skinId,
        // Kept so older builds can still read the card.
        'cardBG': skinId.startsWith('img:') ? skinId.substring(4) : '0',
        'card_balance': limit.toString(),
        'pinned': pinned.toString(),
        'logo_style': logoStyle.name,
        if (billDay != null) 'bill_day': billDay.toString(),
        if (billDay != null && remindDaysBefore != null)
          'remind_before': remindDaysBefore.toString(),
      };
}
