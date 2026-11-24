import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../demo.dart';
import '../models/wallet_card.dart';
import '../secure_card_service.dart';
import '../services/bill_reminders.dart';
import '../theme/card_skins.dart';

/// Owns the list of saved cards. Every mutation is written straight back to
/// secure storage; pinned cards are always kept at the top (stable order).
class WalletProvider extends ChangeNotifier {
  WalletProvider({SecureStorageService? storage})
      : _storage = storage ?? SecureStorageService();

  final SecureStorageService _storage;

  List<WalletCard> _cards = [];
  Map<String, String> _bankCodes = {};
  bool _loaded = false;

  List<WalletCard> get cards => List.unmodifiable(_cards);
  bool get isLoaded => _loaded;
  Map<String, String> get bankCodes => _bankCodes;
  double get totalLimit => _cards.fold(0, (sum, c) => sum + c.limit);

  String? logoAssetFor(String bank) {
    final code = _bankCodes[bank];
    return code == null ? null : 'assets/bank_logos/$code.png';
  }

  Future<void> load() async {
    try {
      final raw = await rootBundle.loadString('assets/bank_mapping.json');
      _bankCodes = Map<String, String>.from(json.decode(raw) as Map);
    } catch (e) {
      debugPrint('Bank mapping not loaded: $e');
    }

    if (kDemoMode) {
      _cards = [...kDemoCards];
      _loaded = true;
      notifyListeners();
      return;
    }

    try {
      final stored = await _storage.getCards();
      var migrated = false;
      _cards = [
        for (var i = 0; i < stored.length; i++)
          () {
            if (stored[i]['id'] == null || stored[i]['theme'] == null) {
              migrated = true;
            }
            return WalletCard.fromMap(stored[i], fallbackId: _newId(i));
          }(),
      ];
      _sortPinned();
      if (migrated) await _persist();
      BillReminders.sync(_cards); // refresh the queue on every launch
    } catch (e) {
      debugPrint('Cards not loaded: $e');
      _cards = [];
    }
    _loaded = true;
    notifyListeners();
  }

  WalletCard? byId(String id) {
    for (final c in _cards) {
      if (c.id == id) return c;
    }
    return null;
  }

  Future<WalletCard> add({
    required String number,
    required String holder,
    required String expiry,
    required String cvv,
    required String bank,
    required String skinId,
    required double limit,
    LogoStyle logoStyle = LogoStyle.boxed,
    int? billDay,
    int? remindDaysBefore,
  }) async {
    final card = WalletCard(
      id: _newId(_cards.length),
      number: number,
      holder: holder,
      expiry: expiry,
      cvv: cvv,
      bank: bank,
      skinId: skinId,
      limit: limit,
      logoStyle: logoStyle,
      billDay: billDay,
      remindDaysBefore: billDay == null ? null : remindDaysBefore,
    );
    _cards.add(card);
    _sortPinned();
    notifyListeners();
    await _persist();
    return card;
  }

  /// Removes a card and returns it with its position, for undo.
  Future<(WalletCard, int)?> remove(String id) async {
    final index = _cards.indexWhere((c) => c.id == id);
    if (index < 0) return null;
    final card = _cards.removeAt(index);
    notifyListeners();
    await _persist();
    return (card, index);
  }

  Future<void> restore(WalletCard card, int index) async {
    if (byId(card.id) != null) return;
    _cards.insert(index.clamp(0, _cards.length), card);
    _sortPinned();
    notifyListeners();
    await _persist();
  }

  /// Deletes a removed card's copied photo once undo is no longer possible.
  Future<void> purgeAssets(WalletCard card) async {
    if (byId(card.id) != null) return;
    try {
      final file = CardSkins.photoFile(card.skinId);
      if (file != null && await file.exists()) await file.delete();
    } catch (_) {}
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;
    final card = _cards.removeAt(oldIndex);
    _cards.insert(newIndex, card);
    _sortPinned();
    notifyListeners();
    await _persist();
  }

  Future<void> togglePin(String id) async {
    final i = _cards.indexWhere((c) => c.id == id);
    if (i < 0) return;
    final card = _cards.removeAt(i);
    final updated = card.copyWith(pinned: !card.pinned);
    // Newly pinned cards jump to the end of the pinned group; unpinned cards
    // drop to the top of the rest.
    final pinnedCount = _cards.where((c) => c.pinned).length;
    _cards.insert(pinnedCount, updated);
    notifyListeners();
    await _persist();
  }

  /// Merges cards from a backup. Cards whose number is already in the wallet
  /// are skipped. Returns how many were added and skipped.
  Future<({int added, int skipped})> importCards(List<Map<String, String>> maps) async {
    final existing = _cards.map((c) => c.digits).toSet();
    final ids = _cards.map((c) => c.id).toSet();
    var added = 0, skipped = 0;
    for (var i = 0; i < maps.length; i++) {
      var card = WalletCard.fromMap(maps[i], fallbackId: _newId(i));
      if (card.digits.isEmpty || existing.contains(card.digits)) {
        skipped++;
        continue;
      }
      if (ids.contains(card.id)) {
        card = WalletCard.fromMap({...maps[i], 'id': _newId(i + 1000)}, fallbackId: _newId(i));
      }
      _cards.add(card);
      existing.add(card.digits);
      ids.add(card.id);
      added++;
    }
    if (added > 0) {
      _sortPinned();
      notifyListeners();
      await _persist();
    }
    return (added: added, skipped: skipped);
  }

  Future<void> updateLogoStyle(String id, LogoStyle style) async {
    final i = _cards.indexWhere((c) => c.id == id);
    if (i < 0) return;
    _cards[i] = _cards[i].copyWith(logoStyle: style);
    notifyListeners();
    await _persist();
  }

  Future<void> updateBilling(String id, {required int? billDay, required int? remindDaysBefore}) async {
    final i = _cards.indexWhere((c) => c.id == id);
    if (i < 0) return;
    _cards[i] = _cards[i].withBilling(billDay: billDay, remindDaysBefore: remindDaysBefore);
    notifyListeners();
    await _persist();
  }

  Future<void> updateSkin(String id, String skinId) async {
    final i = _cards.indexWhere((c) => c.id == id);
    if (i < 0) return;
    final old = _cards[i];
    _cards[i] = old.copyWith(skinId: skinId);
    notifyListeners();
    await _persist();
    if (old.skinId != skinId && old.skinId.startsWith('photo:')) {
      try {
        await CardSkins.photoFile(old.skinId)?.delete();
      } catch (_) {}
    }
  }

  void _sortPinned() {
    final pinned = _cards.where((c) => c.pinned).toList();
    final rest = _cards.where((c) => !c.pinned).toList();
    _cards = [...pinned, ...rest];
  }

  Future<void> _persist() async {
    if (kDemoMode) return; // demo cards live in memory only
    try {
      await _storage.saveCards(_cards.map((c) => c.toMap()).toList());
      BillReminders.sync(_cards);
    } catch (e) {
      debugPrint('Cards not saved: $e');
    }
  }

  static String _newId(int salt) =>
      '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}$salt';
}
