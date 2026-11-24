import 'package:flutter/material.dart';

import '../services/app_services.dart';
import '../services/card_scanner.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_kit.dart';

/// Waits for a card to be tapped on the phone and returns what was read,
/// or null if the user closed the sheet.
Future<ScannedCard?> showCardScanSheet(BuildContext context) {
  return showModalBottomSheet<ScannedCard>(
    context: context,
    builder: (_) => const _ScanSheet(),
  );
}

class _ScanSheet extends StatefulWidget {
  const _ScanSheet();

  @override
  State<_ScanSheet> createState() => _ScanSheetState();
}

class _ScanSheetState extends State<_ScanSheet> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();
  String? _error;
  bool _scanning = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    setState(() {
      _error = null;
      _scanning = true;
    });
    try {
      final card = await CardScanner.scan();
      if (!mounted) return;
      Haptics.flip();
      _scanning = false;
      Navigator.pop(context, card);
    } on CardScanException catch (e) {
      if (!mounted) return;
      Haptics.warn();
      setState(() {
        _error = e.message;
        _scanning = false;
      });
    }
  }

  @override
  void dispose() {
    if (_scanning) CardScanner.cancel();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final failed = _error != null;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            height: 170,
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (context, _) => Stack(alignment: Alignment.center, children: [
                if (!failed)
                  for (var k = 0; k < 2; k++)
                    Builder(builder: (context) {
                      final v = (_pulse.value + k * 0.5) % 1.0;
                      return Opacity(
                        opacity: (1 - v) * 0.6,
                        child: Container(
                          width: 84 + v * 80,
                          height: 84 + v * 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.lime, width: 1.5),
                          ),
                        ),
                      );
                    }),
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: failed ? AppColors.surfaceHigh : AppColors.lime,
                    border: failed ? Border.all(color: AppColors.strokeStrong) : null,
                  ),
                  child: Icon(
                    failed ? Icons.credit_card_off_outlined : Icons.contactless_outlined,
                    size: 40,
                    color: failed ? AppColors.danger : AppColors.ink,
                  ),
                ),
              ]),
            ),
          ),
          Text(failed ? "Couldn't read the card" : 'Tap your card',
              textAlign: TextAlign.center, style: AppText.title),
          const SizedBox(height: 10),
          Text(
            _error ?? 'Hold the card flat against the back of your phone, near the top, until it buzzes.',
            textAlign: TextAlign.center,
            style: AppText.body,
          ),
          const SizedBox(height: 22),
          if (failed) ...[
            GradientButton(label: 'Try again', icon: Icons.contactless_outlined, onPressed: _start),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Type it in instead',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
            ),
          ] else
            // One short line; the icon sits inline so it stays with the text
            // even if a large font size makes it wrap.
            Text.rich(
              TextSpan(children: [
                const WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: Icon(Icons.lock_rounded, size: 13, color: AppColors.lime),
                  ),
                ),
                TextSpan(text: 'Nothing is charged or sent anywhere', style: AppText.mono),
              ]),
              textAlign: TextAlign.center,
            ),
        ]),
      ),
    );
  }
}
