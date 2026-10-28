import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pengingat_tagihan/screens/add_bill_screen.dart';
import 'package:pengingat_tagihan/utils/formatters.dart';

// AddBillScreen baru membutuhkan BillProvider saat menyimpan, jadi kolom
// tanggalnya bisa diuji tanpa Firebase.

Widget _host() => MaterialApp(
  locale: const Locale('id', 'ID'),
  supportedLocales: const [Locale('id', 'ID')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  home: const AddBillScreen(),
);

Future<void> _showField(WidgetTester tester) async {
  await tester.pumpWidget(_host());
  final field = find.text('Pilih tanggal');
  // scrollUntilVisible berhenti begitu widget-nya sudah dibangun, padahal
  // ListView membangun sedikit di luar layar (cacheExtent): kolomnya bisa saja
  // masih di bawah batas layar uji (800x600) dan ketukan meleset.
  // ensureVisible memastikan kolom benar-benar masuk ke area layar.
  await tester.scrollUntilVisible(
    field,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(field);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('awalnya belum ada tanggal terpilih', (tester) async {
    await _showField(tester);

    expect(find.text('Pilih tanggal'), findsOneWidget);
    expect(find.text('Pilih tanggal jatuh tempo pertama'), findsOneWidget);
  });

  testWidgets('mengetuk kolom membuka kalender', (tester) async {
    await _showField(tester);

    await tester.tap(find.text('Pilih tanggal'));
    await tester.pumpAndSettle();

    expect(find.byType(DatePickerDialog), findsOneWidget);
  });

  testWidgets('memilih tanggal menampilkannya beserta ringkasan', (
    tester,
  ) async {
    await _showField(tester);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    await tester.tap(find.text('Pilih tanggal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pilih')); // tanggal awal kalender = hari ini
    await tester.pumpAndSettle();

    expect(find.byType(DatePickerDialog), findsNothing);
    expect(find.text(Formatters.tanggal(today)), findsWidgets);
    // Preset bawaan: 1 Bulan Sekali.
    expect(find.text('Diulang 1 Bulan Sekali'), findsOneWidget);
  });

  testWidgets('Batal menutup kalender tanpa mengisi tanggal', (tester) async {
    await _showField(tester);

    await tester.tap(find.text('Pilih tanggal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();

    expect(find.byType(DatePickerDialog), findsNothing);
    expect(find.text('Pilih tanggal'), findsOneWidget);
  });
}
