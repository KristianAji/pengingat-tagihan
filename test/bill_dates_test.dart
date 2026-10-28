import 'package:flutter_test/flutter_test.dart';

import 'package:pengingat_tagihan/models/bill.dart';

Bill _monthly(
  DateTime dueDate, {
  int? anchorDay,
  int every = 1,
  RepeatUnit unit = RepeatUnit.bulan,
}) {
  return Bill(
    id: 'x',
    name: 'Cicilan',
    type: BillType.tagihan,
    repeatEvery: every,
    repeatUnit: unit,
    dueDate: dueDate,
    anchorDay: anchorDay,
    reminderOffsets: const [3, 1],
    estimatedCost: 500000,
    paymentMethod: 'Transfer',
    createdAt: DateTime(2026, 1, 1),
  );
}

/// Meniru yang dilakukan FirestoreService.markAsPaid berulang kali: tiap
/// pelunasan menyimpan nextDueDate sebagai dueDate baru, lalu dihitung lagi
/// dari tanggal tersimpan itu.
List<DateTime> _chain(Bill start, int steps) {
  final out = <DateTime>[];
  var bill = start;
  for (var i = 0; i < steps; i++) {
    final next = bill.nextDueDate;
    out.add(next);
    bill = bill.copyWith(dueDate: next);
  }
  return out;
}

void main() {
  group('perulangan bulanan dengan anchorDay', () {
    test('tanggal 31 kembali ke 31 setelah bulan pendek', () {
      final dates = _chain(_monthly(DateTime(2026, 1, 31), anchorDay: 31), 5);
      expect(dates, [
        DateTime(2026, 2, 28),
        DateTime(2026, 3, 31), // sebelum perbaikan: 28 Mar
        DateTime(2026, 4, 30),
        DateTime(2026, 5, 31), // sebelum perbaikan: 30 Mei
        DateTime(2026, 6, 30),
      ]);
    });

    test('tahun kabisat memakai 29 Februari lalu kembali ke 31', () {
      final dates = _chain(_monthly(DateTime(2028, 1, 31), anchorDay: 31), 2);
      expect(dates, [DateTime(2028, 2, 29), DateTime(2028, 3, 31)]);
    });

    test('pergantian tahun', () {
      final dates = _chain(_monthly(DateTime(2026, 12, 31), anchorDay: 31), 2);
      expect(dates, [DateTime(2027, 1, 31), DateTime(2027, 2, 28)]);
    });

    test('tanggal 30 hanya terpotong di Februari', () {
      final dates = _chain(_monthly(DateTime(2026, 1, 30), anchorDay: 30), 3);
      expect(dates, [
        DateTime(2026, 2, 28),
        DateTime(2026, 3, 30),
        DateTime(2026, 4, 30),
      ]);
    });

    test('tiap 2 bulan tetap menjaga tanggal asli', () {
      final dates = _chain(
        _monthly(DateTime(2026, 1, 31), anchorDay: 31, every: 2),
        3,
      );
      expect(dates, [
        DateTime(2026, 3, 31),
        DateTime(2026, 5, 31),
        DateTime(2026, 7, 31),
      ]);
    });

    test('tanggal biasa (<= 28) tidak berubah', () {
      final dates = _chain(_monthly(DateTime(2026, 1, 15), anchorDay: 15), 3);
      expect(dates, [
        DateTime(2026, 2, 15),
        DateTime(2026, 3, 15),
        DateTime(2026, 4, 15),
      ]);
    });

    test('nextDueDateAfter melewati periode telat tanpa melorot', () {
      // Jatuh tempo 31 Jan, baru dilunasi 15 Mar: lompat ke 31 Mar.
      final bill = _monthly(DateTime(2026, 1, 31), anchorDay: 31);
      expect(bill.nextDueDateAfter(DateTime(2026, 3, 15)), DateTime(2026, 3, 31));
    });

    test('anchorDay di luar 1..31 diabaikan, pakai dueDate.day', () {
      final bill = _monthly(DateTime(2026, 1, 10), anchorDay: 99);
      expect(bill.nextDueDate, DateTime(2026, 2, 10));
    });
  });

  group('dokumen lama tanpa anchorDay', () {
    test('perilaku lama dipertahankan (pakai dueDate.day)', () {
      final dates = _chain(_monthly(DateTime(2026, 1, 31)), 2);
      expect(dates, [DateTime(2026, 2, 28), DateTime(2026, 3, 28)]);
    });

    test('fromMap tanpa kunci anchorDay menghasilkan null', () {
      final map = _monthly(DateTime(2026, 1, 31), anchorDay: 31).toMap()
        ..remove('anchorDay');
      expect(Bill.fromMap(map).anchorDay, isNull);
    });
  });

  group('penyimpanan', () {
    test('toMap/fromMap menjaga anchorDay', () {
      final bill = _monthly(DateTime(2026, 2, 28), anchorDay: 31);
      expect(Bill.fromMap(bill.toMap()).anchorDay, 31);
    });

    test('copyWith(dueDate) mempertahankan anchorDay', () {
      final bill = _monthly(DateTime(2026, 1, 31), anchorDay: 31);
      expect(bill.copyWith(dueDate: DateTime(2026, 2, 28)).anchorDay, 31);
    });

    test('perulangan hari/minggu tidak terpengaruh', () {
      final harian = _monthly(
        DateTime(2026, 1, 31),
        every: 30,
        unit: RepeatUnit.hari,
      );
      expect(harian.nextDueDate, DateTime(2026, 3, 2));
      final mingguan = _monthly(
        DateTime(2026, 1, 31),
        every: 2,
        unit: RepeatUnit.minggu,
      );
      expect(mingguan.nextDueDate, DateTime(2026, 2, 14));
    });
  });
}
