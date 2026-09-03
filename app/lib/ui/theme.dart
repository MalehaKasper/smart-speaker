import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Дизайн-система з `Smart Speaker EQ.dc.html` (Claude Design), портована 1:1.
/// Кольори — точна конвертація OKLCH → sRGB (не наближення "на око").
class AppColors {
  AppColors._();

  // Нейтральні (з дизайну — вже sRGB hex)
  static const pageBg = Color(0xFFE4E2DD);
  static const screenBg = Color(0xFFF6F4EF);
  static const ink = Color(0xFF1B1A17);
  static const inkSecondary = Color(0xFF5F5B54);
  static const inkTertiary = Color(0xFF7D786F);
  static const inkLabel = Color(0xFF8F8A82);
  static const inkFaint = Color(0xFFA8A29A);
  static const track = Color(0xFFC9C2B4);
  static const border = Color(0xFFD6D1C6);
  static const borderSoft = Color(0xFFDDD9D1);
  static const divider = Color(0xFFE6E2D9);
  static const volumeAreaBg = Color(0xFFEAE6DD);
  static const graphBg = Color(0xFFEFECE4);
  static const handleBar = Color(0xFFCDC7BA);

  // Акценти — oklch(...) з дизайну, конвертовано точним OKLab-перетворенням
  static const accent = Color(0xFF2750A2); // oklch(0.45 0.14 262)
  static const accentHover = Color(0xFF426EC2); // oklch(0.55 0.14 262)
  static const accentPressed = Color(0xFF194292); // oklch(0.40 0.14 262)
  static const red = Color(0xFFCC272B); // oklch(0.55 0.20 26) — від'ємний Gain, AUX, видалення
  static const redTitle = Color(0xFFB30013); // oklch(0.48 0.20 26)
  static const redSnackAction = Color(0xFFFF847A); // oklch(0.76 0.16 26) — на темному snackbar
  static const redHover = Color(0xFFA90005); // oklch(0.45 0.20 26)
}

class AppText {
  AppText._();

  static TextStyle display = GoogleFonts.spaceGrotesk(
    fontWeight: FontWeight.w500,
    letterSpacing: -0.02 * 16,
    color: AppColors.ink,
  );

  static TextStyle body = GoogleFonts.spaceGrotesk(color: AppColors.ink);

  /// IBM Plex Mono — статуси, лейбли, числові дані (як у дизайні).
  static TextStyle mono({
    double size = 11,
    double letterSpacing = 0.14,
    Color color = AppColors.inkLabel,
    FontWeight weight = FontWeight.w400,
  }) {
    return GoogleFonts.ibmPlexMono(
      fontSize: size,
      letterSpacing: letterSpacing * size,
      color: color,
      fontWeight: weight,
    );
  }
}

ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: Brightness.light,
      primary: AppColors.accent,
      error: AppColors.red,
      surface: AppColors.screenBg,
    ),
    scaffoldBackgroundColor: AppColors.pageBg,
    textTheme: GoogleFonts.spaceGroteskTextTheme(),
  );
  return base.copyWith(
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.screenBg,
      foregroundColor: AppColors.ink,
      elevation: 0,
      titleTextStyle: GoogleFonts.spaceGrotesk(
        fontSize: 20,
        fontWeight: FontWeight.w500,
        color: AppColors.ink,
      ),
    ),
  );
}
