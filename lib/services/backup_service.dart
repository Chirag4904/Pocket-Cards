import 'dart:convert';
import 'dart:isolate';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

import '../models/wallet_card.dart';

class BackupException implements Exception {
  const BackupException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Password-protected backups. Everything happens on the device:
///
///   key  = PBKDF2-HMAC-SHA256(password, random 16-byte salt, [iterations])
///   file = AES-256-GCM(key, random 12-byte nonce, cards JSON)
///
/// GCM authenticates the data, so a wrong password or a tampered file fails
/// to decrypt instead of producing garbage.
class BackupService {
  BackupService._();

  static const format = 'pocketcards-backup';
  static const version = 1;
  static const fileExtension = 'pcbackup';
  static const iterations = 150000;
  static const minPasswordLength = 6;

  static final _aes = AesGcm.with256bits();

  /// Runs on a background isolate: ~150k HMAC rounds would otherwise freeze
  /// the UI for a second or so.
  static Future<SecretKey> _deriveKey(String password, List<int> salt, int iterations) async {
    if (iterations < 1 || iterations > 10000000) {
      throw const BackupException("That file isn't a Pocket Cards backup");
    }
    final bytes = await Isolate.run(() async {
      final kdf = Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: iterations, bits: 256);
      final key = await kdf.deriveKeyFromPassword(password: password, nonce: salt);
      return key.extractBytes();
    });
    return SecretKey(bytes);
  }

  static List<int> _random(int length) {
    final r = Random.secure();
    return List<int>.generate(length, (_) => r.nextInt(256));
  }

  /// Returns the backup file's contents (a small JSON envelope).
  static Future<String> encrypt(List<WalletCard> cards, String password) async {
    if (password.length < minPasswordLength) {
      throw const BackupException('Password must be at least $minPasswordLength characters');
    }
    final salt = _random(16);
    final nonce = _random(12);
    final key = await _deriveKey(password, salt, iterations);
    final plain = utf8.encode(jsonEncode({
      'cards': cards.map((c) => c.toMap()).toList(),
      'exported_at': DateTime.now().toUtc().toIso8601String(),
    }));
    final box = await _aes.encrypt(plain, secretKey: key, nonce: nonce);
    return const JsonEncoder.withIndent('  ').convert({
      'format': format,
      'version': version,
      'kdf': 'pbkdf2-hmac-sha256',
      'iterations': iterations,
      'cipher': 'aes-256-gcm',
      'salt': base64Encode(salt),
      'nonce': base64Encode(nonce),
      'mac': base64Encode(box.mac.bytes),
      'data': base64Encode(box.cipherText),
    });
  }

  /// Decrypts a backup's contents into raw card maps.
  static Future<List<Map<String, String>>> decrypt(String contents, String password) async {
    final Map<String, dynamic> env;
    try {
      env = jsonDecode(contents) as Map<String, dynamic>;
    } catch (_) {
      throw const BackupException("That file isn't a Pocket Cards backup");
    }
    if (env['format'] != format) {
      throw const BackupException("That file isn't a Pocket Cards backup");
    }
    if ((env['version'] as int? ?? 0) > version) {
      throw const BackupException('This backup was made by a newer version of the app');
    }
    try {
      final key = await _deriveKey(
        password,
        base64Decode(env['salt'] as String),
        env['iterations'] as int,
      );
      final plain = await _aes.decrypt(
        SecretBox(
          base64Decode(env['data'] as String),
          nonce: base64Decode(env['nonce'] as String),
          mac: Mac(base64Decode(env['mac'] as String)),
        ),
        secretKey: key,
      );
      final body = jsonDecode(utf8.decode(plain)) as Map<String, dynamic>;
      return (body['cards'] as List)
          .map((e) => Map<String, String>.from(e as Map))
          .toList();
    } on SecretBoxAuthenticationError {
      throw const BackupException('Wrong password, or the file is damaged');
    } on BackupException {
      rethrow;
    } catch (_) {
      throw const BackupException('Wrong password, or the file is damaged');
    }
  }
}
