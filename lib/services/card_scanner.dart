import 'dart:io' show Platform;
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';

import '../demo.dart';

/// What a contactless read can recover. The CVV is never on the chip, and
/// many cards no longer carry the holder's name either.
class ScannedCard {
  const ScannedCard({required this.number, this.expiry, this.holder});
  final String number; // digits only
  final String? expiry; // MM/YY
  final String? holder;
}

class CardScanException implements Exception {
  const CardScanException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Reads a bank card's number and expiry by tapping it on the phone (NFC).
///
/// Android only: iOS doesn't let third-party apps talk to payment cards.
/// The read is the same handshake a payment terminal starts with, but it stops
/// after reading the card's public records: nothing is charged, nothing is
/// sent anywhere, and nothing is stored until the user taps "Add to wallet".
class CardScanner {
  CardScanner._();

  /// Whether to offer scanning at all (the phone has NFC, even if it's off).
  static Future<bool> isSupported() async {
    if (kDemoMode) return true; // store screenshots, captured on a simulator
    if (!Platform.isAndroid) return false;
    try {
      return await FlutterNfcKit.nfcAvailability != NFCAvailability.not_supported;
    } catch (_) {
      return false;
    }
  }

  static Future<ScannedCard> scan({Duration timeout = const Duration(seconds: 30)}) async {
    if (kDemoMode) {
      await Future.delayed(const Duration(seconds: 6));
      return kDemoScannedCard;
    }
    final availability = await FlutterNfcKit.nfcAvailability;
    if (availability == NFCAvailability.disabled) {
      throw const CardScanException("NFC is turned off. Turn it on in your phone's settings, then try again.");
    }
    if (availability != NFCAvailability.available) {
      throw const CardScanException("This phone can't read cards over NFC.");
    }
    try {
      final tag = await FlutterNfcKit.poll(
        timeout: timeout,
        androidCheckNDEF: false,
        androidPlatformSound: false,
        readIso15693: false,
        readIso18092: false,
      );
      // Bank cards speak ISO-DEP; these tag types can't be one.
      const notBankCards = {
        NFCTagType.iso15693,
        NFCTagType.iso18092,
        NFCTagType.mifare_classic,
        NFCTagType.mifare_ultralight,
      };
      if (notBankCards.contains(tag.type)) {
        throw const CardScanException("That doesn't look like a bank card. Try the card you want to add.");
      }
      final reader = EmvReader((apdu) => FlutterNfcKit.transceive<Uint8List>(apdu));
      return await reader.read();
    } on CardScanException {
      rethrow;
    } on PlatformException catch (e) {
      debugPrint('NFC read failed: ${e.code} ${e.message}');
      if (e.code == '408') {
        throw const CardScanException('No card found. Hold the card flat against the back of your phone.');
      }
      if ('${e.message}'.toLowerCase().contains('lost')) {
        throw const CardScanException('The card moved away too soon. Hold it still for a second or two.');
      }
      throw const CardScanException(_unreadable);
    } catch (e) {
      debugPrint('NFC read failed: $e');
      throw const CardScanException(_unreadable);
    } finally {
      try {
        await FlutterNfcKit.finish();
      } catch (_) {}
    }
  }

  /// Stops waiting for a card (the user closed the scan sheet).
  static Future<void> cancel() async {
    if (kDemoMode) return;
    try {
      await FlutterNfcKit.finish();
    } catch (_) {}
  }

  static const _unreadable =
      "Couldn't read this card. Some banks block contactless reading, so enter the details by hand.";
}

/// EMV contactless read: select the payment app, get processing options,
/// then read the records that hold the card number and expiry.
///
/// Kept free of plugin calls so it can be tested with recorded responses.
class EmvReader {
  EmvReader(this._transceive, {Random? random}) : _random = random ?? Random.secure();

  final Future<Uint8List> Function(Uint8List apdu) _transceive;
  final Random _random;

  /// Common payment apps, tried when the card's directory (PPSE) is missing.
  static const fallbackAids = [
    'A0000000031010', // Visa
    'A0000000041010', // Mastercard
    'A0000005241010', // RuPay
    'A000000025010801', // American Express
    'A0000000043060', // Maestro
    'A0000000032010', // Visa Electron
    'A0000001523010', // Discover / Diners
    'A0000000651010', // JCB
  ];

