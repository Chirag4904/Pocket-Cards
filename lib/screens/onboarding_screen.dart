import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/app_services.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_kit.dart';

class _Page {
  const _Page(this.icon, this.kicker, this.title, this.body, this.colors);
  final IconData icon;
  final String kicker;
  final String title;
  final String body;
  final List<Color> colors;
}

const _pages = [
  _Page(
    Icons.wifi_off_rounded,
    '01 — OFFLINE',
    'No internet.\nNo problem.',
    "Pocket Cards never connects to a server. There's nothing to hack because nothing is sent.",
    [Color(0xFFD4F46A), Color(0xFF7FC93E)],
  ),
  _Page(
    Icons.smartphone_rounded,
    '02 — ON-DEVICE',
    'Your cards live\non your phone.',
    'Everything is encrypted in your phone\'s secure storage. No accounts, no cloud, no tracking.',
    [Color(0xFF4FE0B0), Color(0xFF1F9C84)],
  ),
  _Page(
    Icons.fingerprint_rounded,
    '03 — LOCKED',
    'Only you\nget in.',
    'Face ID, fingerprint or your phone PIN guards the app every time you open it.',
    [Color(0xFFD4F46A), Color(0xFF10B5A4)],
  ),
];

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onDone});
  final VoidCallback onDone;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  final _name = TextEditingController();
  double _page = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() => _page = _controller.page ?? 0));
  }

  @override
  void dispose() {
    _controller.dispose();
    _name.dispose();
    super.dispose();
  }

  bool get _isLast => _page.round() == _pages.length - 1;

  Future<void> _next() async {
    if (!_isLast) {
      _controller.nextPage(duration: AppMotion.slow, curve: AppMotion.emphasized);
      return;
    }
    FocusScope.of(context).unfocus();
    if (_name.text.trim().isNotEmpty) await AppPrefs.setName(_name.text);
    await AppPrefs.completeOnboarding();
    Haptics.flip();
    widget.onDone();
  }

  Color _lerpColor(int slot) {
    final i = _page.floor().clamp(0, _pages.length - 1);
    final j = (i + 1).clamp(0, _pages.length - 1);
    return Color.lerp(_pages[i].colors[slot], _pages[j].colors[slot], _page - i)!;
  }

  @override
  Widget build(BuildContext context) {
    final a = _lerpColor(0);
    final b = _lerpColor(1);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(children: [
        Positioned(top: -160, left: -120, child: GlowOrb(color: a, size: 460, opacity: 0.30)),
        Positioned(bottom: -200, right: -160, child: GlowOrb(color: b, size: 480, opacity: 0.22)),
        SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 12, 0),
              child: Row(children: [
                Text('pocket', style: AppText.title.copyWith(fontSize: 22)),
                Text('.', style: AppText.title.copyWith(fontSize: 22, color: a)),
                const Spacer(),
                AnimatedOpacity(
                  opacity: _isLast ? 0 : 1,
                  duration: AppMotion.fast,
                  child: TextButton(
                    onPressed: _isLast
                        ? null
                        : () => _controller.animateToPage(_pages.length - 1,
                            duration: AppMotion.slow, curve: AppMotion.emphasized),
                    child: const Text('Skip', style: TextStyle(color: AppColors.textSecondary)),
                  ),
                ),
              ]),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (_) => Haptics.tap(),
                itemBuilder: (context, i) {
                  final p = _pages[i];
                  final delta = (_page - i).clamp(-1.0, 1.0);
                  return LayoutBuilder(builder: (context, c) {
                    return SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: c.maxHeight),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 28),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Center(
                                child: Transform.translate(
                                  offset: Offset(delta * -80, 0),
                                  child: Opacity(
                                    opacity: (1 - delta.abs()).clamp(0, 1),
                                    child: _Illustration(icon: p.icon, colors: p.colors),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 44),
                              Transform.translate(
                                offset: Offset(delta * -40, 0),
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(p.kicker, style: AppText.label.copyWith(color: p.colors[0])),
                                  const SizedBox(height: 12),
                                  Text(p.title, style: AppText.display.copyWith(fontSize: 42)),
                                  const SizedBox(height: 14),
                                  Text(p.body, style: AppText.body.copyWith(fontSize: 16)),
                                  if (i == _pages.length - 1) ...[
                                    const SizedBox(height: 24),
                                    TextField(
                                      controller: _name,
                                      textCapitalization: TextCapitalization.words,
                                      textInputAction: TextInputAction.done,
                                      onSubmitted: (_) => _next(),
                                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
                                      decoration: InputDecoration(
                                        hintText: 'What should we call you? (optional)',
                                        hintStyle: const TextStyle(color: AppColors.textTertiary),
                                        prefixIcon: const Icon(Icons.waving_hand_outlined, color: AppColors.textSecondary, size: 20),
                                        filled: true,
                                        fillColor: AppColors.surfaceHigh,
                                        contentPadding: const EdgeInsets.symmetric(vertical: 18),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: const BorderSide(color: AppColors.stroke),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: const BorderSide(color: AppColors.stroke),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: BorderSide(color: p.colors[0], width: 1.5),
                                        ),
                                      ),
                                    ),
                                  ],
                                ]),
                              ),
                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ),
                    );
                  });
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 8, 28, 24),
              child: Row(children: [
                for (var i = 0; i < _pages.length; i++)
                  AnimatedContainer(
                    duration: AppMotion.medium,
                    curve: AppMotion.emphasized,
                    margin: const EdgeInsets.only(right: 6),
                    width: (_page - i).abs() < 0.5 ? 26 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: (_page - i).abs() < 0.5 ? a : AppColors.strokeStrong,
                    ),
                  ),
                const Spacer(),
                // Animate the width itself (not AnimatedSize, which clips the
                // full-width pill to a hard-edged box mid-animation). The
                // label swaps in only once there's room for it.
                TweenAnimationBuilder<double>(
                  tween: Tween(end: _isLast ? 180 : 64),
                  duration: AppMotion.medium,
                  curve: AppMotion.emphasized,
                  builder: (context, width, _) {
                    final roomForLabel = _isLast && width > 140;
                    return SizedBox(
                      width: width,
                      child: GradientButton(
                        height: 64,
                        label: roomForLabel ? "Let's go" : '',
                        icon: roomForLabel ? null : Icons.arrow_forward_rounded,
                        gradient: LinearGradient(colors: [a, b]),
                        onPressed: _next,
                      ),
                    );
                  },
                ),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }
}

