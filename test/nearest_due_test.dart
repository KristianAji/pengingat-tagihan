import 'package:flutter_test/flutter_test.dart';

import 'package:pengingat_tagihan/models/bill.dart';
import 'package:pengingat_tagihan/utils/nearest_due.dart';

Bill _bill(String id, DateTime dueDate) {
  return Bill(
    id: id,
    name: id,
    type: BillType.tagihan,
    repeatEvery: 1,
    repeatUnit: RepeatUnit.bulan,
    dueDate: dueDate,
    reminderOffsets: const [3, 1],
    estimatedCost: 100000,
    paymentMethod: 'Dana',
    createdAt: DateTime(2026, 1, 1),
  );
}

List<String> _ids(List<Bill> bills) => bills.map((b) => b.id).toList();

void main() {
  final now = DateTime.now();
  // Hari terakhir bulan ini: pasti masih "bulan ini", tidak peduli tanggal
  // berapa tes dijalankan.
  final akhirBulan = DateTime(now.year, now.month + 1, 0);
  // Tanggal 15 bulan depan: pasti di luar bulan ini.
  final bulanDepan = DateTime(now.year, now.month + 1, 15);
  final telat = DateTime(now.year, now.month, now.day - 5);

  group('nearestDueBills', () {
    test('tagihan bulan depan TIDAK ikut', () {
      final hasil = nearestDueBills([
        _bill('depan', bulanDepan),
        _bill('ini', akhirBulan),
      ]);

      expect(_ids(hasil), ['ini']);
    });

    test('kosong bila semua tagihan jatuh tempo bulan depan', () {
      final hasil = nearestDueBills([
        _bill('a', bulanDepan),
        _bill('b', DateTime(now.year, now.month + 2, 1)),
      ]);

      expect(hasil, isEmpty);
    });

    test('tagihan telat ikut dan berada paling depan', () {
      final hasil = nearestDueBills([
        _bill('ini', akhirBulan),
        _bill('telat', telat),
      ]);

      expect(_ids(hasil), ['telat', 'ini']);
    });

    test('dibatasi dua, urut dari yang paling dekat', () {
      final hasil = nearestDueBills([
        _bill('akhir', akhirBulan),
        _bill('telat', telat),
        _bill('telat-lama', DateTime(now.year, now.month, now.day - 20)),
      ]);

      expect(_ids(hasil), ['telat-lama', 'telat']);
    });

    test('limit bisa diatur', () {
      final hasil = nearestDueBills([
        _bill('a', telat),
        _bill('b', akhirBulan),
      ], limit: 1);

      expect(hasil, hasLength(1));
    });

    test('daftar kosong -> kosong', () {
      expect(nearestDueBills(const []), isEmpty);
    });
  });
}
