import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../models/wallet_card.dart';
import '../services/app_services.dart';
import '../theme/app_theme.dart';
import '../theme/card_skins.dart';

/// Everything needed to paint a card face. Decoupled from [WalletCard] so the
/// add-card sheet can preview half-typed data.
class CardFaceData {
  const CardFaceData({
    required this.skin,
    required this.digits,
    required this.holder,
    required this.expiry,
    required this.cvv,
    this.logoAsset,
    this.bankName = '',
    this.pinned = false,
    this.logoStyle = LogoStyle.boxed,
  });

  factory CardFaceData.fromCard(WalletCard card, {String? logoAsset}) =>
      CardFaceData(
        skin: CardSkins.resolve(card.skinId),
        digits: card.digits,
        holder: card.holder,
        expiry: card.expiry,
        cvv: card.cvv,
        logoAsset: logoAsset,
        bankName: card.bank,
        pinned: card.pinned,
        logoStyle: card.logoStyle,
      );

  final CardSkin skin;
  final String digits;
  final String holder;
  final String expiry;
  final String cvv;
  final String? logoAsset;
  final String bankName;
  final bool pinned;
  final LogoStyle logoStyle;

  String get last4 =>
      digits.length >= 4 ? digits.substring(digits.length - 4) : digits;
}

const double kCardAspect = 1.586; // ISO/IEC 7810 ID-1

/// A premium card face. Pass [back] for the reverse side.
/// [light] (-1..1) moves the specular sheen; feed it from [TiltController].
class WalletCardFace extends StatelessWidget {
  const WalletCardFace({
    super.key,
    required this.data,
    this.revealed = false,
    this.back = false,
    this.light = Offset.zero,
    this.shadow = true,
    this.lite = false,
    this.sweep,
  });

  final CardFaceData data;
  final bool revealed;
  final bool back;
  final Offset light;
  final bool shadow;

  /// Cheaper paint for lists where many faces are on screen at once: a single
  /// small blur instead of two large ones (blurs are the costliest thing on
  /// the card to rasterise).
  final bool lite;

  /// 0..1 progress of a one-off holographic glint crossing the card.
  final double? sweep;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: kCardAspect,
      child: LayoutBuilder(builder: (context, c) {
        final s = c.maxWidth / 340; // design scale
        final radius = BorderRadius.circular(22 * s);
        final skin = data.skin;

        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: shadow && lite
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 14 * s,
                      offset: Offset(0, -3 * s),
                    ),
                  ]
                : shadow
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.55),
                      blurRadius: 28 * s,
                      offset: Offset(0, -4 * s),
                    ),
                    BoxShadow(
                      color: skin.accent.withValues(alpha: 0.18),
                      blurRadius: 40 * s,
                      spreadRadius: -8 * s,
                      offset: Offset(0, 18 * s),
                    ),
                  ]
                : null,
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: Stack(fit: StackFit.expand, children: [
              // Base
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: skin.gradient,
                  image: skin.image == null
                      ? null
                      : DecorationImage(image: skin.image!, fit: BoxFit.cover),
                ),
              ),
              if (skin.isImage)
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x33000000), Color(0x05000000), Color(0x99000000)],
                      stops: [0, 0.45, 1],
                    ),
                  ),
                )
              else ...[
                if (skin.glow != null)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0.9, -1.1),
                        radius: 1.1,
                        colors: [
                          skin.glow!.withValues(alpha: 0.45),
                          skin.glow!.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                CustomPaint(painter: _ContourPainter(scale: s)),
              ],
              // Specular sheen that follows device tilt.
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment(-1.4 + light.dx * 0.9, -1 + light.dy * 0.6),
                    end: Alignment(1.4 + light.dx * 0.9, 1 + light.dy * 0.6),
                    colors: [
                      Colors.white.withValues(alpha: 0.0),
                      Colors.white.withValues(alpha: 0.13),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                    stops: const [0.3, 0.5, 0.7],
                  ),
                ),
              ),
              if (sweep != null)
                IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment(-3 + sweep! * 5, -1),
                        end: Alignment(-1 + sweep! * 5, 1),
                        colors: [
                          Colors.white.withValues(alpha: 0),
                          const Color(0xFFB8F2FF).withValues(alpha: 0.10),
                          Colors.white.withValues(alpha: 0.42),
                          const Color(0xFFFFC2F0).withValues(alpha: 0.10),
                          Colors.white.withValues(alpha: 0),
                        ],
                        stops: const [0.30, 0.44, 0.50, 0.56, 0.70],
                      ),
                    ),
                  ),
                ),
              // Hairline edge
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.14),
                    width: 1,
                  ),
                ),
              ),
              back ? _Back(data: data, revealed: revealed, s: s)
                  : _Front(data: data, revealed: revealed, s: s),
            ]),
          ),
        );
      }),
    );
  }
}

