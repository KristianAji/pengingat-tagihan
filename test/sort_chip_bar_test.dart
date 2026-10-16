import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pengingat_tagihan/theme/app_theme.dart';
import 'package:pengingat_tagihan/utils/bill_sort.dart';
import 'package:pengingat_tagihan/widgets/sort_chip_bar.dart';

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

void main() {
  setUpAll(_loadRealFont);

  group('SortChipBar — tata letak', () {
    // Dulu project ini dua kali kena bug overflow karena Row tanpa Expanded.
    // Bilah ini memakai Wrap, jadi harus aman di lebar layar tersempit sekalipun
    // dengan skala huruf besar. Mode frekuensi dipakai karena labelnya paling
    // panjang ("Frekuensi Pengingat") dan sedang aktif sehingga dapat panah.
    for (final width in [320.0, 360.0, 393.0]) {
      for (final scale in [1.0, 1.15, 1.3]) {
        testWidgets('tidak meluber di ${width.toInt()}dp skala $scale',
            (tester) async {
          tester.view.physicalSize = Size(width * 3, 800 * 3);
          tester.view.devicePixelRatio = 3.0;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(_wrap(
            Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: Padding(
                  // Padding yang sama dengan ListView halaman Daftar.
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SortChipBar(
                    mode: BillSortMode.frekuensi,
                    ascending: true,
                    onSelect: (_) {},
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

  group('SortChipBar — perilaku', () {
    testWidgets('menampilkan chip untuk setiap mode', (tester) async {
      await tester.pumpWidget(_wrap(
        SortChipBar(
          mode: BillSortMode.jatuhTempo,
          ascending: true,
          onSelect: (_) {},
        ),
      ));

      for (final mode in BillSortMode.values) {
        expect(find.text(mode.label), findsOneWidget);
      }
      expect(find.text('Urutkan:'), findsOneWidget);
    });

    testWidgets('panah arah hanya muncul di chip yang aktif', (tester) async {
      await tester.pumpWidget(_wrap(
        SortChipBar(
          mode: BillSortMode.metode,
          ascending: false,
          onSelect: (_) {},
        ),
      ));

      expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
      expect(find.byIcon(Icons.arrow_upward), findsNothing);
    });

    testWidgets('arah naik memakai panah ke atas', (tester) async {
      await tester.pumpWidget(_wrap(
        SortChipBar(
          mode: BillSortMode.jenis,
          ascending: true,
          onSelect: (_) {},
        ),
      ));

      expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
      expect(find.byIcon(Icons.arrow_downward), findsNothing);
    });

    testWidgets('ketuk chip memanggil onSelect dengan mode itu', (tester) async {
      BillSortMode? tapped;
      await tester.pumpWidget(_wrap(
        SortChipBar(
          mode: BillSortMode.jatuhTempo,
          ascending: true,
          onSelect: (m) => tapped = m,
        ),
      ));

      await tester.tap(find.text('Frekuensi Pengingat'));
      expect(tapped, BillSortMode.frekuensi);
    });
  });
}
