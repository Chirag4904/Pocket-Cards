import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/wallet_card.dart';
import '../provider/wallet_provider.dart';
import '../services/app_services.dart';
import '../theme/app_theme.dart';
import '../theme/card_skins.dart';
import '../services/bill_reminders.dart';
import '../widgets/bill_reminder_picker.dart';
import '../widgets/skin_picker.dart';
import 'share_card_sheet.dart';
import '../widgets/ui_kit.dart';
import '../widgets/wallet_card_view.dart';

/// The "lifted" card: tilt, flip, hold-to-peek, and per-field copy.
class CardDetailScreen extends StatefulWidget {
  const CardDetailScreen({super.key, required this.cardId});
  final String cardId;

  @override
  State<CardDetailScreen> createState() => _CardDetailScreenState();
}

class _CardDetailScreenState extends State<CardDetailScreen> {
  bool _flipped = false;
  bool _revealed = false; // toggled with the eye button
  bool _peeking = false; // true while the card is held down

  bool get _showDetails => _revealed || _peeking;

  void _toast(String text) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      duration: const Duration(seconds: 2),
      content: Row(children: [
        const Icon(Icons.check_circle_rounded, color: AppColors.lime, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ]),
    ));
  }

  Future<void> _copy(String label, String value) async {
    await SecureClipboard.copy(value);
    _toast('$label copied · clears in 30s');
  }

  Future<void> _editReminder(WalletCard card) async {
    final wallet = context.read<WalletProvider>();
    Haptics.tap();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Bill reminder', style: AppText.title),
            const SizedBox(height: 6),
            const Text('Optional. Get a nudge before this card\'s monthly bill.', style: AppText.body),
            const SizedBox(height: 18),
            Consumer<WalletProvider>(
              builder: (context, w, _) {
                final current = w.byId(card.id) ?? card;
                return BillReminderPicker(
                  billDay: current.billDay,
                  remindDaysBefore: current.remindDaysBefore,
                  onChanged: (day, lead) =>
                      wallet.updateBilling(card.id, billDay: day, remindDaysBefore: lead),
                  previewCard: () => w.byId(card.id) ?? current,
                );
              },
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _changeLook(WalletCard card) async {
    final wallet = context.read<WalletProvider>();
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Change the look', style: AppText.title),
          const SizedBox(height: 18),
          Consumer<WalletProvider>(
            builder: (context, w, _) {
              final current = w.byId(card.id) ?? card;
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SectionLabel('Background'),
                SkinPicker(
                  selected: current.skinId,
                  onChanged: (id) => wallet.updateSkin(card.id, id),
                ),
                if (w.logoAssetFor(card.bank) != null) ...[
                  const SizedBox(height: 18),
                  const SectionLabel('Logo on card'),
                  LogoStylePicker(
                    selected: current.logoStyle,
                    onChanged: (s) => wallet.updateLogoStyle(card.id, s),
                  ),
                ],
              ]);
            },
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletProvider>();
    final card = wallet.byId(widget.cardId);
    if (card == null) {
      return const Scaffold(body: SizedBox.shrink());
    }
    final skin = CardSkins.resolve(card.skinId);
    final data = CardFaceData.fromCard(card, logoAsset: wallet.logoAssetFor(card.bank));

    return Scaffold(
      body: Stack(children: [
        Positioned(
          top: -80,
          left: 0,
          right: 0,
          child: Center(
            child: TweenAnimationBuilder<Color?>(
              tween: ColorTween(end: skin.accent),
              duration: AppMotion.slow,
              builder: (context, c, _) => GlowOrb(color: c!, size: 520, opacity: 0.32),
            ),
          ),
        ),
        SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                GlassIconButton(
                  icon: Icons.arrow_back_rounded,
                  onTap: () => Navigator.pop(context),
                ),
                Expanded(
                  child: Column(children: [
                    Text(card.bank.isEmpty ? 'Card' : card.bank,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.button.copyWith(color: AppColors.textPrimary)),
                    const SizedBox(height: 2),
                    Text('•• ${card.last4}', style: AppText.label.copyWith(letterSpacing: 1)),
                  ]),
                ),
                GlassIconButton(
                  icon: Icons.ios_share_rounded,
                  tooltip: 'Share',
                  onTap: () => showShareCardSheet(context, card),
                ),
                const SizedBox(width: 8),
                GlassIconButton(
                  icon: card.pinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                  active: card.pinned,
                  tooltip: card.pinned ? 'Unpin' : 'Pin to top',
                  onTap: () {
                    wallet.togglePin(card.id);
                    _toast(card.pinned ? 'Unpinned' : 'Pinned to the top');
                  },
                ),
              ]),
              const SizedBox(height: 28),
              GestureDetector(
                onTap: () {
                  Haptics.flip();
                  setState(() => _flipped = !_flipped);
                },
                onLongPressStart: (_) {
                  Haptics.copy();
                  setState(() => _peeking = true);
                },
                onLongPressEnd: (_) => setState(() => _peeking = false),
                onLongPressCancel: () => setState(() => _peeking = false),
                child: Hero(
                  tag: 'card-${card.id}',
                  flightShuttleBuilder: cardFlightShuttle,
                  child: InteractiveCard(
                    introSweep: true,
                    data: data,
                    revealed: _showDetails,
                    flipped: _flipped,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Entrance(
                delay: Duration(milliseconds: 250),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.touch_app_outlined, size: 14, color: AppColors.textTertiary),
                  SizedBox(width: 6),
                  Text('tap to flip · hold to peek', style: AppText.mono),
                ]),
              ),
              const SizedBox(height: 24),
              Entrance(
                delay: const Duration(milliseconds: 180),
                child: _RevealToggle(
                  revealed: _revealed,
                  accent: skin.accent,
                  onChanged: (v) {
                    Haptics.tap();
                    setState(() => _revealed = v);
                  },
                ),
              ),
              const SizedBox(height: 14),
              Entrance(
                delay: const Duration(milliseconds: 240),
                child: _CopyTile(
                  label: 'Card number',
                  display: _showDetails ? card.formattedNumber : card.maskedNumber,
                  accent: skin.accent,
                  onCopy: () => _copy('Card number', card.digits),
                ),
              ),
              const SizedBox(height: 12),
              Entrance(
                delay: const Duration(milliseconds: 300),
                child: Row(children: [
                  Expanded(
                    child: _CopyTile(
                      label: 'Expiry',
                      display: card.expiry,
                      accent: skin.accent,
                      onCopy: () => _copy('Expiry', card.expiry),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _CopyTile(
                      label: 'CVV',
                      display: _showDetails ? card.cvv : '•••',
                      accent: skin.accent,
                      onCopy: () => _copy('CVV', card.cvv),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 12),
              Entrance(
                delay: const Duration(milliseconds: 360),
                child: Row(children: [
                  Expanded(
                    child: _InfoTile(
                      label: 'Card limit',
                      value: card.limit > 0 ? formatInr(card.limit) : 'Not set',
                      muted: card.limit <= 0,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Pressable(
                      onTap: () => _changeLook(card),
                      child: _InfoTile(
                        label: 'Look',
                        value: skin.label,
                        trailing: Container(
                          width: 34,
                          height: 22,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            gradient: skin.gradient,
                            image: skin.image == null
                                ? null
                                : DecorationImage(image: skin.image!, fit: BoxFit.cover),
                            border: Border.all(color: AppColors.strokeStrong),
                          ),
                        ),
                      ),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 12),
              Entrance(
                delay: const Duration(milliseconds: 420),
                child: Pressable(
                  onTap: () => _editReminder(card),
                  child: _InfoTile(
                    label: 'Bill reminder',
                    value: card.billDay == null
                        ? 'Add a bill date'
                        : 'Bill on the ${BillReminders.ordinal(card.billDay!)}'
                            '${card.hasReminder ? ' · ${BillReminders.leadLabel(card.remindDaysBefore!).toLowerCase()}' : ' · no reminder'}',
                    muted: card.billDay == null,
                    trailing: Icon(
                      card.hasReminder
                          ? Icons.notifications_active_outlined
                          : Icons.notifications_none_rounded,
                      size: 20,
                      color: card.hasReminder ? AppColors.lime : AppColors.textTertiary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'copied details are wiped from your clipboard after 30s',
                textAlign: TextAlign.center,
                style: AppText.mono,
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _RevealToggle extends StatelessWidget {
  const _RevealToggle({required this.revealed, required this.accent, required this.onChanged});
  final bool revealed;
  final Color accent;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!revealed),
      child: Container(
        height: 52,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: AppColors.stroke),
        ),
        child: LayoutBuilder(builder: (context, c) {
          final half = c.maxWidth / 2;
          return Stack(children: [
            AnimatedPositioned(
              duration: AppMotion.medium,
              curve: AppMotion.emphasized,
              left: revealed ? half : 0,
              top: 0,
              bottom: 0,
              width: half,
              child: Container(
                decoration: BoxDecoration(
                  color: revealed ? accent.withValues(alpha: 0.18) : AppColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: revealed ? accent.withValues(alpha: 0.5) : AppColors.strokeStrong,
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Row(children: [
                _seg(Icons.visibility_off_rounded, 'Hidden', !revealed, AppColors.textPrimary),
                _seg(Icons.visibility_rounded, 'Visible', revealed, accent),
              ]),
            ),
          ]);
        }),
      ),
    );
  }

  Widget _seg(IconData icon, String label, bool active, Color color) => Expanded(
        child: AnimatedDefaultTextStyle(
          duration: AppMotion.fast,
          style: TextStyle(
            fontFamily: 'SpaceGrotesk',
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: active ? color : AppColors.textTertiary,
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 17, color: active ? color : AppColors.textTertiary),
            const SizedBox(width: 8),
            Text(label),
          ]),
        ),
      );
}

class _CopyTile extends StatefulWidget {
  const _CopyTile({
    required this.label,
    required this.display,
    required this.accent,
    required this.onCopy,
  });

  final String label;
  final String display;
  final Color accent;
  final VoidCallback onCopy;

  @override
  State<_CopyTile> createState() => _CopyTileState();
}

class _CopyTileState extends State<_CopyTile> {
  bool _copied = false;
  Timer? _reset;

  @override
  void dispose() {
    _reset?.cancel();
    super.dispose();
  }

  void _tap() {
    widget.onCopy();
    setState(() => _copied = true);
    _reset?.cancel();
    _reset = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: _tap,
      haptic: false, // SecureClipboard fires its own haptic
      child: AnimatedContainer(
        duration: AppMotion.medium,
        padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _copied ? widget.accent.withValues(alpha: 0.6) : AppColors.stroke,
          ),
        ),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.label.toUpperCase(), style: AppText.label),
              const SizedBox(height: 6),
              AnimatedSwitcher(
                duration: AppMotion.medium,
                transitionBuilder: (c, a) => FadeTransition(opacity: a, child: c),
                child: FittedBox(
                  key: ValueKey(widget.display),
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    widget.display,
                    maxLines: 1,
                    style: const TextStyle(
                      fontFamily: 'SpaceGrotesk',
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.2,
                      color: AppColors.textPrimary,
                      fontFeatures: AppText.tabular,
                    ),
                  ),
                ),
              ),
            ]),
          ),
          const SizedBox(width: 8),
          AnimatedContainer(
            duration: AppMotion.medium,
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _copied ? widget.accent : AppColors.surfaceHigh,
            ),
            child: AnimatedSwitcher(
              duration: AppMotion.medium,
              transitionBuilder: (c, a) => ScaleTransition(
                scale: CurvedAnimation(parent: a, curve: AppMotion.spring),
                child: c,
              ),
              child: Icon(
                _copied ? Icons.check_rounded : Icons.copy_rounded,
                key: ValueKey(_copied),
                size: 18,
                color: _copied ? AppColors.ink : AppColors.textSecondary,
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.label, required this.value, this.trailing, this.muted = false});
  final String label;
  final String value;
  final Widget? trailing;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.stroke),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label.toUpperCase(), style: AppText.label),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                    color: muted ? AppColors.textTertiary : AppColors.textPrimary,
                    fontFeatures: AppText.tabular,
                  )),
            ),
          ]),
        ),
        if (trailing != null) trailing!,
      ]),
    );
  }
}
