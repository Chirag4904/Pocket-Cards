import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_cards/CreditCardScreen.dart';
import 'package:pocket_cards/models/wallet_card.dart';
import 'package:pocket_cards/provider/card_provider.dart';
import 'package:pocket_cards/provider/wallet_provider.dart';
import 'package:pocket_cards/secure_card_service.dart';
import 'package:pocket_cards/theme/app_theme.dart';
import 'package:provider/provider.dart';

/// In-memory stand-in for secure storage.
class FakeStorage extends SecureStorageService {
  FakeStorage(this.cards);
  List<Map<String, String>> cards;

  @override
  Future<List<Map<String, String>>> getCards() async =>
      cards.map((c) => Map<String, String>.from(c)).toList();

  @override
  Future<void> saveCards(List<Map<String, String>> list) async => cards = list;
}

Map<String, String> legacyCard(String number, {String bg = '0'}) => {
      'card_number': number,
      'card_holder_name': 'Test User',
      'expiry_date': '09/29',
      'cvv': '123',
      'bank': 'HDFC Bank',
      'cardBG': bg,
      'card_balance': '100000.0',
    };

void main() {
  test('formatInr uses Indian grouping', () {
    expect(formatInr(0), '₹0');
    expect(formatInr(999), '₹999');
    expect(formatInr(250000), '₹2,50,000');
    expect(formatInr(12345678), '₹1,23,45,678');
  });

  test('legacy cards get ids and skins, and pins sort to the top', () async {
    final storage = FakeStorage([
      legacyCard('4111111111111111', bg: '2'),
      legacyCard('5555555555554444'),
    ]);
    final wallet = WalletProvider(storage: storage);
    await wallet.load();

    expect(wallet.cards.map((c) => c.skinId), ['img:2', 'grad:ember']);
    expect(wallet.cards.every((c) => c.id.isNotEmpty), isTrue);
    expect(storage.cards.first['id'], isNotNull, reason: 'migration persisted');

    expect(wallet.cards.first.logoStyle, LogoStyle.boxed, reason: 'default for old cards');
    await wallet.updateLogoStyle(wallet.cards.first.id, LogoStyle.plain);
    expect(storage.cards.first['logo_style'], 'plain');

    await wallet.togglePin(wallet.cards[1].id);
    expect(wallet.cards.first.last4, '4444');
    expect(wallet.cards.first.pinned, isTrue);
  });

  testWidgets('swipe left deletes and UNDO restores', (tester) async {
    final wallet = WalletProvider(storage: FakeStorage([
      legacyCard('4111111111114821'),
    ]));
    await tester.runAsync(wallet.load);
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CardProvider()),
        ChangeNotifierProvider.value(value: wallet),
      ],
      child: MaterialApp(theme: buildAppTheme(), home: const CreditCardScreen()),
    ));
    await tester.pump(const Duration(seconds: 2));
    expect(wallet.cards, hasLength(1));

    await tester.fling(find.byType(Dismissible), const Offset(-400, 0), 1500);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(const Duration(seconds: 1));
    expect(wallet.cards, isEmpty);
    expect(find.text('UNDO'), findsOneWidget);

    await tester.tap(find.text('UNDO'));
    await tester.pump(const Duration(seconds: 2));
    expect(wallet.cards, hasLength(1));
    expect(find.text('•• 4821'), findsOneWidget);
  });
}