TextStyle _cardText(double s, double size,
        {FontWeight weight = FontWeight.w500, double spacing = 0, double alpha = 1}) =>
    TextStyle(
      fontFamily: 'SpaceGrotesk',
      fontSize: size * s,
      fontWeight: weight,
      letterSpacing: spacing * s,
      color: Colors.white.withValues(alpha: alpha),
      fontFeatures: AppText.tabular,
      shadows: const [Shadow(color: Color(0x55000000), blurRadius: 6, offset: Offset(0, 1))],
    );

class _Front extends StatelessWidget {
  const _Front({required this.data, required this.revealed, required this.s});
  final CardFaceData data;
  final bool revealed;
  final double s;

  @override
  Widget build(BuildContext context) {
    final digits = data.digits;
    final grouped = digits
        .padRight(16, '•')
        .replaceAllMapped(RegExp(r'.{4}'), (m) => '${m.group(0)}  ')
        .trim();
    final number = revealed || digits.isEmpty
        ? (digits.isEmpty ? '••••  ••••  ••••  ••••' : grouped)
        : '••••  ••••  ••••  ${data.last4}';

    return Padding(
      padding: EdgeInsets.fromLTRB(20 * s, 18 * s, 20 * s, 18 * s),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _BankMark(data: data, s: s),
          const Spacer(),
          if (data.pinned) ...[
            Icon(Icons.push_pin_rounded, size: 13 * s, color: Colors.white70),
            SizedBox(width: 6 * s),
          ],
          Text(data.last4.isEmpty ? '' : '•• ${data.last4}',
              style: _cardText(s, 13, alpha: 0.85, spacing: 0.5)),
        ]),
        const Spacer(),
        Row(children: [
          SizedBox(
            width: 40 * s,
            height: 30 * s,
            child: CustomPaint(painter: _ChipPainter()),
          ),
          SizedBox(width: 10 * s),
          Transform.rotate(
            angle: math.pi / 2,
            child: Icon(Icons.wifi_rounded,
                size: 20 * s, color: Colors.white.withValues(alpha: 0.8)),
          ),
        ]),
        SizedBox(height: 14 * s),
        AnimatedSwitcher(
          duration: AppMotion.medium,
          switchInCurve: AppMotion.emphasized,
          transitionBuilder: (child, a) => FadeTransition(
            opacity: a,
            child: SlideTransition(
              position: Tween(begin: const Offset(0, 0.25), end: Offset.zero)
                  .animate(a),
              child: child,
            ),
          ),
          child: FittedBox(
            key: ValueKey(number),
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(number,
                maxLines: 1,
                style: _cardText(s, 21, spacing: 1.2, weight: FontWeight.w500)),
          ),
        ),
        SizedBox(height: 12 * s),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: _Field(
              label: 'CARD HOLDER',
              value: data.holder.isEmpty ? 'YOUR NAME' : data.holder.toUpperCase(),
              s: s,
            ),
          ),
          SizedBox(width: 16 * s),
          _Field(
              label: 'EXPIRES',
              value: data.expiry.isEmpty ? 'MM/YY' : data.expiry,
              s: s),
          SizedBox(width: 14 * s),
          NetworkMark(network: WalletCard.detectNetwork(digits), s: s),
        ]),
      ]),
    );
  }
}