  Future<ScannedCard> read() async {
    final aids = <String>[];
    final ppse = await _command(_select(ascii('2PAY.SYS.DDF01')));
    if (ppse != null) {
      for (final t in Tlv.findAll(Tlv.parse(ppse), 0x4F)) {
        aids.add(hex(t.value));
      }
    }
    for (final aid in fallbackAids) {
      if (!aids.contains(aid)) aids.add(aid);
    }

    for (final aid in aids) {
      final fci = await _command(_select(unhex(aid)));
      if (fci == null) continue;
      final found = _Found()..absorb(Tlv.parse(fci));

      final pdol = Tlv.find(Tlv.parse(fci), 0x9F38)?.value;
      final gpo = await _command(_gpo(pdol));
      var afl = Uint8List(0);
      if (gpo != null) {
        final tlvs = Tlv.parse(gpo);
        found.absorb(tlvs);
        final format1 = Tlv.find(tlvs, 0x80);
        if (format1 != null && format1.value.length > 2) {
          afl = format1.value.sublist(2); // AIP (2 bytes) then AFL
        } else {
          afl = Tlv.find(tlvs, 0x94)?.value ?? Uint8List(0);
        }
      }

      if (!found.complete) {
        for (final (sfi, record) in _recordsFor(afl)) {
          final data = await _command(_readRecord(sfi, record));
          if (data != null) found.absorb(Tlv.parse(data));
          if (found.complete) break;
        }
      }
      final card = found.toCard();
      if (card != null) return card;
    }
    throw const CardScanException(CardScanner._unreadable);
  }

  /// Records listed in the AFL; if there's none, the usual places to look.
  static Iterable<(int, int)> _recordsFor(Uint8List afl) sync* {
    if (afl.length >= 4) {
      for (var i = 0; i + 3 < afl.length; i += 4) {
        final sfi = afl[i] >> 3;
        for (var r = afl[i + 1]; r <= afl[i + 2]; r++) {
          yield (sfi, r);
        }
      }
      return;
    }
    for (var sfi = 1; sfi <= 4; sfi++) {
      for (var r = 1; r <= 4; r++) {
        yield (sfi, r);
      }
    }
  }

  /// Sends an APDU; returns the response data on 90 00, else null.
  Future<Uint8List?> _command(Uint8List apdu) async {
    var response = await _transceive(apdu);
    for (var tries = 0; tries < 4; tries++) {
      if (response.length < 2) return null;
      final sw1 = response[response.length - 2], sw2 = response[response.length - 1];
      if (sw1 == 0x90 && sw2 == 0x00) return response.sublist(0, response.length - 2);
      if (sw1 == 0x61) {
        response = await _transceive(Uint8List.fromList([0x00, 0xC0, 0x00, 0x00, sw2]));
      } else if (sw1 == 0x6C) {
        response = await _transceive(Uint8List.fromList([...apdu.sublist(0, apdu.length - 1), sw2]));
      } else {
        return null;
      }
    }
    return null;
  }

  static Uint8List _select(List<int> name) =>
      Uint8List.fromList([0x00, 0xA4, 0x04, 0x00, name.length, ...name, 0x00]);

  static Uint8List _readRecord(int sfi, int record) =>
      Uint8List.fromList([0x00, 0xB2, record, (sfi << 3) | 0x04, 0x00]);

  Uint8List _gpo(Uint8List? pdol) {
    final data = pdol == null ? <int>[] : _pdolData(pdol);
    return Uint8List.fromList([0x80, 0xA8, 0x00, 0x00, data.length + 2, 0x83, data.length, ...data, 0x00]);
  }

  /// Answers the card's data request (PDOL) like a basic terminal would.
  List<int> _pdolData(Uint8List pdol) {
    final now = DateTime.now();
    int bcd(int v) => ((v ~/ 10) << 4) | (v % 10);
    final known = <int, List<int>>{
      0x9F66: [0xB6, 0x20, 0xC0, 0x00], // terminal transaction qualifiers
      0x9F02: [0, 0, 0, 0, 0, 1], // amount: a token 0.01, nothing is charged
      0x9F03: [0, 0, 0, 0, 0, 0],
      0x9F1A: [0x03, 0x56], // terminal country: India
      0x5F2A: [0x03, 0x56], // currency: INR
      0x9A: [bcd(now.year % 100), bcd(now.month), bcd(now.day)],
      0x9F21: [bcd(now.hour), bcd(now.minute), bcd(now.second)],
      0x9C: [0x00],
      0x9F35: [0x22],
      0x9F37: [for (var i = 0; i < 4; i++) _random.nextInt(256)],
      0x9F4C: [for (var i = 0; i < 8; i++) _random.nextInt(256)],
    };
    final out = <int>[];
    var i = 0;
    while (i < pdol.length) {
      final (tag, next) = Tlv.readTag(pdol, i);
      if (next >= pdol.length) break;
      final len = pdol[next];
      i = next + 1;
      final value = known[tag] ?? const [];
      for (var k = 0; k < len; k++) {
        out.add(k < value.length ? value[k] : 0);
      }
    }
    return out;
  }
}

/// Collects card fields from whichever records hold them.
class _Found {
  String? pan;
  String? expiry;
  String? holder;

  bool get complete => pan != null && expiry != null;

