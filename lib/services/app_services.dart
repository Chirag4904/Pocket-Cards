import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Small, non-sensitive preferences (onboarding flag, display name).
class AppPrefs {
  AppPrefs._();

  static SharedPreferences? _prefs;
  static final name = ValueNotifier<String>('');

  static Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      name.value = _prefs!.getString('display_name') ?? '';
    } catch (_) {
      _prefs = null;
    }
  }

  static bool get onboarded => _prefs?.getBool('onboarded') ?? false;

  static Future<void> completeOnboarding() async =>
      _prefs?.setBool('onboarded', true);

  static Future<void> setName(String value) async {
    name.value = value.trim();
    await _prefs?.setString('display_name', value.trim());
  }
}

/// One place for haptic vocabulary so the whole app feels consistent.
class Haptics {
  Haptics._();

  static void tap() => HapticFeedback.selectionClick();
  static void copy() => HapticFeedback.lightImpact();
  static void flip() => HapticFeedback.mediumImpact();
  static void warn() => HapticFeedback.heavyImpact();
}

/// Copies sensitive values and wipes the clipboard after [clearAfter].
///
/// We deliberately don't read the clipboard back to check it first: on
/// iOS 16+ and Android 12+ that shows a "pasted from clipboard" banner.
class SecureClipboard {
  SecureClipboard._();

  static const clearAfter = Duration(seconds: 30);
  static Timer? _timer;

  static Future<void> copy(String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    Haptics.copy();
    _timer?.cancel();
    _timer = Timer(clearAfter, () {
      Clipboard.setData(const ClipboardData(text: '')).catchError((_) {});
    });
  }
}

/// Device tilt as a smoothed offset in roughly [-1, 1] on each axis.
///
/// Reads the accelerometer only (no network, no permissions) and only while
/// something is listening. A slow-moving baseline means "however you're
/// holding the phone" is neutral, so the card drifts back to centre.
class TiltController extends ValueNotifier<Offset> {
  TiltController._() : super(Offset.zero);
  static final instance = TiltController._();

  StreamSubscription<AccelerometerEvent>? _sub;
  Offset? _baseline;
  Offset _smoothed = Offset.zero;

  @override
  void addListener(VoidCallback listener) {
    super.addListener(listener);
    if (_sub == null) _start();
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    if (!hasListeners) _stop();
  }

  void _start() {
    try {
      _sub = accelerometerEventStream(samplingPeriod: SensorInterval.gameInterval)
          .listen(_onEvent, onError: (_) {}, cancelOnError: false);
    } catch (_) {
      _sub = null;
    }
  }

  void _stop() {
    _sub?.cancel();
    _sub = null;
    _baseline = null;
    _smoothed = Offset.zero;
    value = Offset.zero;
  }

  void _onEvent(AccelerometerEvent e) {
    final raw = Offset(e.x / 9.8, e.y / 9.8);
    _baseline = _baseline == null
        ? raw
        : Offset.lerp(_baseline, raw, 0.015); // slow recentre
    final delta = (raw - _baseline!) * 2.2;
    final clamped = Offset(
      delta.dx.clamp(-1.0, 1.0),
      delta.dy.clamp(-1.0, 1.0),
    );
    _smoothed = Offset.lerp(_smoothed, clamped, 0.18)!; // low-pass
    if ((_smoothed - value).distance > 0.002) value = _smoothed;
  }

  /// Convenience for painting: max rotation in radians.
  static const maxAngle = math.pi / 22;
}
