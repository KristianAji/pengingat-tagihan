import 'package:flutter_test/flutter_test.dart';

import 'package:pengingat_tagihan/models/bill.dart';
import 'package:pengingat_tagihan/utils/emergency_cash.dart';

Bill _bill({
  required String id,
  BillType type = BillType.tagihan,
  int repeatEvery = 1,
  RepeatUnit repeatUnit = RepeatUnit.bulan,
  double estimatedCost = 100000,
  bool? isMandatory,
}) {
  return Bill(
    id: id,
    name: id,
    type: type,
    repeatEvery: repeatEvery,
    repeatUnit: repeatUnit,
    dueDate: DateTime(2026, 1, 10),
    reminderOffsets: const [7, 3, 1],
    estimatedCost: estimatedCost,
    paymentMethod: 'Dana',
    createdAt: DateTime(2026, 1, 1),
    isMandatory: isMandatory,
  );
}

void main() {
  group('Bill.isMandatory — bawaan dari jenis', () {
    test('Tagihan dianggap wajib, Belanja tidak', () {
      expect(_bill(id: 'a').isMandatory, isTrue);
      expect(_bill(id: 'b', type: BillType.belanja).isMandatory, isFalse);
    });

    test('bisa ditimpa lewat konstruktor', () {
      expect(_bill(id: 'a', isMandatory: false).isMandatory, isFalse);
      expect(
        _bill(id: 'b', type: BillType.belanja, isMandatory: true).isMandatory,
        isTrue,
      );
    });

    test('copyWith mengubah penanda tanpa menyentuh field lain', () {
      final asli = _bill(id: 'a', estimatedCost: 250000);
      final ubah = asli.copyWith(isMandatory: false);

      expect(ubah.isMandatory, isFalse);
      expect(ubah.estimatedCost, 250000);
      expect(ubah.name, asli.name);
      expect(ubah.dueDate, asli.dueDate);
    });

    test('dokumen lama tanpa field isMandatory jatuh ke bawaannya', () {
      final map = _bill(id: 'a').toMap()..remove('isMandatory');
      expect(Bill.fromMap(map).isMandatory, isTrue);

      final mapBelanja = _bill(id: 'b', type: BillType.belanja).toMap()
        ..remove('isMandatory');
      expect(Bill.fromMap(mapBelanja).isMandatory, isFalse);
    });

    test('bolak-balik toMap/fromMap mempertahankan penanda', () {
      final b = _bill(id: 'a', isMandatory: false);
      expect(Bill.fromMap(b.toMap()).isMandatory, isFalse);
      expect(Bill.fromJson(b.toJson()).isMandatory, isFalse);
    });
  });

  group('monthlyCost — normalisasi perulangan ke bulanan', () {
    test('bulanan apa adanya', () {
      expect(
        EmergencyCashCalculator.monthlyCost(
          _bill(id: 'a', estimatedCost: 500000),
        ),
        500000,
      );
    });

    test('tahunan dibagi 12', () {
      final pajak = _bill(id: 'a', repeatEvery: 12, estimatedCost: 1200000);
      expect(EmergencyCashCalculator.monthlyCost(pajak), closeTo(100000, 0.01));
    });

    test('3 & 6 bulanan dibagi sesuai periodenya', () {
      expect(
        EmergencyCashCalculator.monthlyCost(
          _bill(id: 'a', repeatEvery: 3, estimatedCost: 900000),
        ),
        closeTo(300000, 0.01),
      );
      expect(
        EmergencyCashCalculator.monthlyCost(
          _bill(id: 'b', repeatEvery: 6, estimatedCost: 600000),
        ),
        closeTo(100000, 0.01),
      );
    });

    test('mingguan dikali rata-rata jumlah minggu per bulan', () {
      // 30,4375 hari / 7 hari = 4,348 minggu per bulan.
      final mingguan = _bill(
        id: 'a',
        repeatEvery: 1,
        repeatUnit: RepeatUnit.minggu,
        estimatedCost: 50000,
      );
      expect(
        EmergencyCashCalculator.monthlyCost(mingguan),
        closeTo(50000 * 30.4375 / 7, 0.01),
      );
    });

    test('harian dikali rata-rata jumlah hari per bulan', () {
      final harian = _bill(
        id: 'a',
        repeatEvery: 30,
        repeatUnit: RepeatUnit.hari,
        estimatedCost: 300000,
      );
      expect(
        EmergencyCashCalculator.monthlyCost(harian),
        closeTo(300000 * 30.4375 / 30, 0.01),
      );
    });

    test('periode 0 tidak menghasilkan pembagian nol', () {
      final rusak = _bill(id: 'a', repeatEvery: 0, estimatedCost: 100000);
      expect(EmergencyCashCalculator.monthlyCost(rusak), 0);
    });
  });

  group('calculate — dana darurat minimal', () {
    test('mengalikan kebutuhan bulanan dengan rentang yang dipilih', () {
      final bills = [
        _bill(id: 'kos', estimatedCost: 1000000),
        _bill(id: 'listrik', estimatedCost: 200000),
      ];

      final r3 = EmergencyCashCalculator.calculate(bills, 3);
      expect(r3.monthlyMandatory, 1200000);
      expect(r3.target, 3600000);
      expect(r3.itemCount, 2);

      expect(EmergencyCashCalculator.calculate(bills, 6).target, 7200000);
      expect(EmergencyCashCalculator.calculate(bills, 12).target, 14400000);
    });

    test('hanya item wajib yang dihitung', () {
      final bills = [
        _bill(id: 'kos', estimatedCost: 1000000),
        // Belanja: bawaannya tidak wajib.
        _bill(id: 'skincare', type: BillType.belanja, estimatedCost: 500000),
        // Tagihan yang sengaja dikeluarkan pengguna.
        _bill(id: 'langganan', estimatedCost: 99000, isMandatory: false),
      ];

      final r = EmergencyCashCalculator.calculate(bills, 6);
      expect(r.itemCount, 1);
      expect(r.monthlyMandatory, 1000000);
      expect(r.target, 6000000);
    });

    test('belanja yang ditandai wajib ikut dihitung', () {
      final bills = [
        _bill(
          id: 'belanja-bulanan',
          type: BillType.belanja,
          estimatedCost: 800000,
          isMandatory: true,
        ),
      ];
      expect(EmergencyCashCalculator.calculate(bills, 3).target, 2400000);
    });

    test('campuran periode dijumlahkan setelah dinormalkan', () {
      final bills = [
        _bill(id: 'kos', estimatedCost: 1000000), // 1.000.000 / bulan
        _bill(id: 'pajak', repeatEvery: 12, estimatedCost: 1200000), // 100.000
        _bill(id: 'air', repeatEvery: 3, estimatedCost: 300000), // 100.000
      ];

      final r = EmergencyCashCalculator.calculate(bills, 6);
      expect(r.monthlyMandatory, closeTo(1200000, 0.01));
      expect(r.target, closeTo(7200000, 0.01));
    });

    test('daftar kosong atau tanpa item wajib menghasilkan nol', () {
      final kosong = EmergencyCashCalculator.calculate([], 6);
      expect(kosong.target, 0);
      expect(kosong.itemCount, 0);
      expect(kosong.isEmpty, isTrue);

      final tanpaWajib = EmergencyCashCalculator.calculate([
        _bill(id: 'a', type: BillType.belanja),
      ], 6);
      expect(tanpaWajib.isEmpty, isTrue);
    });

    test('hasil tidak kosong bila ada item wajib', () {
      final r = EmergencyCashCalculator.calculate([_bill(id: 'a')], 6);
      expect(r.isEmpty, isFalse);
      expect(r.months, 6);
    });
  });
}
