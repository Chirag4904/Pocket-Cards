import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_cards/provider/card_provider.dart';
import 'package:provider/provider.dart';
import 'package:pocket_cards/main.dart'; // Import your main file

void main() {
  group('MyApp', () {
    testWidgets('renders MaterialApp', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (context) => CardProvider())
          ],
          child: MyApp(),
        ),
      );
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('renders BiometricAuthScreen as home', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (context) => CardProvider())
          ],
          child: MyApp(),
        ),
      );
      expect(find.byType(BiometricAuthScreen), findsOneWidget);
    });
  });
}