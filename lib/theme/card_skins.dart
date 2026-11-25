import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// A card's visual theme. Stored on the card as a short string id:
///   `grad:NAME`     preset gradient
///   `img:N`         bundled artwork (assets/cardBGN.jpg, N = 1..4)
///   `photo:FILE`    a gallery photo copied into the app's documents folder
class CardSkin {
  const CardSkin({
    required this.id,
    required this.label,
    required this.colors,
    required this.accent,
    this.image,
    this.glow,
  });

  final String id;
  final String label;

  /// Base gradient. For image skins this is the fallback / loading colour.
  final List<Color> colors;

  /// Used to tint UI around the card (detail glow, chips, buttons).
  final Color accent;

  /// Soft radial highlight painted in the top-right corner for depth.
  final Color? glow;

  final ImageProvider? image;

  bool get isImage => image != null;

  Gradient get gradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: colors,
      );
}

class CardSkins {
  CardSkins._();

  static const defaultId = 'grad:aurora';

  static const gradients = <CardSkin>[
    CardSkin(
      id: 'grad:aurora',
      label: 'Aurora',
      colors: [Color(0xFF1B2A6B), Color(0xFF5B3FD1), Color(0xFF10B5A4)],
      accent: Color(0xFF5EF0D6),
      glow: Color(0xFF7DF9E4),
    ),
    CardSkin(
      id: 'grad:sunset',
      label: 'Sunset',
      colors: [Color(0xFFFF4E6A), Color(0xFFFF7B54), Color(0xFFFFC46B)],
      accent: Color(0xFFFFA26B),
      glow: Color(0xFFFFE3A3),
    ),
    CardSkin(
      id: 'grad:mint',
      label: 'Mint',
      colors: [Color(0xFF0B7A6A), Color(0xFF15B58C), Color(0xFF8BF5B5)],
      accent: Color(0xFF6BF2B0),
      glow: Color(0xFFD4FFE6),
    ),
    CardSkin(
      id: 'grad:mono',
      label: 'Mono',
      colors: [Color(0xFF16181D), Color(0xFF2B2F38), Color(0xFF4A4F5A)],
      accent: Color(0xFFD8DCE6),
      glow: Color(0xFFFFFFFF),
    ),
    CardSkin(
      id: 'grad:candy',
      label: 'Candy',
      colors: [Color(0xFFFF5FA2), Color(0xFFB45CFF), Color(0xFF5C8BFF)],
      accent: Color(0xFFE08CFF),
      glow: Color(0xFFFFC2F0),
    ),
    CardSkin(
      id: 'grad:ember',
      label: 'Ember',
      colors: [Color(0xFF5A0D16), Color(0xFFB3261E), Color(0xFFFF5A4E)],
      accent: Color(0xFFFF7A6E),
      glow: Color(0xFFFFB3A1),
    ),
  ];

  static const _imageAccents = [
    Color(0xFF8FB8FF),
    Color(0xFFFF9A8B),
    Color(0xFFB9A4FF),
    Color(0xFF7FE0FF),
  ];

  static List<CardSkin> get artwork => [
        for (var i = 1; i <= 4; i++)
          CardSkin(
            id: 'img:$i',
            label: 'Art $i',
            colors: const [Color(0xFF1B1F2A), Color(0xFF2B3040)],
            accent: _imageAccents[i - 1],
            image: ResizeImage(AssetImage('assets/cardBG$i.jpg'), width: 1000),
          ),
      ];

  /// Documents directory, resolved once at startup. Photo skins store only a
  /// file name because the iOS container path changes between app updates.
  static String? _docsDir;

  static Future<void> init() async {
    try {
      _docsDir = (await getApplicationDocumentsDirectory()).path;
    } catch (_) {
      _docsDir = null; // e.g. tests: photo skins fall back to the default.
    }
  }

  static String? get photosDir =>
      _docsDir == null ? null : '$_docsDir/card_skins';

  static File? photoFile(String skinId) {
    if (!skinId.startsWith('photo:') || photosDir == null) return null;
    return File('$photosDir/${skinId.substring(6)}');
  }

  static final _photoSkins = <String, CardSkin>{};
  static final _artwork = artwork;

  static CardSkin resolve(String? id) {
    id ??= defaultId;
    if (id.startsWith('img:')) {
      final n = int.tryParse(id.substring(4)) ?? 0;
      if (n >= 1 && n <= 4) return _artwork[n - 1];
    }
    if (id.startsWith('photo:')) {
      final file = photoFile(id);
      // Memoised: this runs on every card rebuild, and a sync disk check per
      // card per rebuild is exactly what makes scrolling stutter.
      final cached = _photoSkins[id];
      if (cached != null) return cached;
      if (file != null && file.existsSync()) {
        return _photoSkins[id] = CardSkin(
          id: id,
          label: 'Photo',
          colors: const [Color(0xFF1B1F2A), Color(0xFF2B3040)],
          accent: const Color(0xFFE6E9F2),
          image: ResizeImage(FileImage(file), width: 1000),
        );
      }
    }
    return gradients.firstWhere((s) => s.id == id,
        orElse: () => gradients.first);
  }

  /// Maps the original `cardBG` index (0 = plain red) to a skin id.
  static String fromLegacy(String? cardBG) {
    final n = int.tryParse(cardBG ?? '0') ?? 0;
    return n >= 1 && n <= 4 ? 'img:$n' : 'grad:ember';
  }
}
