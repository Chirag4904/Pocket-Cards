import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_cards/CreditCardScreen.dart';
import 'package:pocket_cards/provider/card_provider.dart';
import 'package:pocket_cards/provider/wallet_provider.dart';
import 'package:pocket_cards/theme/app_theme.dart';
import 'package:pocket_cards/theme/card_skins.dart';
import 'package:pocket_cards/widgets/wallet_card_view.dart';
import 'package:provider/provider.dart';

import 'wallet_test.dart' show FakeStorage, legacyCard;

void main() {
  testWidgets('pulling the list down fans the stack apart, then it settles', (tester) async {
    final wallet = WalletProvider(storage: FakeStorage([
      legacyCard('4111111111110001'),
      legacyCard('4111111111110002'),
      legacyCard('4111111111110003'),
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

    double gap() =>
        tester.getTopLeft(find.text('•• 0002')).dy - tester.getTopLeft(find.text('•• 0001')).dy;
    final resting = gap();

    final g = await tester.startGesture(const Offset(200, 300));
    for (var i = 0; i < 10; i++) {
      await g.moveBy(const Offset(0, 30));
      await tester.pump(const Duration(milliseconds: 16));
    }
    final stretched = gap();
    expect(stretched, greaterThan(resting * 1.4), reason: 'cards fan apart on overscroll');

    await g.up();
    for (var i = 0; i < 120; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(gap(), moreOrLessEquals(resting, epsilon: 0.5), reason: 'stack settles back');
  });

  testWidgets('card leans towards the finger and springs back', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Center(
        child: SizedBox(
          width: 340,
          child: InteractiveCard(
            tilt: false,
            revealed: false,
            flipped: false,
            data: CardFaceData(
              skin: CardSkins.resolve(null),
              digits: '4111111111111111',
              holder: 'Test',
              expiry: '09/29',
              cvv: '123',
            ),
          ),
        ),
      ),
    ));

    Matrix4 outer() => tester
        .widgetList<Transform>(find.descendant(
            of: find.byType(InteractiveCard), matching: find.byType(Transform)))
        .first
        .transform;
    final rest = outer().clone();

    final centre = tester.getCenter(find.byType(InteractiveCard));
    final g = await tester.startGesture(centre + const Offset(150, 0));
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(outer(), isNot(equals(rest)), reason: 'tilted while pressed');

    await g.up();
    for (var i = 0; i < 180; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final settled = outer();
    for (var i = 0; i < 16; i++) {
      expect(settled.storage[i], moreOrLessEquals(rest.storage[i], epsilon: 0.002));
    }
  });
}
