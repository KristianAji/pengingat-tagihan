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
        testWidgets('tidak meluber di ${width.toInt()}dp skala $scale', (
          tester,
        ) async {
          tester.view.physicalSize = Size(width * 3, 800 * 3);
          tester.view.devicePixelRatio = 3.0;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(
            _wrap(
              Builder(
                builder: (context) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
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
            ),
          );

          // Overflow dilaporkan Flutter sebagai exception saat paint.
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  group('SortChipBar — perilaku', () {
    // Bilah ini berupa dropdown + tombol panah (bukan deretan chip), jadi
    // hanya label mode yang AKTIF yang terlihat sebelum dropdown dibuka.
    Finder dropdown() => find.byType(DropdownButton<BillSortMode>);

    testWidgets('menampilkan label Urutkan dan mode yang sedang aktif', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          SortChipBar(
            mode: BillSortMode.jatuhTempo,
            ascending: true,
            onSelect: (_) {},
          ),
        ),
      );

      expect(find.text('Urutkan:'), findsOneWidget);
      expect(find.text(BillSortMode.jatuhTempo.label), findsOneWidget);
    });

    testWidgets('membuka dropdown menampilkan semua mode', (tester) async {
      await tester.pumpWidget(
        _wrap(
          SortChipBar(
            mode: BillSortMode.jatuhTempo,
            ascending: true,
            onSelect: (_) {},
          ),
        ),
      );

      await tester.tap(dropdown());
      await tester.pumpAndSettle();

      for (final mode in BillSortMode.values) {
        expect(find.text(mode.label), findsWidgets);
      }
    });

    testWidgets('panah arah naik memakai panah ke atas', (tester) async {
      await tester.pumpWidget(
        _wrap(
          SortChipBar(
            mode: BillSortMode.jenis,
            ascending: true,
            onSelect: (_) {},
          ),
        ),
      );

      expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
      expect(find.byIcon(Icons.arrow_downward), findsNothing);
    });

    testWidgets('panah arah turun memakai panah ke bawah', (tester) async {
      await tester.pumpWidget(
        _wrap(
          SortChipBar(
            mode: BillSortMode.metode,
            ascending: false,
            onSelect: (_) {},
          ),
        ),
      );

      expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
      expect(find.byIcon(Icons.arrow_upward), findsNothing);
    });

    testWidgets('memilih mode lain di dropdown memanggil onSelect', (
      tester,
    ) async {
      BillSortMode? dipilih;
      await tester.pumpWidget(
        _wrap(
          SortChipBar(
            mode: BillSortMode.jatuhTempo,
            ascending: true,
            onSelect: (m) => dipilih = m,
          ),
        ),
      );

      await tester.tap(dropdown());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Frekuensi Pengingat').last);
      await tester.pumpAndSettle();

      expect(dipilih, BillSortMode.frekuensi);
    });

    // Dropdown tetap memanggil onChanged saat item yang sama dipilih ulang;
    // tanpa penjagaan di widget, arah urutan ikut terbalik tanpa disengaja.
    testWidgets('memilih ulang mode yang aktif tidak memanggil onSelect', (
      tester,
    ) async {
      BillSortMode? dipilih;
      await tester.pumpWidget(
        _wrap(
          SortChipBar(
            mode: BillSortMode.jatuhTempo,
            ascending: true,
            onSelect: (m) => dipilih = m,
          ),
        ),
      );

      await tester.tap(dropdown());
      await tester.pumpAndSettle();
      await tester.tap(find.text(BillSortMode.jatuhTempo.label).last);
      await tester.pumpAndSettle();

      expect(dipilih, isNull);
    });

    testWidgets('mengetuk panah memanggil onSelect dengan mode aktif', (
      tester,
    ) async {
      BillSortMode? dipilih;
      await tester.pumpWidget(
        _wrap(
          SortChipBar(
            mode: BillSortMode.metode,
            ascending: true,
            onSelect: (m) => dipilih = m,
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.arrow_upward));

      // Mode yang sama diketuk lagi = membalik arah (lihat nextSortState).
      expect(dipilih, BillSortMode.metode);
    });
  });
}
