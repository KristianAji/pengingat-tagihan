import 'package:flutter_test/flutter_test.dart';

import 'package:pengingat_tagihan/models/bill.dart';
import 'package:pengingat_tagihan/models/user_profile.dart';
import 'package:pengingat_tagihan/utils/burn_rate.dart';

// "Sekarang": Rab 28 Okt 2026 pukul 10:00. Gajian tanggal 25, jadi gajian
// berikutnya 25 Nov 2026 dan sisa harinya 28.
final _now = DateTime(2026, 10, 28, 10, 0);
final _payday = DateTime(2026, 11, 25);

Bill _bill({
  String id = 'a',
  required DateTime due,
  int every = 1,
  RepeatUnit unit = RepeatUnit.bulan,
  double cost = 100000,
  BillType type = BillType.tagihan,
  bool? mandatory,
  int? limit,
  int? remaining,
}) {
  return Bill(
    id: id,
    name: id,
    type: type,
    repeatEvery: every,
    repeatUnit: unit,
    dueDate: due,
    reminderOffsets: const [7, 3, 1],
    estimatedCost: cost,
    paymentMethod: 'Dana',
    repeatLimit: limit,
    remaining: remaining,
    createdAt: DateTime(2026, 1, 1),
    isMandatory: mandatory,
  );
}

UserProfile _profile(double income) =>
    UserProfile(totalPemasukan: income, tanggalGajian: 25);

BurnRateResult _hitung(double income, List<Bill> bills) =>
    BurnRateCalculator.calculate(_profile(income), bills, now: _now);

