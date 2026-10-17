import 'package:flutter/material.dart';

/// Logo aplikasi (maskot kucing) untuk dipakai DI DALAM layar, bukan icon
/// peluncur — icon peluncur diurus `flutter_launcher_icons` dari
/// `assets/icon/app_icon.png`.
///
/// Berkas yang dipakai `app_icon_foreground.png`, yaitu lapisan depan icon
/// adaptif. Kedua aset icon berlatar bening (sejak 2026-10-17), jadi logo ini
/// tampil polos di atas latar layar putih tanpa kotak yang mengelilinginya.
///
/// Berkasnya sendiri adalah lapisan depan icon adaptif, jadi subjeknya sengaja
/// hanya menempati 72% kanvas (738 dari 1024 px) supaya aman saat dimasking
/// Android. Karena itu `size` di sini berarti ukuran SUBJEK yang terlihat,
/// bukan sisi kotak gambarnya.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 74});

  /// Panjang sisi terpanjang subjek yang terlihat, dalam piksel logis.
  ///
  /// 74 menyamai ukuran icon lonceng Material yang dulu dipakai di halaman
  /// Login dan Tentang Aplikasi.
  final double size;

  /// 1024 / 738 — diukur dari berkasnya lewat `tool/cek_latar_icon.dart`.
  /// Kalau gambarnya dibuat ulang dengan rasio berbeda, angka ini ikut berubah.
  static const double _kanvasPerSubjek = 1.3875;

  @override
  Widget build(BuildContext context) {
    final sisi = size * _kanvasPerSubjek;
    return Image.asset(
      'assets/icon/app_icon_foreground.png',
      width: sisi,
      height: sisi,
      filterQuality: FilterQuality.medium,
    );
  }
}
