import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_cards/provider/card_provider.dart'; // Import your CardProvider class

void main() {
  group('CardProvider', () {
    late CardProvider provider;

    setUp(() {
      provider = CardProvider();
    });

    test('initial values are correct', () {
      expect(provider.cardNumber, '');
      expect(provider.expiryDate, '');
      expect(provider.cardHolderName, '');
      expect(provider.cvv, '');
      expect(provider.selectedBank, '');
      expect(provider.cardColor, '0xFFFF0000');
      expect(provider.cardBalance, 0);
      expect(provider.cardBG, 0);
    });

    test('setCardNumber updates the card number', () {
      provider.setCardNumber('1234 5678 9012 3456');
      expect(provider.cardNumber, '1234 5678 9012 3456');
    });

    test('setExpiryDate updates the expiry date', () {
      provider.setExpiryDate('12/2025');
      expect(provider.expiryDate, '12/2025');
    });

    test('setCardHolderName updates the card holder name', () {
      provider.setCardHolderName('John Doe');
      expect(provider.cardHolderName, 'John Doe');
    });

    test('setCVV updates the CVV', () {
      provider.setCVV('123');
      expect(provider.cvv, '123');
    });

    test('setSelectedBank updates the selected bank', () {
      provider.setSelectedBank('Bank of America');
      expect(provider.selectedBank, 'Bank of America');
    });

    test('setCardColor updates the card color', () {
      provider.setCardColor('0xFF0000FF');
      expect(provider.cardColor, '0xFF0000FF');
    });

    test('setCardBalance updates the card balance', () {
      provider.setCardBalance(100.0);
      expect(provider.cardBalance, 100.0);
    });

    test('setCardBG updates the card background', () {
      provider.setCardBG(1);
      expect(provider.cardBG, 1);
    });

    test('clearFields resets all fields to their initial values', () {
      provider.setCardNumber('1234 5678 9012 3456');
      provider.setExpiryDate('12/2025');
      provider.setCardHolderName('John Doe');
      provider.setCVV('123');
      provider.setSelectedBank('Bank of America');
      provider.setCardColor('0xFF0000FF');
      provider.setCardBalance(100.0);
      provider.setCardBG(1);

      provider.clearFields();

      expect(provider.cardNumber, '');
      expect(provider.expiryDate, '');
      expect(provider.cardHolderName, '');
      expect(provider.cvv, '');
      expect(provider.selectedBank, '');
      expect(provider.cardColor, '0xFFFF0000');
      expect(provider.cardBalance, 0);
      expect(provider.cardBG, 0);
    });
  });
}