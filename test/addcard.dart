import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_cards/provider/card_provider.dart'; // Import your CardProvider class
import 'package:pocket_cards/CreditCardScreen.dart';
import 'package:pocket_cards/secure_card_service.dart'; // Import your CreditCardScreen class

void main() {
  group('Add Card', () {
    late CardProvider provider;
    late FlutterSecureStorage storage;

    setUp(() {
      provider = CardProvider();
      storage = FlutterSecureStorage();
    });

    tearDown(() async {
      await storage.deleteAll();
    });

    test('add card stores card data securely', () async {
      // Set up the card data
      provider.setCardNumber('1234 5678 9012 3456');
      provider.setExpiryDate('12/2025');
      provider.setCardHolderName('John Doe');
      provider.setCVV('123');
      provider.setSelectedBank('Bank of America');
      provider.setCardColor('0xFF0000FF');
      provider.setCardBalance(100.0);
      provider.setCardBG(1);

      final SecureStorageService _storageService = SecureStorageService();


      // Add the card
      // await provider.addCard(storage);
      await _storageService.addCard(provider.cardNumber, provider.cardHolderName, provider.expiryDate,
          provider.cvv, provider.selectedBank, provider.cardBG.toString(), provider.cardBalance);

      // Verify that the card data is stored securely
      expect(await storage.read(key: 'card_number'), '1234 5678 9012 3456');
      expect(await storage.read(key: 'expiry_date'), '12/2025');
      expect(await storage.read(key: 'card_holder_name'), 'John Doe');
      expect(await storage.read(key: 'cvv'), '123');
      expect(await storage.read(key: 'selected_bank'), 'Bank of America');
      expect(await storage.read(key: 'card_color'), '0xFF0000FF');
      expect(await storage.read(key: 'card_balance'), '100.0');
      expect(await storage.read(key: 'card_bg'), '1');
    });
  });
}