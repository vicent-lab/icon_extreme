import 'package:material_ui/material_ui.dart';
import 'package:google_fonts/google_fonts.dart';

/// ICON brand: deep charcoal-green + gold on warm concrete. Calm, lots of white space.
class Brand {
  static const ink = Color(0xFF17251F);
  static const gold = Color(0xFFC9A227);
  static const concrete = Color(0xFFF4F1EA);
  static const line = Color(0x1A0F1713);
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: Brand.ink,
    primary: Brand.ink,
    secondary: Brand.gold,
    surface: Colors.white,
    brightness: Brightness.light,
  );
  final text = GoogleFonts.manropeTextTheme();
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    textTheme: text,
    scaffoldBackgroundColor: Brand.concrete,
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Brand.line),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      filled: true,
      fillColor: Colors.white,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Brand.ink,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    dividerTheme: const DividerThemeData(color: Brand.line, space: 1),
  );
}
