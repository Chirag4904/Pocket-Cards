import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../provider/wallet_provider.dart';
import '../services/app_services.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_kit.dart';
import '../widgets/wallet_card_view.dart';

/// Drag to reorder; pin favourites so they always sit on top of the stack.
class ArrangeScreen extends StatelessWidget {
  const ArrangeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletProvider>();
    final cards = wallet.cards;

    return Scaffold(
      body: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Row(children: [
              GlassIconButton(
                icon: Icons.arrow_back_rounded,
                onTap: () => Navigator.pop(context),
              ),
            ]),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 22, 24, 6),
            child: Text('Arrange', style: AppText.display),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, 18),
            child: Text('Hold and drag to reorder. Pinned cards stay on top.',
                style: AppText.body),
          ),
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
              physics: const BouncingScrollPhysics(),
              itemCount: cards.length,
              onReorderStart: (_) => Haptics.flip(),
              onReorder: (a, b) {
                Haptics.tap();
                wallet.reorder(a, b);
              },
              proxyDecorator: (child, index, animation) => AnimatedBuilder(
                animation: animation,
                builder: (context, child) {
                  final t = Curves.easeOut.transform(animation.value);
                  return Transform.scale(
                    scale: lerpDouble(1, 1.04, t),
                    child: Material(
                      color: Colors.transparent,
                      elevation: 0,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.5 * t),
                              blurRadius: 30,
                              offset: const Offset(0, 14),
                            ),
                          ],
                        ),
                        child: child,
                      ),
                    ),
                  );
                },
                child: child,
              ),
              itemBuilder: (context, i) {
                final card = cards[i];
                final showDivider = i > 0 && cards[i - 1].pinned && !card.pinned;
                return Column(
                  key: ValueKey(card.id),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (showDivider)
                      const Padding(
                        padding: EdgeInsets.fromLTRB(4, 6, 4, 14),
                        child: Row(children: [
                          Expanded(child: Divider(color: AppColors.stroke)),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10),
                            child: Text('EVERYTHING ELSE', style: AppText.label),
                          ),
                          Expanded(child: Divider(color: AppColors.stroke)),
                        ]),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: card.pinned
                                ? AppColors.lime.withValues(alpha: 0.35)
                                : AppColors.stroke,
                          ),
                        ),
                        child: Row(children: [
                          SizedBox(
                            width: 92,
                            child: WalletCardFace(
                              shadow: false,
                              data: CardFaceData.fromCard(card,
                                  logoAsset: wallet.logoAssetFor(card.bank)),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(card.bank.isEmpty ? 'Card' : card.bank,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500)),
                              const SizedBox(height: 3),
                              Text(card.limit > 0 ? '•• ${card.last4}  ·  ${formatInr(card.limit)}' : '•• ${card.last4}',
                                  style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13,
                                      fontFeatures: AppText.tabular)),
                            ]),
                          ),
                          IconButton(
                            onPressed: () {
                              Haptics.tap();
                              wallet.togglePin(card.id);
                            },
                            icon: AnimatedSwitcher(
                              duration: AppMotion.medium,
                              transitionBuilder: (c, a) => RotationTransition(
                                turns: Tween(begin: -0.1, end: 0.0).animate(a),
                                child: ScaleTransition(scale: a, child: c),
                              ),
                              child: Icon(
                                card.pinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                                key: ValueKey(card.pinned),
                                color: card.pinned ? AppColors.lime : AppColors.textTertiary,
                              ),
                            ),
                          ),
                          ReorderableDragStartListener(
                            index: i,
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 12),
                              child: Icon(Icons.drag_indicator_rounded,
                                  color: AppColors.textTertiary),
                            ),
                          ),
                        ]),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}
