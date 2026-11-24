import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_cards/models/wallet_card.dart';
import 'package:pocket_cards/provider/wallet_provider.dart';
import 'package:pocket_cards/services/backup_service.dart';

import 'wallet_test.dart' show FakeStorage, legacyCard;

void main() {
  final cards = [
    WalletCard.fromMap(legacyCard('4111111111114821'), fallbackId: 'a'),
    WalletCard.fromMap(legacyCard('5555555555554444', bg: '3'), fallbackId: 'b')
        .copyWith(pinned: true, logoStyle: LogoStyle.plain),
  ];

  test('encrypt then decrypt round-trips every field', () async {
    final file = await BackupService.encrypt(cards, 'correct horse');
    expect(file, isNot(contains('4111')), reason: 'no plaintext in the file');
    expect(jsonDecode(file)['format'], BackupService.format);

    final maps = await BackupService.decrypt(file, 'correct horse');
    expect(maps.map((m) => m['card_number']), ['4111111111114821', '5555555555554444']);
    expect(maps[1]['pinned'], 'true');
    expect(maps[1]['logo_style'], 'plain');
    expect(maps[1]['cvv'], '123');
  });

  test('wrong password, short password and junk files are rejected', () async {
    final file = await BackupService.encrypt(cards, 'correct horse');
    expect(() => BackupService.decrypt(file, 'wrong horse'), throwsA(isA<BackupException>()));
    expect(() => BackupService.encrypt(cards, '123'), throwsA(isA<BackupException>()));
    expect(() => BackupService.decrypt('{"hello":1}', 'x'), throwsA(isA<BackupException>()));
    expect(() => BackupService.decrypt('not json', 'x'), throwsA(isA<BackupException>()));

    final tampered = jsonDecode(file) as Map<String, dynamic>;
    final data = base64Decode(tampered['data'] as String);
    data[0] ^= 1;
    tampered['data'] = base64Encode(data);
    expect(() => BackupService.decrypt(jsonEncode(tampered), 'correct horse'),
        throwsA(isA<BackupException>()));
  });

  test('import skips cards already in the wallet', () async {
    final wallet = WalletProvider(storage: FakeStorage([legacyCard('4111111111114821')]));
    await wallet.load();
    final file = await BackupService.encrypt(cards, 'correct horse');
    final result = await wallet.importCards(await BackupService.decrypt(file, 'correct horse'));
    expect(result.added, 1);
    expect(result.skipped, 1);
    expect(wallet.cards, hasLength(2));
    expect(wallet.cards.first.last4, '4444', reason: 'imported pinned card sorts to the top');
  });
}
