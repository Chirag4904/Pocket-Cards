import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Design tokens for Pocket Cards.
///
/// One dark, ink-toned palette with a single signature gradient
/// (iris -> violet -> pink) used for primary actions and brand moments.
class AppColors {
  AppColors._();

  static const ink = Color(0xFF0A0C11); // app background
  static const surface = Color(0xFF13161E); // tiles, sheets
  static const surfaceHigh = Color(0xFF1B1F2A); // fields, raised tiles
  static const stroke = Color(0x14FFFFFF); // hairline borders (8%)
  static const strokeStrong = Color(0x29FFFFFF); // 16%

  static const textPrimary = Color(0xFFF4F6FB);
  static const textSecondary = Color(0xFF9AA3B5);
  static const textTertiary = Color(0xFF5E6678);

  static const iris = Color(0xFF7C9CFF);
  static const violet = Color(0xFFB07CFF);
  static const pink = Color(0xFFFF7CC8);
  static const lime = Color(0xFFC8FF5A);
  static const danger = Color(0xFFFF5A6E);

  static const brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [iris, violet, pink],
  );
}

class AppMotion {
  AppMotion._();

  static const fast = Duration(milliseconds: 180);
  static const medium = Duration(milliseconds: 320);
  static const slow = Duration(milliseconds: 520);

  /// Snappy, slightly springy ease used for most UI motion.
  static const emphasized = Cubic(0.2, 0.0, 0.0, 1.0);
  static const spring = Curves.easeOutBack;
}

class AppText {
  AppText._();

  static const _family = 'SpaceGrotesk';

  /// Dot-matrix display face (Doto, round dots). Headlines and big numbers
  /// only: it has no ₹ glyph, so rupee amounts fall back to Space Mono.
  static const _dots = 'Doto';
  static const _dotsVariations = [
    FontVariation('wght', 900),
    FontVariation('ROND', 100),
  ];
  static const _mono = 'SpaceMono';

  static const display = TextStyle(
    fontFamily: _dots,
    fontFamilyFallback: [_mono],
    fontVariations: _dotsVariations,
    fontSize: 38,
    height: 1.05,
    letterSpacing: -0.5,
    color: AppColors.textPrimary,
  );

  static const title = TextStyle(
    fontFamily: _dots,
    fontFamilyFallback: [_mono],
    fontVariations: _dotsVariations,
    fontSize: 26,
    height: 1.1,
    letterSpacing: -0.2,
    color: AppColors.textPrimary,
  );

  static const body = TextStyle(
    fontFamily: _family,
    fontSize: 15,
    height: 1.45,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  /// Monospaced micro-labels, the "instrument panel" layer of the UI.
  static const label = TextStyle(
    fontFamily: _mono,
    fontSize: 11,
    fontWeight: FontWeight.w400,
    letterSpacing: 1.4,
    color: AppColors.textTertiary,
  );

  static const button = TextStyle(
    fontFamily: _family,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.1,
  );

  /// Small monospaced text for hints and secondary numbers.
  static const mono = TextStyle(
    fontFamily: _mono,
    fontSize: 12.5,
    letterSpacing: 0.2,
    color: AppColors.textTertiary,
  );

  static const tabular = [FontFeature.tabularFigures()];
}

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.iris,
    brightness: Brightness.dark,
  ).copyWith(
    primary: AppColors.iris,
    secondary: AppColors.violet,
    surface: AppColors.surface,
    error: AppColors.danger,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    fontFamily: 'SpaceGrotesk',
    scaffoldBackgroundColor: AppColors.ink,
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.light,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.surfaceHigh,
      contentTextStyle: AppText.body.copyWith(color: AppColors.textPrimary),
      actionTextColor: AppColors.lime,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.strokeStrong),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      dragHandleColor: AppColors.strokeStrong,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: AppColors.iris,
      selectionHandleColor: AppColors.iris,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: CupertinoPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    }),
  );
}

/// Formats a rupee amount with Indian digit grouping: 1234567 -> ₹12,34,567.
String formatInr(num value) {
  final digits = value.round().abs().toString();
  String grouped;
  if (digits.length <= 3) {
    grouped = digits;
  } else {
    final last3 = digits.substring(digits.length - 3);
    var rest = digits.substring(0, digits.length - 3);
    final parts = <String>[];
    while (rest.length > 2) {
      parts.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) parts.insert(0, rest);
    grouped = '${parts.join(',')},$last3';
  }
  return '${value < 0 ? '-' : ''}₹$grouped';
}