class _Back extends StatelessWidget {
  const _Back({required this.data, required this.revealed, required this.s});
  final CardFaceData data;
  final bool revealed;
  final double s;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(height: 22 * s),
      Container(height: 42 * s, color: Colors.black.withValues(alpha: 0.82)),
      SizedBox(height: 18 * s),
      Padding(
        padding: EdgeInsets.symmetric(horizontal: 20 * s),
        child: Row(children: [
          Expanded(
            child: Container(
              height: 34 * s,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6 * s),
                gradient: const LinearGradient(
                  colors: [Color(0xFFF1F1EE), Color(0xFFDADAD4)],
                ),
              ),
              child: CustomPaint(painter: _SignaturePainter()),
            ),
          ),
          SizedBox(width: 10 * s),
          Container(
            height: 34 * s,
            padding: EdgeInsets.symmetric(horizontal: 12 * s),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6 * s),
            ),
            child: AnimatedSwitcher(
              duration: AppMotion.fast,
              child: Text(
                revealed && data.cvv.isNotEmpty ? data.cvv : '•••',
                key: ValueKey(revealed),
                style: TextStyle(
                  fontFamily: 'SpaceGrotesk',
                  fontSize: 15 * s,
                  fontWeight: FontWeight.w700,
                  fontStyle: FontStyle.italic,
                  letterSpacing: 2 * s,
                  color: const Color(0xFF15171C),
                  fontFeatures: AppText.tabular,
                ),
              ),
            ),
          ),
        ]),
      ),
      Padding(
        padding: EdgeInsets.fromLTRB(20 * s, 6 * s, 20 * s, 0),
        child: Align(
          alignment: Alignment.centerRight,
          child: Text('CVV', style: _cardText(s, 8.5, spacing: 1.4, alpha: 0.7)),
        ),
      ),
      const Spacer(),
      Padding(
        padding: EdgeInsets.fromLTRB(20 * s, 0, 20 * s, 16 * s),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: Text(
              'Stored only on this device.\nNever synced. Never shared.',
              style: _cardText(s, 9, alpha: 0.7, spacing: 0.2),
            ),
          ),
          NetworkMark(network: WalletCard.detectNetwork(data.digits), s: s),
        ]),
      ),
    ]);
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value, required this.s});
  final String label;
  final String value;
  final double s;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: _cardText(s, 8, spacing: 1.4, alpha: 0.65)),
        SizedBox(height: 3 * s),
        Text(value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _cardText(s, 13, weight: FontWeight.w500, spacing: 0.6)),
      ],
    );
  }
}

class _BankMark extends StatelessWidget {
  const _BankMark({required this.data, required this.s});
  final CardFaceData data;
  final double s;

  @override
  Widget build(BuildContext context) {
    if (data.logoAsset != null && data.logoStyle == LogoStyle.plain) {
      return Image.asset(data.logoAsset!,
          height: 20 * s, filterQuality: FilterQuality.medium);
    }
    if (data.logoAsset != null && data.logoStyle == LogoStyle.boxed) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 7 * s, vertical: 5 * s),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8 * s),
          boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 8)],
        ),
        child: Image.asset(data.logoAsset!,
            height: 14 * s, filterQuality: FilterQuality.medium),
      );
    }
    return Text(
      data.bankName.isEmpty ? 'POCKET' : data.bankName,
      style: _cardText(s, 14, weight: FontWeight.w700, spacing: 0.4),
    );
  }
}

/// Wordmark-style network marks drawn in code (no network fetch, no assets).
class NetworkMark extends StatelessWidget {
  const NetworkMark({super.key, required this.network, this.s = 1});
  final CardNetwork network;
  final double s;

  @override
  Widget build(BuildContext context) {
    switch (network) {
      case CardNetwork.visa:
        return Text('VISA',
            style: TextStyle(
              fontFamily: 'SpaceGrotesk',
              fontSize: 22 * s,
              fontWeight: FontWeight.w700,
              fontStyle: FontStyle.italic,
              letterSpacing: -0.5 * s,
              color: Colors.white,
              height: 1,
            ));
      case CardNetwork.mastercard:
        return SizedBox(
          width: 40 * s,
          height: 25 * s,
          child: CustomPaint(painter: _MastercardPainter()),
        );
      case CardNetwork.rupay:
        return Text('RuPay',
            style: TextStyle(
              fontFamily: 'SpaceGrotesk',
              fontSize: 17 * s,
              fontWeight: FontWeight.w700,
              fontStyle: FontStyle.italic,
              color: Colors.white,
              height: 1,
            ));
      case CardNetwork.amex:
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 5 * s, vertical: 3 * s),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white, width: 1.4 * s),
            borderRadius: BorderRadius.circular(3 * s),
          ),
          child: Text('AMEX',
              style: TextStyle(
                fontFamily: 'SpaceGrotesk',
                fontSize: 11 * s,
                fontWeight: FontWeight.w700,
                letterSpacing: 1 * s,
                color: Colors.white,
                height: 1,
              )),
        );
      case CardNetwork.unknown:
        return const SizedBox.shrink();
    }
  }
}

