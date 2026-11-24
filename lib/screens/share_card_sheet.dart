import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/wallet_card.dart';
import '../provider/wallet_provider.dart';
import '../services/app_services.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_kit.dart';
import '../widgets/wallet_card_view.dart';

Future<void> showShareCardSheet(BuildContext context, WalletCard card) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _ShareCardSheet(card: card),
  );
}

/// Plain-text version of a card, for "Copy details".
String cardDetailsText(WalletCard card) => [
      if (card.bank.isNotEmpty) card.bank,
      'Name: ${card.holder}',
      'Card number: ${card.formattedNumber}',
      'Expiry: ${card.expiry}',
      'CVV: ${card.cvv}',
    ].join('\n');

class _ShareCardSheet extends StatefulWidget {
  const _ShareCardSheet({required this.card});
  final WalletCard card;

  @override
  State<_ShareCardSheet> createState() => _ShareCardSheetState();
}

class _ShareCardSheetState extends State<_ShareCardSheet> {
  final _captureKey = GlobalKey();
  bool _full = true;
  bool _busy = false;

  Future<void> _shareImage() async {
    if (_busy) return;
    setState(() => _busy = true);
    File? file;
    try {
      final boundary =
          _captureKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      final dir = await getTemporaryDirectory();
      file = File('${dir.path}/card-${widget.card.last4}.png');
      await file.writeAsBytes(bytes!.buffer.asUint8List(), flush: true);
      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      Haptics.copy();
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path, mimeType: 'image/png')],
        sharePositionOrigin:
            box == null ? null : box.localToGlobal(Offset.zero) & box.size,
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't create the image")),
        );
      }
    } finally {
      // The share sheet has its own copy by now; don't leave card images lying around.
      try {
        await file?.delete();
      } catch (_) {}
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copyDetails() async {
    await SecureClipboard.copy(cardDetailsText(widget.card));
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Row(children: [
        Icon(Icons.check_circle_rounded, color: AppColors.lime, size: 20),
        SizedBox(width: 10),
        Expanded(child: Text('All details copied · clears in 30s')),
      ]),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final wallet = context.read<WalletProvider>();
    final data = CardFaceData.fromCard(widget.card, logoAsset: wallet.logoAssetFor(widget.card.bank));

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Expanded(child: Text('Share card', style: AppText.title)),
          GlassIconButton(icon: Icons.close_rounded, onTap: () => Navigator.pop(context)),
        ]),
        const SizedBox(height: 18),
        _Segmented(
          full: _full,
          onChanged: (v) {
            Haptics.tap();
            setState(() => _full = v);
          },
        ),
        const SizedBox(height: 16),
        RepaintBoundary(
          key: _captureKey,
          child: _ShareComposition(data: data, full: _full),
        ),
        const SizedBox(height: 14),
        AnimatedSwitcher(
          duration: AppMotion.medium,
          child: Row(
            key: ValueKey(_full),
            children: [
              Icon(_full ? Icons.warning_amber_rounded : Icons.shield_outlined,
                  size: 16, color: _full ? AppColors.pink : AppColors.lime),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _full
                      ? 'Includes the full number and CVV. Only send it to people you trust.'
                      : 'Number and CVV are hidden. Safe to share.',
                  style: AppText.mono.copyWith(fontSize: 11.5),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        GradientButton(
          label: _busy ? 'Preparing…' : 'Share image',
          icon: Icons.ios_share_rounded,
          onPressed: _shareImage,
        ),
        const SizedBox(height: 12),
        Pressable(
          onTap: _copyDetails,
          haptic: false,
          child: Container(
            height: 58,
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(29),
              border: Border.all(color: AppColors.strokeStrong),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.copy_all_rounded, color: AppColors.textPrimary, size: 20),
              const SizedBox(width: 10),
              Text('Copy all details', style: AppText.button.copyWith(color: AppColors.textPrimary)),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _Segmented extends StatelessWidget {
  const _Segmented({required this.full, required this.onChanged});
  final bool full;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget seg(String label, IconData icon, bool value) {
      final on = full == value;
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onChanged(value),
          child: AnimatedContainer(
            duration: AppMotion.fast,
            decoration: BoxDecoration(
              color: on ? AppColors.textPrimary : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, size: 16, color: on ? AppColors.ink : AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: on ? AppColors.ink : AppColors.textSecondary,
                  )),
            ]),
          ),
        ),
      );
    }

    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.stroke),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        seg('Full details', Icons.visibility_rounded, true),
        seg('Masked', Icons.visibility_off_rounded, false),
      ]),
    );
  }
}

/// What ends up in the PNG: front and back of the card on a branded backdrop.
class _ShareComposition extends StatelessWidget {
  const _ShareComposition({required this.data, required this.full});
  final CardFaceData data;
  final bool full;

  @override
  Widget build(BuildContext context) {
    final accent = data.skin.accent;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: RadialGradient(
          center: const Alignment(0, -0.6),
          radius: 1.2,
          colors: [accent.withValues(alpha: 0.28), AppColors.ink],
        ),
        border: Border.all(color: AppColors.stroke),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        WalletCardFace(data: data, revealed: full, shadow: false),
        const SizedBox(height: 14),
        WalletCardFace(data: data, revealed: full, back: true, shadow: false),
        const SizedBox(height: 14),
        Row(children: [
          Text('pocket', style: AppText.title.copyWith(fontSize: 18)),
          Text('.', style: AppText.title.copyWith(fontSize: 18, color: accent)),
          const Spacer(),
          Text(full ? 'card details' : 'masked card', style: AppText.mono.copyWith(fontSize: 11)),
        ]),
      ]),
    );
  }
}