/// Glowing orb with orbiting rings and floating mini cards.
class _Illustration extends StatefulWidget {
  const _Illustration({required this.icon, required this.colors});
  final IconData icon;
  final List<Color> colors;

  @override
  State<_Illustration> createState() => _IllustrationState();
}

class _IllustrationState extends State<_Illustration> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final [a, b] = widget.colors;
    return SizedBox(
      width: 260,
      height: 260,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value * 2 * math.pi;
          final pulse = 1 + math.sin(t * 2) * 0.03;
          return Stack(alignment: Alignment.center, children: [
            GlowOrb(color: a, size: 260, opacity: 0.35),
            OrbitRing(size: 240, color: a, period: 22),
            OrbitRing(size: 180, color: b, reverse: true, period: 14),
            Transform.scale(
              scale: pulse,
              child: Container(
                width: 112,
                height: 112,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [a, b],
                  ),
                  boxShadow: [BoxShadow(color: a.withValues(alpha: 0.5), blurRadius: 40)],
                ),
                child: Icon(widget.icon, size: 48, color: AppColors.ink),
              ),
            ),
            // Floating mini cards
            Transform.translate(
              offset: Offset(-92, -70 + math.sin(t) * 8),
              child: Transform.rotate(angle: -0.25, child: _MiniCard(color: b)),
            ),
            Transform.translate(
              offset: Offset(96, 64 + math.cos(t) * 8),
              child: Transform.rotate(angle: 0.2, child: _MiniCard(color: a)),
            ),
          ]);
        },
      ),
    );
  }
}

class _MiniCard extends StatelessWidget {
  const _MiniCard({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: 62,
        height: 40,
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9),
          gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.55)]),
          border: Border.all(color: Colors.white24),
          boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 14, offset: Offset(0, 6))],
        ),
        alignment: Alignment.topLeft,
        child: Container(
          width: 14,
          height: 10,
          decoration: BoxDecoration(
            color: const Color(0xFFE9C77B),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      );
}