class _MastercardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = size.height / 2;
    final left = Offset(r, r);
    final right = Offset(size.width - r, r);
    canvas.drawCircle(left, r, Paint()..color = const Color(0xFFEB001B));
    canvas.drawCircle(right, r, Paint()..color = const Color(0xFFF79E1B));
    final overlap = Path.combine(
      PathOperation.intersect,
      Path()..addOval(Rect.fromCircle(center: left, radius: r)),
      Path()..addOval(Rect.fromCircle(center: right, radius: r)),
    );
    canvas.drawPath(overlap, Paint()..color = const Color(0xFFFF5F00));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ChipPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rr = RRect.fromRectAndRadius(rect, Radius.circular(size.height * 0.2));
    canvas.drawRRect(
      rr,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF6E3A8), Color(0xFFC99A45), Color(0xFFF0D58C), Color(0xFFB78838)],
          stops: [0, 0.4, 0.7, 1],
        ).createShader(rect),
    );
    final line = Paint()
      ..color = const Color(0x66704A12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.height * 0.035;
    final w = size.width, h = size.height;
    canvas.drawLine(Offset(0, h * 0.35), Offset(w * 0.33, h * 0.35), line);
    canvas.drawLine(Offset(0, h * 0.65), Offset(w * 0.33, h * 0.65), line);
    canvas.drawLine(Offset(w * 0.67, h * 0.35), Offset(w, h * 0.35), line);
    canvas.drawLine(Offset(w * 0.67, h * 0.65), Offset(w, h * 0.65), line);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTRB(w * 0.33, h * 0.18, w * 0.67, h * 0.82),
          Radius.circular(h * 0.12)),
      line,
    );
    canvas.drawRRect(rr, line..color = const Color(0x40704A12));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Faint topographic rings that give gradient skins some texture.
class _ContourPainter extends CustomPainter {
  _ContourPainter({required this.scale});
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.07);
    final center = Offset(size.width * 1.05, size.height * 1.15);
    for (var i = 1; i <= 9; i++) {
      canvas.drawCircle(center, i * 34.0 * scale, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ContourPainter old) => old.scale != scale;
}

class _SignaturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0x1A15171C)
      ..strokeWidth = 1;
    for (double x = -size.height; x < size.width; x += 6) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Card with a 3D tilt that follows both the device (accelerometer) and your
/// finger, a flip to the back, and an optional shine sweep when it appears.
class InteractiveCard extends StatefulWidget {
  const InteractiveCard({
    super.key,
    required this.data,
    required this.revealed,
    required this.flipped,
    this.tilt = true,
    this.touchTilt = true,
    this.introSweep = false,
  });

  final CardFaceData data;
  final bool revealed;
  final bool flipped;

  /// Follow the device's motion sensor.
  final bool tilt;

  /// Lean towards the finger while it's on the card, then spring back.
  final bool touchTilt;

  /// Run a one-off holographic shine across the card after it appears.
  final bool introSweep;

  @override
  State<InteractiveCard> createState() => _InteractiveCardState();
}

