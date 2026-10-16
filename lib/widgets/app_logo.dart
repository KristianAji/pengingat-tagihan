import 'package:flutter/material.dart';

/// Logo aplikasi (maskot kucing) untuk dipakai DI DALAM layar, bukan icon
/// peluncur — icon peluncur diurus `flutter_launcher_icons` dari
/// `assets/icon/app_icon.png`.
///
/// Berkas yang dipakai `app_icon_foreground.png`, bukan `app_icon.png`:
/// keduanya terlihat sama di penampil gambar, tapi yang pertama latarnya bening
/// (alpha 0) dan yang kedua putih pekat (alpha 255). Di atas latar aplikasi
/// (`AppColors.surface`, #F4F6FB) versi putih itu akan tampak sebagai kotak
/// putih yang tidak diinginkan.
///
/// Berkasnya sendiri adalah lapisan depan icon adaptif, jadi subjeknya sengaja
/// hanya menempati 66% kanvas (676 dari 1024 px) supaya aman saat dimasking
/// Android. Karena itu `size` di sini berarti ukuran SUBJEK yang terlihat,
/// bukan sisi kotak gambarnya.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 74});

  /// Panjang sisi terpanjang subjek yang terlihat, dalam piksel logis.
  ///
  /// 74 menyamai ukuran icon lonceng Material yang dulu dipakai di halaman
  /// Login dan Tentang Aplikasi.
  final double size;

  /// 1024 / 676 — diukur dari berkasnya lewat `tool/cek_latar_icon.dart`.
  /// Kalau gambarnya dibuat ulang dengan rasio berbeda, angka ini ikut berubah.
  static const double _kanvasPerSubjek = 1.515;

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
