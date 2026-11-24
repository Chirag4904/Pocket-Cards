import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_cards/services/card_scanner.dart';

/// A fake contactless card: maps a command prefix (hex) to a response (hex,
/// including the status word). Unknown commands get 6A82 (not found).
class FakeCard {
  FakeCard(this.responses);
  final Map<String, String> responses;
  final sent = <String>[];

  Future<Uint8List> transceive(Uint8List apdu) async {
    final cmd = hex(apdu);
    sent.add(cmd);
    for (final e in responses.entries) {
      if (cmd.startsWith(e.key)) return unhex(e.value);
    }
    return unhex('6A82');
  }
}

String tlv(String tag, String valueHex) {
  final len = valueHex.length ~/ 2;
  final l = len < 0x80 ? len.toRadixString(16).padLeft(2, '0') : '81${len.toRadixString(16).padLeft(2, '0')}';
  return '$tag$l$valueHex'.toUpperCase();
}

String asciiHex(String s) => hex(s.codeUnits);

const selectPpse = '00A404000E325041592E5359532E444446303100';
String selectAid(String aid) => '00A40400${(aid.length ~/ 2).toRadixString(16).padLeft(2, '0')}$aid'.toUpperCase();

void main() {
  test('Visa-style: number and expiry come back in the GPO response', () async {
    const aid = 'A0000000031010';
    final card = FakeCard({
      selectPpse: tlv('6F', tlv('84', asciiHex('2PAY.SYS.DDF01')) +
              tlv('A5', tlv('BF0C', tlv('61', tlv('4F', aid) + tlv('87', '01'))))) +
          '9000',
      selectAid(aid): tlv('6F', tlv('84', aid) +
              tlv('A5', tlv('50', asciiHex('VISA DEBIT')) + tlv('9F38', '9F66049F02069F37045F2A02'))) +
          '9000',
      // Track 2 equivalent: PAN D YYMM service-code ...
      '80A80000': tlv('77', tlv('82', '2000') + tlv('57', '4111111111111111D29082010000000000000F') +
              tlv('5F20', asciiHex('MEHTA/AARAV '))) +
          '9000',
    });
    final result = await EmvReader(card.transceive, random: Random(1)).read();
    expect(result.number, '4111111111111111');
    expect(result.expiry, '08/29');
    expect(result.holder, 'Aarav Mehta');
    // PDOL asks for 4+6+4+2 = 16 bytes; the GPO must carry exactly that.
    final gpo = card.sent.firstWhere((c) => c.startsWith('80A8'));
    expect(gpo.substring(8, 14), '128310'); // Lc=18, tag 83, length 16
    expect(gpo.substring(14, 22), 'B620C000'); // terminal qualifiers first
  });

  test('Mastercard-style: details read from the records the AFL points to', () async {
    const aid = 'A0000000041010';
    final card = FakeCard({
      selectPpse: tlv('6F', tlv('A5', tlv('BF0C', tlv('61', tlv('4F', aid))))) + '9000',
      selectAid(aid): tlv('6F', tlv('84', aid) + tlv('A5', tlv('50', asciiHex('MASTERCARD')))) + '9000',
      // Format 1: AIP 1980, AFL: SFI 1 record 1, SFI 2 records 1-2.
      '80A80000028300': tlv('80', '1980' '08010100' '10010200') + '9000',
      '00B2010C': tlv('70', tlv('9F6C', '0001')) + '9000',
      '00B20114': tlv('70', tlv('5A', '5555444433332222') + tlv('5F24', '300531') +
              tlv('5F20', asciiHex('CARDHOLDER/VISA'))) +
          '9000',
    });
    final result = await EmvReader(card.transceive).read();
    expect(result.number, '5555444433332222');
    expect(result.expiry, '05/30');
    expect(result.holder, isNull, reason: 'placeholder names are dropped');
    expect(card.sent.where((c) => c.startsWith('00B2')).length, 2,
        reason: 'stops reading once number and expiry are found');
  });

  test('no PPSE: falls back to known payment apps and odd-length PAN padding', () async {
    const aid = 'A0000005241010'; // RuPay
    final card = FakeCard({
      selectAid(aid): tlv('6F', tlv('84', aid)) + '9000',
      '80A80000': tlv('77', tlv('94', '08010100')) + '9000',
      '00B2010C': tlv('70', tlv('5A', '6521234567890123456F') + tlv('5F24', '271231')) + '9000',
    });
    final result = await EmvReader(card.transceive).read();
    expect(result.number, '6521234567890123456');
    expect(result.expiry, '12/27');
  });

  test('61xx responses are fetched with GET RESPONSE', () async {
    const aid = 'A0000000031010';
    final full = tlv('77', tlv('57', '4111111111111111D2512F')) + '9000';
    final card = FakeCard({
      selectAid(aid): tlv('6F', tlv('84', aid)) + '9000',
      '80A80000': '61${(full.length ~/ 2 - 2).toRadixString(16).padLeft(2, '0')}',
      '00C00000': full,
    });
    final result = await EmvReader(card.transceive).read();
    expect(result.number, '4111111111111111');
    expect(result.expiry, '12/25');
  });

  test('a card that answers nothing useful raises a friendly error', () async {
    final card = FakeCard({});
    expect(
      () => EmvReader(card.transceive).read(),
      throwsA(isA<CardScanException>().having((e) => e.message, 'message', contains('enter the details'))),
    );
  });

  test('TLV parser handles multi-byte tags, long lengths and padding', () {
    final bytes = unhex('${tlv('9F38', '9F6604')}00FF${tlv('70', tlv('5F20', asciiHex('A' * 130)))}');
    final parsed = Tlv.parse(bytes);
    expect(Tlv.find(parsed, 0x9F38)!.value, unhex('9F6604'));
    expect(String.fromCharCodes(Tlv.find(parsed, 0x5F20)!.value), 'A' * 130);
  });

  test('truncated data does not throw', () {
    expect(Tlv.parse(unhex('5A08411111')), isEmpty);
  });
}
