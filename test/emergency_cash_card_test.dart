import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pengingat_tagihan/theme/app_theme.dart';
import 'package:pengingat_tagihan/utils/emergency_cash.dart';
import 'package:pengingat_tagihan/widgets/emergency_cash_card.dart';

// Font bawaan widget test adalah font kotak (setiap huruf selebar font-size),
// sehingga ukuran teks membengkak dan pengukuran tata letak jadi tidak jujur.
// Daftarkan font asli sebagai 'Roboto' — family yang dipakai AppTheme — supaya
// lebar teks realistis. Bila fontnya tidak ada, tes tetap jalan apa adanya.
Future<void> _loadRealFont() async {
  final file = File(r'C:\Windows\Fonts\segoeui.ttf');
  if (!file.existsSync()) return;
  final loader = FontLoader('Roboto')
    ..addFont(Future.value(file.readAsBytesSync().buffer.asByteData()));
  await loader.load();
}

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: child),
    );

EmergencyCashResult _result({
  int months = 6,
  double monthly = 2450000,
  int itemCount = 3,
}) {
  return EmergencyCashResult(
    months: months,
    monthlyMandatory: itemCount == 0 ? 0 : monthly,
    target: itemCount == 0 ? 0 : monthly * months,
    itemCount: itemCount,
  );
}

void main() {
  setUpAll(_loadRealFont);

  group('EmergencyCashCardView — tata letak', () {
    // Kartu ini memuat nominal panjang ("Rp 14.700.000"), kalimat keterangan,
    // tiga chip, dan catatan dua baris — semuanya berpotensi meluber di layar
    // sempit dengan skala huruf besar.
    for (final width in [320.0, 360.0, 393.0]) {
      for (final scale in [1.0, 1.15, 1.3]) {
        testWidgets('tidak meluber di ${width.toInt()}dp skala $scale',
            (tester) async {
          tester.view.physicalSize = Size(width * 3, 900 * 3);
          tester.view.devicePixelRatio = 3.0;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(_wrap(
            Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: Padding(
                  // Padding yang sama dengan ListView halaman Beranda.
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: EmergencyCashCardView(
                    result: _result(months: 12, monthly: 9850000),
                    selectedMonths: 12,
                    onSelectMonths: (_) {},
                  ),
                ),
              ),
            ),
          ));

          // Overflow dilaporkan Flutter sebagai exception saat paint.
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  group('EmergencyCashCardView — isi', () {
    testWidgets('menampilkan nominal, keterangan, dan chip rentang',
        (tester) async {
      await tester.pumpWidget(_wrap(EmergencyCashCardView(
        result: _result(months: 6, monthly: 2450000, itemCount: 3),
        selectedMonths: 6,
        onSelectMonths: (_) {},
      )));

      expect(find.text('Dana Darurat'), findsOneWidget);
      expect(find.text('Rp 14.700.000'), findsOneWidget);
      expect(find.textContaining('Rp 2.450.000 / bulan'), findsOneWidget);
      expect(find.textContaining('3 item wajib'), findsOneWidget);
      for (final m in EmergencyCashCalculator.pilihanBulan) {
        expect(find.text('$m bulan'), findsOneWidget);
      }
    });

    testWidgets('menjelaskan bila belum ada item wajib', (tester) async {
      await tester.pumpWidget(_wrap(EmergencyCashCardView(
        result: _result(itemCount: 0),
        selectedMonths: 6,
        onSelectMonths: (_) {},
      )));

      expect(find.text('Rp 0'), findsOneWidget);
      expect(find.textContaining('Belum ada item wajib'), findsOneWidget);
    });

    testWidgets('ketuk chip memanggil onSelectMonths dengan rentang itu',
        (tester) async {
      int? dipilih;
      await tester.pumpWidget(_wrap(EmergencyCashCardView(
        result: _result(),
        selectedMonths: 6,
        onSelectMonths: (m) => dipilih = m,
      )));

      await tester.tap(find.text('12 bulan'));
      expect(dipilih, 12);

      await tester.tap(find.text('3 bulan'));
      expect(dipilih, 3);
    });
  });
}
