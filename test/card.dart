import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pocket_cards/CreditCardScreen.dart';
import 'package:pocket_cards/provider/card_provider.dart';
import 'package:pocket_cards/provider/wallet_provider.dart';

void main() {
  group('CreditCardScreen', () {
    testWidgets('renders with no cards', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (context) => CardProvider()),
            ChangeNotifierProvider(create: (context) => WalletProvider()),
          ],
          child: MaterialApp(home: CreditCardScreen()),
        ),
      );
      // Let the wallet finish loading (asset + storage I/O are real async).
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Add your first card'), findsOneWidget);
    });

    // testWidgets('renders with cards', (tester) async {
    //   final cardProvider = CardProvider();
    //   cardProvider.addCard(
    //     'Card Number',
    //     'Card Holder Name',
    //     'Expiry Date',
    //     'CVV',
    //     'Bank',
    //     'Card BG',
    //     100.0,
    //   );
    //
    //   await tester.pumpWidget(
    //     MultiProvider(
    //       providers: [
    //         ChangeNotifierProvider(create: (context) => cardProvider)
    //       ],
    //       child: MaterialApp(home: CreditCardScreen()),
    //     ),
    //   );
    //
    //   expect(find.byType(CreditCardUi), findsOneWidget);
    // });
    //
    // testWidgets('adds a new card', (tester) async {
    //   final cardProvider = CardProvider();
    //
    //   await tester.pumpWidget(
    //     MultiProvider(
    //       providers: [
    //         ChangeNotifierProvider(create: (context) => cardProvider)
    //       ],
    //       child: MaterialApp(home: CreditCardScreen()),
    //     ),
    //   );
    //
    //   await tester.tap(find.byIcon(Icons.add));
    //   await tester.pump();
    //
    //   await tester.enterText(find.byKey(Key('cardNumber')), '1234567890123456');
    //   await tester.enterText(find.byKey(Key('cardHolderName')), 'Card Holder Name');
    //   await tester.enterText(find.byKey(Key('expiryDate')), '12/25');
    //   await tester.enterText(find.byKey(Key('cvv')), '123');
    //   await tester.tap(find.byType(DropdownButtonFormField));
    //   await tester.tap(find.text('Select a bank').last);
    //
    //   await tester.tap(find.text('Add Card'));
    //   await tester.pump();
    //
    //   expect(cardProvider.cards.length, 1);
    // });
    //
    // testWidgets('deletes a card', (tester) async {
    //   final cardProvider = CardProvider();
    //   cardProvider.addCard(
    //     'Card Number',
    //     'Card Holder Name',
    //     'Expiry Date',
    //     'CVV',
    //     'Bank',
    //     'Card BG',
    //     100.0,
    //   );
    //
    //   await tester.pumpWidget(
    //     MultiProvider(
    //       providers: [
    //         ChangeNotifierProvider(create: (context) => cardProvider)
    //       ],
    //       child: MaterialApp(home: CreditCardScreen()),
    //     ),
    //   );
    //
    //   await tester.tap(find.byType(CreditCardUi));
    //   await tester.pump();
    //
    //   await tester.tap(find.byIcon(Icons.delete));
    //   await tester.tap(find.text('Delete'));
    //
    //   expect(cardProvider.cards.length, 0);
    // });
  });
}