void main() {
  group('nextPayday', () {
    test('gajian bulan ini sudah lewat -> bulan depan', () {
      expect(BurnRateCalculator.nextPayday(25, _now), DateTime(2026, 11, 25));
    });

    test('gajian masih di depan -> bulan ini', () {
      expect(BurnRateCalculator.nextPayday(30, _now), DateTime(2026, 10, 30));
    });

    test('tanggal 31 dipotong ke akhir bulan pendek', () {
      expect(
        BurnRateCalculator.nextPayday(31, DateTime(2026, 2, 10)),
        DateTime(2026, 2, 28),
      );
    });
  });

  group('Bill.occurrencesUntil', () {
    test('bulanan yang jatuh tempo sebelum gajian dihitung sekali', () {
      final b = _bill(due: DateTime(2026, 11, 5)); // berikutnya 5 Des
      expect(b.occurrencesUntil(_payday, _now), 1);
    });

    test('jatuh tempo tepat di hari gajian ikut dihitung', () {
      final b = _bill(due: DateTime(2026, 11, 25));
      expect(b.occurrencesUntil(_payday, _now), 1);
    });

    test('jatuh tempo setelah gajian tidak dihitung', () {
      final b = _bill(due: DateTime(2026, 11, 26));
      expect(b.occurrencesUntil(_payday, _now), 0);
    });

    test('mingguan: 30 Okt, 6, 13, 20 Nov = 4 kali (27 Nov sudah lewat gajian)', () {
      final b = _bill(due: DateTime(2026, 10, 30), unit: RepeatUnit.minggu);
      expect(b.occurrencesUntil(_payday, _now), 4);
    });

    test('2 mingguan: 1 Nov dan 15 Nov = 2 kali (29 Nov lewat gajian)', () {
      final b = _bill(
        due: DateTime(2026, 11, 1),
        every: 2,
        unit: RepeatUnit.minggu,
      );
      expect(b.occurrencesUntil(_payday, _now), 2);
    });

    test('harian: 28 Okt s.d. 25 Nov = 29 kali', () {
      final b = _bill(due: DateTime(2026, 10, 28), unit: RepeatUnit.hari);
      expect(b.occurrencesUntil(_payday, _now), 29);
    });

    // Satu pelunasan memajukan jatuh tempo ke periode pertama SETELAH hari
    // ini, jadi periode telat 21 & 28 Okt tidak jadi tagihan tambahan.
    test('mingguan yang telat: 1 yang tertunda + periode setelah hari ini', () {
      final b = _bill(due: DateTime(2026, 10, 14), unit: RepeatUnit.minggu);
      // 14 Okt (tertunda) + 4, 11, 18, 25 Nov.
      expect(b.occurrencesUntil(_payday, _now), 5);
    });

    test('bulanan yang telat: yang tertunda + periode berikutnya sebelum gajian', () {
      final b = _bill(due: DateTime(2026, 10, 10)); // berikutnya 10 Nov
      expect(b.occurrencesUntil(_payday, _now), 2);
    });

    test('cicilan tidak dihitung melebihi sisa angsuran', () {
      final b = _bill(
        due: DateTime(2026, 10, 30),
        unit: RepeatUnit.minggu,
        limit: 12,
        remaining: 2,
      );
      expect(b.occurrencesUntil(_payday, _now), 2);
    });

    test('cicilan tanpa remaining memakai repeatLimit', () {
      final b = _bill(
        due: DateTime(2026, 10, 30),
        unit: RepeatUnit.minggu,
        limit: 3,
      );
      expect(b.occurrencesUntil(_payday, _now), 3);
    });

    test('periode 0 (data rusak) tidak membuat putaran tak berujung', () {
      final b = _bill(due: DateTime(2026, 10, 30), every: 0);
      expect(b.occurrencesUntil(_payday, _now), 1);
    });
  });

  group('BurnRateCalculator — tagihan wajib', () {
    test('tagihan mingguan dikalikan jumlah jatuh temponya', () {
      final r = _hitung(5000000, [
        _bill(due: DateTime(2026, 10, 30), unit: RepeatUnit.minggu),
      ]);
      expect(r.totalTagihanWajib, 400000); // 4 x 100.000
      expect(r.freeCashFlow, 4600000);
    });

    test('hanya item wajib yang dihitung', () {
      final r = _hitung(5000000, [
        _bill(id: 'kos', due: DateTime(2026, 11, 5), cost: 1000000),
        _bill(
          id: 'skincare',
          due: DateTime(2026, 11, 5),
          cost: 500000,
          type: BillType.belanja,
        ),
        _bill(
          id: 'langganan',
          due: DateTime(2026, 11, 5),
          cost: 99000,
          mandatory: false,
        ),
      ]);
      expect(r.totalTagihanWajib, 1000000);
    });

    test('item di luar siklus gaji tidak dihitung', () {
      final r = _hitung(5000000, [
        _bill(due: DateTime(2026, 11, 26), cost: 700000),
      ]);
      expect(r.totalTagihanWajib, 0);
    });

    test('sisa hari dan tanggal gajian mengikuti profil', () {
      final r = _hitung(5000000, const []);
      expect(r.nextPayday, _payday);
      expect(r.sisaHari, 28);
    });
  });

  group('BurnRateCalculator — tingkatan status', () {
    // Satu tagihan Rp 1.000.000 (jatuh tempo 5 Nov, sekali sebelum gajian);
    // sisa 28 hari, jadi batas harian = (pemasukan - 1.000.000) / 28.
    BurnRateResult dengan(double income) => _hitung(income, [
      _bill(due: DateTime(2026, 11, 5), cost: 1000000),
    ]);

    test('tepat Rp 30.000/hari = Aman', () {
      final r = dengan(1840000); // 840.000 / 28
      expect(r.batasAmanHarian, 30000);
      expect(r.status, BurnRateStatus.aman);
    });

    test('di atas batas aman = Aman', () {
      expect(dengan(3000000).status, BurnRateStatus.aman);
    });

    test('antara 10.000 dan 30.000 = Terbatas', () {
      final r = dengan(1560000); // 560.000 / 28 = 20.000
      expect(r.batasAmanHarian, 20000);
      expect(r.status, BurnRateStatus.terbatas);
    });

    test('tepat Rp 10.000/hari = Terbatas', () {
      final r = dengan(1280000); // 280.000 / 28
      expect(r.batasAmanHarian, 10000);
      expect(r.status, BurnRateStatus.terbatas);
    });

    test('di bawah 10.000 tapi masih positif = Kritis', () {
      final r = dengan(1140000); // 140.000 / 28 = 5.000
      expect(r.batasAmanHarian, 5000);
      expect(r.status, BurnRateStatus.kritis);
    });

    test('tepat nol = Kritis, bukan Overbudget', () {
      final r = dengan(1000000);
      expect(r.freeCashFlow, 0);
      expect(r.status, BurnRateStatus.kritis);
    });

    test('tagihan melebihi pemasukan = Overbudget', () {
      final r = dengan(999999);
      expect(r.freeCashFlow, lessThan(0));
      expect(r.status, BurnRateStatus.overbudget);
    });

    test('label setiap status unik dan tidak kosong', () {
      final labels = BurnRateStatus.values.map((s) => s.label).toList();
      expect(labels.toSet().length, BurnRateStatus.values.length);
      expect(labels.every((l) => l.trim().isNotEmpty), isTrue);
    });
  });
}
