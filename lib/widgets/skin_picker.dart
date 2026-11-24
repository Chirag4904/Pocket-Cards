import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/wallet_card.dart';
import '../services/app_services.dart';
import '../theme/app_theme.dart';
import '../theme/card_skins.dart';

/// Copies a gallery photo into the app's private documents folder and returns
/// its skin id, or null if the user cancelled. Nothing leaves the device.
Future<String?> pickPhotoSkin() async {
  final dir = CardSkins.photosDir;
  if (dir == null) return null;
  final picked = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: 1600,
    imageQuality: 88,
  );
  if (picked == null) return null;
  await Directory(dir).create(recursive: true);
  final name = 'skin_${DateTime.now().millisecondsSinceEpoch}.jpg';
  await File(picked.path).copy('$dir/$name');
  return 'photo:$name';
}

/// Horizontal swatch rail: your photo, bundled art, then gradients.
class SkinPicker extends StatefulWidget {
  const SkinPicker({super.key, required this.selected, required this.onChanged});

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  State<SkinPicker> createState() => _SkinPickerState();
}

class _SkinPickerState extends State<SkinPicker> {
  bool _picking = false;

  Future<void> _pickPhoto() async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final id = await pickPhotoSkin();
      if (id != null) widget.onChanged(id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open your photos')),
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final skins = [...CardSkins.gradients, ...CardSkins.artwork];
    final selectedIsPhoto = widget.selected.startsWith('photo:');

    return SizedBox(
      height: 86,
      child: ListView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        children: [
          _Swatch(
            label: 'Photo',
            selected: selectedIsPhoto,
            onTap: _pickPhoto,
            child: selectedIsPhoto
                ? _SkinFill(skin: CardSkins.resolve(widget.selected))
                : Container(
                    color: AppColors.surfaceHigh,
                    alignment: Alignment.center,
                    child: _picking
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add_photo_alternate_outlined,
                            color: AppColors.textSecondary, size: 22),
                  ),
          ),
          for (final skin in skins)
            _Swatch(
              label: skin.label,
              selected: widget.selected == skin.id,
              onTap: () => widget.onChanged(skin.id),
              child: _SkinFill(skin: skin),
            ),
        ],
      ),
    );
  }
}

class _SkinFill extends StatelessWidget {
  const _SkinFill({required this.skin});
  final CardSkin skin;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: skin.gradient,
          image: skin.image == null
              ? null
              : DecorationImage(image: skin.image!, fit: BoxFit.cover),
        ),
      );
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: () {
          Haptics.tap();
          onTap();
        },
        child: Column(children: [
          AnimatedScale(
            scale: selected ? 1.0 : 0.92,
            duration: AppMotion.medium,
            curve: AppMotion.spring,
            child: AnimatedContainer(
              duration: AppMotion.fast,
              width: 82,
              height: 54,
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: selected ? AppColors.brandGradient : null,
                color: selected ? null : AppColors.stroke,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(11.5),
                child: Stack(fit: StackFit.expand, children: [
                  child,
                  AnimatedOpacity(
                    opacity: selected ? 1 : 0,
                    duration: AppMotion.fast,
                    child: Container(
                      color: Colors.black26,
                      alignment: Alignment.center,
                      child: const Icon(Icons.check_rounded,
                          color: Colors.white, size: 22),
                    ),
                  ),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(label,
              style: AppText.label.copyWith(
                letterSpacing: 0.4,
                fontSize: 11,
                color: selected ? AppColors.textPrimary : AppColors.textTertiary,
              )),
        ]),
      ),
    );
  }
}

/// Three-way segmented choice for how the bank logo sits on the card.
class LogoStylePicker extends StatelessWidget {
  const LogoStylePicker({super.key, required this.selected, required this.onChanged});

  final LogoStyle selected;
  final ValueChanged<LogoStyle> onChanged;

  static const _icons = {
    LogoStyle.boxed: Icons.crop_square_rounded,
    LogoStyle.plain: Icons.image_outlined,
    LogoStyle.text: Icons.text_fields_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.stroke),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final style in LogoStyle.values)
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (style == selected) return;
                Haptics.tap();
                onChanged(style);
              },
              child: AnimatedContainer(
                duration: AppMotion.fast,
                decoration: BoxDecoration(
                  color: style == selected ? AppColors.textPrimary : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(_icons[style], size: 16,
                      color: style == selected ? AppColors.ink : AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Text(style.label,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: style == selected ? AppColors.ink : AppColors.textSecondary,
                      )),
                ]),
              ),
            ),
          ),
      ]),
    );
  }
}