  void absorb(List<Tlv> tlvs) {
    final pan5a = Tlv.find(tlvs, 0x5A);
    if (pan == null && pan5a != null) pan = _digits(hex(pan5a.value));

    final exp = Tlv.find(tlvs, 0x5F24);
    if (expiry == null && exp != null && exp.value.length >= 2) {
      final s = hex(exp.value); // YYMMDD
      expiry = _validExpiry(s.substring(2, 4), s.substring(0, 2));
    }

    for (final tag in const [0x57, 0x9F6B]) {
      final t2 = Tlv.find(tlvs, tag);
      if (t2 == null) continue;
      final s = hex(t2.value); // PAN 'D' YYMM ...
      final d = s.indexOf('D');
      if (d > 0) {
        pan ??= _digits(s.substring(0, d));
        if (expiry == null && s.length >= d + 5) {
          expiry = _validExpiry(s.substring(d + 3, d + 5), s.substring(d + 1, d + 3));
        }
      }
    }

    final t1 = Tlv.find(tlvs, 0x56); // "B" PAN "^" NAME "^" YYMM...
    if (t1 != null) {
      final parts = String.fromCharCodes(t1.value).split('^');
      if (parts.length >= 3) {
        pan ??= _digits(parts[0]);
        holder ??= _name(parts[1]);
        if (expiry == null && parts[2].length >= 4) {
          expiry = _validExpiry(parts[2].substring(2, 4), parts[2].substring(0, 2));
        }
      }
    }

    for (final tag in const [0x5F20, 0x9F0B]) {
      final n = Tlv.find(tlvs, tag);
      if (holder == null && n != null) holder = _name(String.fromCharCodes(n.value));
    }
  }

  ScannedCard? toCard() {
    final p = pan;
    if (p == null || p.length < 12 || p.length > 19) return null;
    return ScannedCard(number: p, expiry: expiry, holder: holder);
  }

  static String _digits(String s) => s.replaceAll(RegExp(r'[^0-9]'), '');

  static String? _validExpiry(String mm, String yy) {
    final m = int.tryParse(mm);
    if (m == null || m < 1 || m > 12 || int.tryParse(yy) == null) return null;
    return '$mm/$yy';
  }

  /// "MEHTA/AARAV " -> "Aarav Mehta". Placeholder names are ignored.
  static String? _name(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[^A-Za-z /.\-]'), '').trim();
    if (cleaned.isEmpty || cleaned == '/' || RegExp(r'CARD ?HOLDER|VALUED|CUSTOMER', caseSensitive: false).hasMatch(cleaned)) {
      return null;
    }
    final parts = cleaned.split('/').map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
    final ordered = parts.length == 2 ? '${parts[1]} ${parts[0]}' : parts.join(' ');
    final words = ordered.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    final name = words.map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase()).join(' ');
    return name.isEmpty ? null : name;
  }
}

/// Minimal BER-TLV, enough for EMV card responses.
class Tlv {
  Tlv(this.tag, this.value, this.children);
  final int tag;
  final Uint8List value;
  final List<Tlv> children;

  static (int tag, int next) readTag(Uint8List b, int i) {
    var tag = b[i];
    var j = i + 1;
    if ((b[i] & 0x1F) == 0x1F) {
      while (j < b.length) {
        final byte = b[j++];
        tag = (tag << 8) | byte;
        if ((byte & 0x80) == 0) break;
      }
    }
    return (tag, j);
  }

  static List<Tlv> parse(Uint8List b) {
    final out = <Tlv>[];
    var i = 0;
    while (i < b.length) {
      if (b[i] == 0x00 || b[i] == 0xFF) {
        i++; // padding between objects
        continue;
      }
      final constructed = (b[i] & 0x20) != 0;
      final (tag, afterTag) = readTag(b, i);
      if (afterTag >= b.length) break;
      var len = b[afterTag];
      var p = afterTag + 1;
      if (len & 0x80 != 0) {
        final n = len & 0x7F;
        if (n == 0 || n > 3 || p + n > b.length) break;
        len = 0;
        for (var k = 0; k < n; k++) {
          len = (len << 8) | b[p++];
        }
      }
      if (p + len > b.length) break; // truncated: stop rather than misread
      final value = Uint8List.sublistView(b, p, p + len);
      out.add(Tlv(tag, value, constructed ? parse(value) : const []));
      i = p + len;
    }
    return out;
  }

  static Tlv? find(List<Tlv> tlvs, int tag) {
    for (final t in tlvs) {
      if (t.tag == tag) return t;
      final inner = find(t.children, tag);
      if (inner != null) return inner;
    }
    return null;
  }

  static Iterable<Tlv> findAll(List<Tlv> tlvs, int tag) sync* {
    for (final t in tlvs) {
      if (t.tag == tag) yield t;
      yield* findAll(t.children, tag);
    }
  }
}

String hex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join().toUpperCase();

Uint8List unhex(String s) => Uint8List.fromList([
      for (var i = 0; i + 1 < s.length; i += 2) int.parse(s.substring(i, i + 2), radix: 16),
    ]);

List<int> ascii(String s) => s.codeUnits;
