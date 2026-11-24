import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/app_services.dart';
import '../theme/app_theme.dart';

/// Scales down slightly while pressed: the core "tactile" feel of the app.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.96,
    this.haptic = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  final bool haptic;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onLongPress: widget.onLongPress,
      onTap: widget.onTap == null
          ? null
          : () {
              if (widget.haptic) Haptics.tap();
              widget.onTap!();
            },
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: AppMotion.fast,
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Primary call to action with the brand gradient.
class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.height = 58,
    this.gradient = AppColors.brandGradient,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final double height;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onPressed,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(height / 2),
          boxShadow: [
            BoxShadow(
              color: AppColors.lime.withValues(alpha: 0.28),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        // Cross-fade when the label/icon changes instead of popping.
        child: AnimatedSwitcher(
          duration: AppMotion.fast,
          child: Row(
            key: ValueKey('$label|${icon?.codePoint}'),
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) Icon(icon, color: AppColors.ink, size: 22),
              if (icon != null && label.isNotEmpty) const SizedBox(width: 10),
              if (label.isNotEmpty)
                Flexible(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                      softWrap: false,
                      style: AppText.button.copyWith(color: AppColors.ink)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Round translucent icon button used in headers.
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.active = false,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool active;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = Pressable(
      onTap: onTap,
      scale: 0.9,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active ? AppColors.textPrimary : AppColors.surfaceHigh,
          border: Border.all(color: AppColors.stroke),
        ),
        child: Icon(icon,
            size: 20, color: active ? AppColors.ink : AppColors.textPrimary),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

/// Slides + fades its child in once, after [delay]. Used to stagger lists.
class Entrance extends StatefulWidget {
  const Entrance({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = 40,
    this.duration = const Duration(milliseconds: 650),
  });

  final Widget child;
  final Duration delay;
  final double offset;
  final Duration duration;

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.duration + widget.delay);
  late final Animation<double> _t = CurvedAnimation(
    parent: _c,
    curve: Interval(
      widget.delay.inMilliseconds /
          (widget.duration + widget.delay).inMilliseconds.clamp(1, 1 << 30),
      1,
      curve: AppMotion.emphasized,
    ),
  );

  @override
  void initState() {
    super.initState();
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      child: widget.child,
      builder: (context, child) {
        final v = _t.value;
        return Opacity(
          opacity: v.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1 - v) * widget.offset),
            child: Transform.scale(scale: 0.96 + 0.04 * v, child: child),
          ),
        );
      },
    );
  }
}

/// Soft blurred colour blob, used for ambient background glows.
class GlowOrb extends StatelessWidget {
  const GlowOrb({super.key, required this.color, this.size = 320, this.opacity = 0.35});
  final Color color;
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [
            color.withValues(alpha: opacity),
            color.withValues(alpha: 0),
          ]),
        ),
      ),
    );
  }
}

/// A slowly rotating dashed ring, used in onboarding and lock illustrations.
class OrbitRing extends StatefulWidget {
  const OrbitRing({super.key, required this.size, this.color = Colors.white, this.reverse = false, this.period = 18});
  final double size;
  final Color color;
  final bool reverse;
  final int period;

  @override
  State<OrbitRing> createState() => _OrbitRingState();
}

class _OrbitRingState extends State<OrbitRing> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: Duration(seconds: widget.period))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: widget.reverse ? ReverseAnimation(_c) : _c,
      child: CustomPaint(
        size: Size.square(widget.size),
        painter: _DashedRingPainter(widget.color),
      ),
    );
  }
}

class _DashedRingPainter extends CustomPainter {
  _DashedRingPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final c = Offset(r, r);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.6;
    const dashes = 48;
    for (var i = 0; i < dashes; i++) {
      final a = i / dashes * 2 * math.pi;
      p.color = color.withValues(alpha: 0.08 + 0.32 * (i / dashes));
      canvas.drawArc(Rect.fromCircle(center: c, radius: r - 1), a, 0.06, false, p);
    }
    // A bright "satellite" dot on the ring.
    canvas.drawCircle(Offset(c.dx + r - 1, c.dy), 3.5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _DashedRingPainter old) => old.color != color;
}

/// Section caption: small, spaced, uppercase.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10, top: 4),
        child: Text(text.toUpperCase(), style: AppText.label),
      );
}

/// Fade-through page route used for screen-to-screen hand-offs.
class FadeRoute<T> extends PageRouteBuilder<T> {
  FadeRoute({required WidgetBuilder builder, Duration duration = const Duration(milliseconds: 520)})
      : super(
          transitionDuration: duration,
          reverseTransitionDuration: const Duration(milliseconds: 380),
          pageBuilder: (context, a, b) => builder(context),
          transitionsBuilder: (context, a, b, child) => FadeTransition(
            opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
            child: child,
          ),
        );
}
