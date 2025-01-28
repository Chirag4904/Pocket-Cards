import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

class SecureStorageService {
  final _storage = FlutterSecureStorage();

  // Save a new card
  Future<void> addCard(String number, String holder, String expiry, String cvv,String bank,String cardBG,double card_balance) async {
    List<Map<String, String>> cards = await getCards();
    final newCard = {
      'card_number': number,
      'card_holder_name': holder,
      'expiry_date': expiry,
      'cvv': cvv,
      'bank': bank,
      'cardBG': cardBG,
      'card_balance': card_balance.toString(),
    };
    cards.add(newCard);
    await _storage.write(key: 'cards', value: jsonEncode(cards));
  }

  // Fetch all cards
  Future<List<Map<String, String>>> getCards() async {
    final data = await _storage.read(key: 'cards');
    if (data == null) return [];

    List<dynamic> decodedData = jsonDecode(data);
    return decodedData.map((e) => Map<String, String>.from(e)).toList();
  }

  // Delete a card by index
  Future<void> deleteCard(int index) async {
    List<Map<String, String>> cards = await getCards();
    cards.removeAt(index);
    await _storage.write(key: 'cards', value: jsonEncode(cards));
  }
}
