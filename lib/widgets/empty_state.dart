import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/card_skins.dart';
import 'ui_kit.dart';

/// Shown when the wallet has no cards: a floating fan of ghost cards.
class WalletEmptyState extends StatelessWidget {
  const WalletEmptyState({super.key, required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Entrance(child: SizedBox(height: 210, child: _FloatingFan())),
        const SizedBox(height: 28),
        Entrance(
          delay: const Duration(milliseconds: 120),
          child: Text("Your wallet's\nfeeling light",
              textAlign: TextAlign.center, style: AppText.title.copyWith(fontSize: 26)),
        ),
        const SizedBox(height: 10),
        const Entrance(
          delay: Duration(milliseconds: 200),
          child: Text(
            'Add your first card. It stays encrypted\non this phone and never goes online.',
            textAlign: TextAlign.center,
            style: AppText.body,
          ),
        ),
        const SizedBox(height: 28),
        Entrance(
          delay: const Duration(milliseconds: 280),
          child: SizedBox(
            width: 240,
            child: GradientButton(
              label: 'Add your first card',
              icon: Icons.add_rounded,
              onPressed: onAdd,
            ),
          ),
        ),
      ],
    );
  }
}

class _FloatingFan extends StatefulWidget {
  const _FloatingFan();

  @override
  State<_FloatingFan> createState() => _FloatingFanState();
}

class _FloatingFanState extends State<_FloatingFan>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 5))
        ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final skins = [
      CardSkins.resolve('grad:candy'),
      CardSkins.resolve('grad:sunset'),
      CardSkins.resolve('grad:aurora'),
    ];
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value * 2 * math.pi;
        return Stack(alignment: Alignment.center, children: [
          GlowOrb(color: AppColors.violet, size: 300, opacity: 0.28),
          for (var i = 0; i < 3; i++)
            Transform.translate(
              offset: Offset((i - 1) * 34.0, math.sin(t + i * 1.2) * 7 - (2 - i) * 6),
              child: Transform.rotate(
                angle: (i - 1) * 0.16 + math.sin(t + i) * 0.015,
                child: _GhostCard(skin: skins[i], strong: i == 2),
              ),
            ),
          Positioned(
            right: 40,
            top: 18 + math.sin(t * 2) * 4,
            child: Icon(Icons.auto_awesome,
                color: AppColors.lime.withValues(alpha: 0.9), size: 22),
          ),
          Positioned(
            left: 46,
            bottom: 24 + math.cos(t * 2) * 4,
            child: Icon(Icons.auto_awesome,
                color: AppColors.pink.withValues(alpha: 0.7), size: 14),
          ),
        ]);
      },
    );
  }
}

class _GhostCard extends StatelessWidget {
  const _GhostCard({required this.skin, required this.strong});
  final CardSkin skin;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 190,
      height: 120,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: skin.colors
              .map((c) => c.withValues(alpha: strong ? 0.95 : 0.45))
              .toList(),
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 24, offset: Offset(0, 12))],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 26,
          height: 19,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(5),
            color: const Color(0xFFE9C77B).withValues(alpha: strong ? 1 : 0.5),
          ),
        ),
        const Spacer(),
        Row(children: [
          for (var i = 0; i < 4; i++) ...[
            Container(
              width: 26,
              height: 6,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 7),
          ],
        ]),
      ]),
    );
  }
}
