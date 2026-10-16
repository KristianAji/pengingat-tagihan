import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pengingat_tagihan/widgets/app_logo.dart';

void main() {
  // Bagian yang paling gampang salah adalah pendaftaran asetnya di pubspec:
  // tanpa itu, `Image.asset` baru gagal saat aplikasi jalan di HP, bukan saat
  // analyze. Karena itu berkasnya dibaca langsung di sini.
  test('berkas logo terdaftar sebagai aset', () async {
    final data = await rootBundle.load('assets/icon/app_icon_foreground.png');
    expect(data.lengthInBytes, greaterThan(0));
  });

  testWidgets('kotak gambar mengikuti ukuran subjek yang diminta',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Center(child: AppLogo(size: 74))),
    ));

    // Subjek hanya menempati 66% kanvas, jadi kotaknya harus 1,515x lebih besar
    // dari `size` — kalau tidak, maskotnya tampil lebih kecil dari icon yang
    // digantikannya.
    final kotak = tester.getSize(find.byType(AppLogo));
    expect(kotak.width, closeTo(74 * 1.515, 0.01));
    expect(kotak.height, closeTo(74 * 1.515, 0.01));
  });

  testWidgets('ukuran bisa diperbesar untuk keadaan kosong', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Center(child: AppLogo(size: 96))),
    ));

    final kotak = tester.getSize(find.byType(AppLogo));
    expect(kotak.width, closeTo(96 * 1.515, 0.01));
  });
}
