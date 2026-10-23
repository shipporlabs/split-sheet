import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Colour tokens. Dark "studio night" palette with an amber accent.
class C {
  static const bg = Color(0xFF100F0D);
  static const bgDeep = Color(0xFF070706);
  static const surface = Color(0xFF1B1A17);
  static const surface2 = Color(0xFF262420);
  static const surfaceWarm = Color(0xFF1E1B14);
  static const nav = Color(0xFF151411);
  static const line = Color(0xFF2E2C27);
  static const line2 = Color(0xFF3A3731);
  static const lineWarm = Color(0xFF4A3C20);
  static const text = Color(0xFFF3EFE7);
  static const text2 = Color(0xFFCFC9BD);
  static const muted = Color(0xFFA8A296);
  static const faint = Color(0xFF8E897E);
  static const accent = Color(0xFFF4B740);
  static const accentSoft = Color(0xFFF4D08A);
  static const accentBg = Color(0xFF2A2215);
  static const onAccent = Color(0xFF1A1408);
  static const green = Color(0xFF5FD3A6);
  static const greenBg = Color(0xFF173327);
  static const greenLine = Color(0xFF2F6B53);
  static const onGreen = Color(0xFF0F2A20);
  static const red = Color(0xFFF5A487);
  static const redBg = Color(0xFF2A1712);
  static const redLine = Color(0xFF5A2E22);

  static const _split = [
    Color(0xFFF4B740),
    Color(0xFFC98A2B),
    Color(0xFF7A5A26),
    Color(0xFFE8C98F),
    Color(0xFF9E7B45),
    Color(0xFFFFE1A3),
    Color(0xFFB0702A),
    Color(0xFF5C4520),
    Color(0xFFD9A55B),
    Color(0xFF4A3818),
  ];

  /// Colour for the i-th person in a split bar.
  static Color split(int i) => _split[i % _split.length];
}

Color withA(Color c, double opacity) => c.withAlpha((opacity * 255).round());

/// Text styles: Bricolage Grotesque for display, DM Sans for UI, JetBrains Mono for numbers and hashes.
class T {
  static TextStyle display(double size,
      {Color color = C.text, FontWeight weight = FontWeight.w700, double? height}) {
    final base = TextStyle(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: -size * 0.02,
    );
    try {
      return GoogleFonts.getFont('Bricolage Grotesque', textStyle: base);
    } catch (_) {
      return GoogleFonts.spaceGrotesk(textStyle: base);
    }
  }

  static TextStyle body(double size,
          {Color color = C.text, FontWeight weight = FontWeight.w400, double? height}) =>
      GoogleFonts.dmSans(fontSize: size, fontWeight: weight, color: color, height: height);

  static TextStyle mono(double size, {Color color = C.text, FontWeight weight = FontWeight.w400}) =>
      GoogleFonts.jetBrainsMono(fontSize: size, fontWeight: weight, color: color);
}

ThemeData buildTheme() {
  final base = ThemeData(useMaterial3: true, brightness: Brightness.dark);
  final textTheme =
      GoogleFonts.dmSansTextTheme(base.textTheme).apply(bodyColor: C.text, displayColor: C.text);

  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: c, width: w),
      );

  return base.copyWith(
    scaffoldBackgroundColor: C.bg,
    colorScheme: const ColorScheme.dark(
      primary: C.accent,
      onPrimary: C.onAccent,
      secondary: C.green,
      onSecondary: C.onGreen,
      surface: C.surface,
      onSurface: C.text,
      error: C.red,
      onError: C.onAccent,
    ),
    textTheme: textTheme,
    dividerColor: C.line,
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: C.accent,
      selectionColor: Color(0x55F4B740),
      selectionHandleColor: C.accent,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: C.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      hintStyle: T.body(15, color: C.faint),
      labelStyle: T.body(14, color: C.muted),
      floatingLabelStyle: T.body(14, color: C.accent),
      errorStyle: T.body(12, color: C.red),
      border: border(C.line2),
      enabledBorder: border(C.line2),
      focusedBorder: border(C.accent, 2),
      errorBorder: border(C.red),
      focusedErrorBorder: border(C.red, 2),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: C.surface2,
      contentTextStyle: T.body(14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: C.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: C.accent),
  );
}
