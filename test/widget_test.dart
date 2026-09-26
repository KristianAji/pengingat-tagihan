import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pengingat_tagihan/models/bill.dart';
import 'package:pengingat_tagihan/utils/formatters.dart';
import 'package:pengingat_tagihan/widgets/dashboard_bill_card.dart';

// Catatan: alur penuh aplikasi butuh Firebase (main.dart memanggil
// Firebase.initializeApp), jadi di sini kita uji logika & widget murni
// yang tidak bergantung pada Firebase.

Bill _sampleBill({int repeatEvery = 1, RepeatUnit unit = RepeatUnit.bulan}) {
  return Bill(
    id: '1',
    name: 'Wi-Fi',
    type: BillType.tagihan,
    repeatEvery: repeatEvery,
    repeatUnit: unit,
    dueDate: DateTime(2026, 1, 10),
    reminderOffsets: const [7, 3, 1],
    estimatedCost: 350000,
    paymentMethod: 'Dana',
    createdAt: DateTime(2026, 1, 1),
  );
}

void main() {
  test('Formatters.rupiah memformat angka ke Rupiah', () {
    expect(Formatters.rupiah(350000), contains('350.000'));
  });

  test('Bill.nextDueDate maju satu periode', () {
    final bill = _sampleBill(repeatEvery: 1, unit: RepeatUnit.bulan);
    expect(bill.nextDueDate, DateTime(2026, 2, 10));
  });

  test('Bill.repeatDescription & reminderDescription benar', () {
    final bill = _sampleBill(repeatEvery: 30, unit: RepeatUnit.hari);
    expect(bill.repeatDescription, '30 Hari Sekali');
    expect(bill.reminderDescription, 'H-7, H-3, H-1');
  });

  test('Bill toMap/fromMap round-trip', () {
    final bill = _sampleBill();
    final restored = Bill.fromMap(bill.toMap());
    expect(restored.name, bill.name);
    expect(restored.estimatedCost, bill.estimatedCost);
    expect(restored.dueDate, bill.dueDate);
  });

  testWidgets('TypeBadge menampilkan label jenis', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: TypeBadge(type: BillType.belanja)),
    ));
    expect(find.text('Belanja'), findsOneWidget);
  });
}