class _InteractiveCardState extends State<InteractiveCard>
    with TickerProviderStateMixin {
  late final AnimationController _flip = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
    value: widget.flipped ? 1 : 0,
  );

  // Touch tilt, one unbounded controller per axis so release can use a spring.
  late final AnimationController _tx = AnimationController.unbounded(vsync: this);
  late final AnimationController _ty = AnimationController.unbounded(vsync: this);
  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 160),
    reverseDuration: const Duration(milliseconds: 420),
  );
  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );

  Size _size = Size.zero;

  static const _spring = SpringDescription(mass: 1, stiffness: 180, damping: 11);

  @override
  void initState() {
    super.initState();
    if (widget.introSweep) {
      Future.delayed(const Duration(milliseconds: 420), () {
        if (mounted) _sweep.forward();
      });
    }
  }

  @override
  void didUpdateWidget(covariant InteractiveCard old) {
    super.didUpdateWidget(old);
    if (old.flipped != widget.flipped) {
      widget.flipped ? _flip.forward() : _flip.reverse();
      // Flipping is a good moment for another glint.
      if (widget.introSweep) _sweep.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _flip.dispose();
    _tx.dispose();
    _ty.dispose();
    _press.dispose();
    _sweep.dispose();
    super.dispose();
  }

  void _track(Offset local) {
    if (_size.isEmpty) return;
    final nx = ((local.dx / _size.width) * 2 - 1).clamp(-1.0, 1.0);
    final ny = ((local.dy / _size.height) * 2 - 1).clamp(-1.0, 1.0);
    const d = Duration(milliseconds: 90);
    _tx.animateTo(nx, duration: d, curve: Curves.easeOut);
    _ty.animateTo(ny, duration: d, curve: Curves.easeOut);
  }

  void _release() {
    _tx.animateWith(SpringSimulation(_spring, _tx.value, 0, 0));
    _ty.animateWith(SpringSimulation(_spring, _ty.value, 0, 0));
    _press.reverse();
  }

  Widget _build(Offset sensor) {
    return AnimatedBuilder(
      animation: Listenable.merge([_flip, _tx, _ty, _press, _sweep]),
      builder: (context, _) {
        final t = Curves.easeInOutCubic.transform(_flip.value);
        final angle = t * math.pi;
        final showBack = angle > math.pi / 2;
        // Lift slightly mid-flip so it reads as a physical object.
        final lift = 1 + math.sin(t * math.pi) * 0.06;
        final press = 1 - 0.035 * Curves.easeOut.transform(_press.value);

        // Finger tilt is stronger than sensor tilt; the card leans *into* the
        // touch, so the side you press goes down.
        final tilt = Offset(
          sensor.dx + _tx.value * 1.5,
          sensor.dy + _ty.value * 1.5,
        );

        final m = Matrix4.identity()
          ..setEntry(3, 2, 0.0011)
          ..scale(lift * press, lift * press)
          ..rotateX(tilt.dy * TiltController.maxAngle)
          ..rotateY(-tilt.dx * TiltController.maxAngle + angle);

        final sweeping = _sweep.isAnimating;
        final face = WalletCardFace(
          data: widget.data,
          revealed: widget.revealed,
          back: showBack,
          light: Offset(-tilt.dx, -tilt.dy),
          sweep: sweeping ? Curves.easeInOutCubic.transform(_sweep.value) : null,
        );

        return Transform(
          alignment: Alignment.center,
          transform: m,
          child: showBack
              ? Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.rotationY(math.pi),
                  child: face,
                )
              : face,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget card = widget.tilt
        ? ValueListenableBuilder<Offset>(
            valueListenable: TiltController.instance,
            builder: (context, tilt, _) => _build(tilt),
          )
        : _build(Offset.zero);

    if (!widget.touchTilt) return card;

    // Listener is passive: taps and long-presses still reach the parent.
    return LayoutBuilder(builder: (context, c) {
      _size = Size(c.maxWidth, c.maxWidth / kCardAspect);
      return Listener(
        onPointerDown: (e) {
          _press.forward();
          _track(e.localPosition);
        },
        onPointerMove: (e) => _track(e.localPosition),
        onPointerUp: (_) => _release(),
        onPointerCancel: (_) => _release(),
        child: card,
      );
    });
  }
}

/// Hero flight for cards: the card lifts towards you and rocks back slightly
/// mid-flight, so opening one feels like pulling it out of a wallet.
Widget cardFlightShuttle(
  BuildContext flightContext,
  Animation<double> animation,
  HeroFlightDirection direction,
  BuildContext fromContext,
  BuildContext toContext,
) {
  final hero = (direction == HeroFlightDirection.push ? toContext : fromContext).widget as Hero;
  return AnimatedBuilder(
    animation: animation,
    child: hero.child,
    builder: (context, child) {
      final t = Curves.easeInOut.transform(animation.value);
      final arc = math.sin(t * math.pi); // 0 → 1 → 0
      return Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.0011)
          ..scale(1 + arc * 0.06)
          ..rotateX(arc * 0.32)
          ..rotateZ(arc * -0.025),
        child: child,
      );
    },
  );
}
