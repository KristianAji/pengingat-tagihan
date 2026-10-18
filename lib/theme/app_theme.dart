import 'package:flutter/material.dart';

/// Konstanta desain global.
/// Corner radius di-fix ke 20 untuk semua komponen (sesuai spesifikasi).
class AppRadius {
  static const double all = 20;
  static BorderRadius get br => BorderRadius.circular(all);
  static RoundedRectangleBorder get shape =>
      RoundedRectangleBorder(borderRadius: br);
}

class AppColors {
  static const Color primary = Color(0xFF16153E); // navy outline ikon
  static const Color primaryDark = Color(0xFF0D0C2B); // navy lebih gelap
  static const Color tagihan = Color(0xFFF6877A); // coral
  static const Color belanja = Color(0xFFF8BD7F); // oranye peach
  static const Color danger = Color(0xFFFA5252); // tetap
  static const Color warning = Color(0xFFF08C00); // tetap

  static const Color background = Colors.white; // tetap
  static const Color surface = Color(0xFFF4F6FB); // tetap
  static const Color card = Colors.white;
  static const Color textDark = Color(0xFF16153E); // navy, senada outline ikon
  static const Color textMuted = Color(0xFF868E96);
  static const Color hint = Color(0xFFADB5BD);

  static Color forType(bool isTagihan) => isTagihan ? tagihan : belanja;
}

class AppTheme {
  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
      ),
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: 'Roboto',
    );

    return base.copyWith(
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0,
        // Kartu putih di atas latar putih butuh garis tepi supaya batasnya
        // terlihat. Sebelumnya latar halaman abu-abu yang memisahkannya.
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.br,
          side: const BorderSide(color: Color(0xFFE9ECEF)),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: AppRadius.shape,
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: AppRadius.shape,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        // Teks contoh ("Contoh: Stok Skincare", dll.) dibuat lebih abu-abu
        // supaya jelas beda dengan isian asli.
        hintStyle: const TextStyle(color: AppColors.hint),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadius.br,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.br,
          borderSide: const BorderSide(color: Color(0xFFE9ECEF)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.br,
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        centerTitle: false,
      ),
    );
  }
}
