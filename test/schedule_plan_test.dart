import 'package:flutter_test/flutter_test.dart';

import 'package:pengingat_tagihan/models/bill.dart';
import 'package:pengingat_tagihan/services/schedule_plan.dart';

// Sekarang: 25 Okt 2026 pukul 09:00. Notifikasi dikirim pukul 08:00 hari
// pengingat, jadi pengingat 25 Okt sudah lewat 1 jam.
final _now = DateTime(2026, 10, 25, 9, 0);

Bill _bill(
  String id,
  DateTime dueDate, {
  List<int> offsets = const [7, 3, 1],
  int every = 1,
  RepeatUnit unit = RepeatUnit.bulan,
}) {
  return Bill(
    id: id,
    name: 'Tagihan $id',
    type: BillType.tagihan,
    repeatEvery: every,
    repeatUnit: unit,
    dueDate: dueDate,
    reminderOffsets: offsets,
    estimatedCost: 100000,
    paymentMethod: 'Dana',
    createdAt: DateTime(2026, 1, 1),
  );
}

int _id(String billId, int offset, DateTime due) =>
    SchedulePlan.notifId(billId, offset, due);

int _overdueId(String billId, DateTime due) =>
    SchedulePlan.notifId(billId, SchedulePlan.overdueOffset, due);

void main() {
  group('pembagian pengingat', () {
    test('yang waktunya sudah lewat = fired, sisanya = upcoming', () {
      // Jatuh tempo 27 Okt: H-7 (20 Okt) dan H-3 (24 Okt) sudah lewat,
      // H-1 (26 Okt) belum.
      final due = DateTime(2026, 10, 27);
      final plan = SchedulePlan.build([_bill('a', due)], _now);

      expect(plan.fired, {_id('a', 7, due), _id('a', 3, due)});
      // Selain H-1, tiap tagihan selalu punya pengingat harian "telat".
      expect(
        plan.upcoming.keys,
        unorderedEquals([_id('a', 1, due), _overdueId('a', due)]),
      );
      expect(plan.upcoming[_id('a', 1, due)]!.offset, 1);
      expect(
        plan.upcoming[_id('a', 1, due)]!.fireDate,
        DateTime(2026, 10, 26, 8, 0),
      );
    });

    test('fireDateFor: pukul 08:00, H-n sebelum jatuh tempo', () {
      expect(
        SchedulePlan.fireDateFor(DateTime(2026, 1, 31), 3),
        DateTime(2026, 1, 28, 8, 0),
      );
      expect(
        SchedulePlan.fireDateFor(DateTime(2026, 3, 2), 7),
        DateTime(2026, 2, 23, 8, 0),
      );
    });

    test('tanpa tagihan: rencana kosong', () {
      final plan = SchedulePlan.build(const [], _now);
      expect(plan.upcoming, isEmpty);
      expect(plan.fired, isEmpty);
    });
  });

  group('id notifikasi', () {
    final due = DateTime(2026, 11, 5);

    test('sama untuk masukan yang sama', () {
      expect(_id('a', 3, due), _id('a', 3, due));
    });

    test('berbeda per tagihan, per H-, dan per periode jatuh tempo', () {
      final ids = {
        _id('a', 3, due),
        _id('b', 3, due),
        _id('a', 1, due),
        _id('a', 3, DateTime(2026, 12, 5)),
      };
      expect(ids, hasLength(4));
    });

    test('jam di tanggal jatuh tempo tidak mengubah id', () {
      expect(
        _id('a', 3, DateTime(2026, 11, 5)),
        _id('a', 3, DateTime(2026, 11, 5, 14, 30)),
      );
    });

    test('selalu non-negatif (syarat id notifikasi Android)', () {
      for (var i = 0; i < 200; i++) {
        expect(_id('bill-$i', i % 8, DateTime(2026, 1, 1 + i % 28)), isNonNegative);
      }
    });
  });

  group('pembersihan jadwal tertunda', () {
    test('hanya yang tidak ada di rencana yang dibatalkan', () {
      final due = DateTime(2026, 10, 27);
      final plan = SchedulePlan.build([_bill('a', due)], _now);
      final upcomingId = _id('a', 1, due);
      const staleId = 12345;

      expect(plan.pendingToCancel([upcomingId, staleId]), {staleId});
    });

    test('H- yang dihilangkan pengguna ikut dibatalkan', () {
      final due = DateTime(2026, 11, 20);
      final before = SchedulePlan.build([_bill('a', due)], _now);
      final after = SchedulePlan.build([
        _bill('a', due, offsets: const [7]),
      ], _now);

      final pending = before.upcoming.keys;
      expect(after.pendingToCancel(pending), {
        _id('a', 3, due),
        _id('a', 1, due),
      });
    });
  });

  group('pembersihan notifikasi yang sedang tampil', () {
    test('melunasi tagihan A tidak menghapus notifikasi tagihan B', () {
      // Keduanya jatuh tempo 26 Okt; H-1 (25 Okt 08:00) sudah tampil.
      final dueA = DateTime(2026, 10, 26);
      final dueB = DateTime(2026, 10, 26);
      final tampil = [_id('a', 1, dueA), _id('b', 1, dueB)];

      // A dilunasi -> jatuh temponya maju sebulan. B tetap belum dibayar.
      final setelahLunas = SchedulePlan.build([
        _bill('a', DateTime(2026, 11, 26)),
        _bill('b', dueB),
      ], _now);

      expect(setelahLunas.activeToCancel(tampil), {_id('a', 1, dueA)});
    });

    test('notifikasi tagihan yang telat dan belum dibayar tetap dipertahankan', () {
      final due = DateTime(2026, 10, 20);
      final plan = SchedulePlan.build([_bill('a', due)], _now);
      final tampil = [_id('a', 1, due), _id('a', 3, due)];

      expect(plan.activeToCancel(tampil), isEmpty);
    });

    test('tagihan yang dihapus: notifikasinya dibersihkan', () {
      final due = DateTime(2026, 10, 26);
      final plan = SchedulePlan.build(const [], _now);

      expect(plan.activeToCancel([_id('a', 1, due)]), {_id('a', 1, due)});
    });

    test('tagihan mingguan: notifikasi periode lama basi walau H-7 periode '
        'baru sudah lewat', () {
      // Periode lama jatuh tempo 22 Okt (H-7 tampil). Dilunasi -> 30 Okt.
      // H-7 periode baru (23 Okt) juga sudah lewat, tapi id-nya beda.
      final lama = DateTime(2026, 10, 22);
      final baru = DateTime(2026, 10, 30);
      final plan = SchedulePlan.build([
        _bill('a', baru, every: 1, unit: RepeatUnit.minggu),
      ], _now);

      expect(plan.fired, contains(_id('a', 7, baru)));
      expect(plan.activeToCancel([_id('a', 7, lama)]), {_id('a', 7, lama)});
    });

    test('id luar rencana (bukan milik pengingat) tidak dipertahankan', () {
      final plan = SchedulePlan.build(const [], _now);
      expect(plan.activeToCancel([999]), {999});
    });
  });

  group('pengingat Hari-H', () {
    test('offset 0 dijadwalkan pukul 08:00 pada hari jatuh tempo', () {
      final due = DateTime(2026, 10, 27);
      final plan = SchedulePlan.build([
        _bill('a', due, offsets: const [0]),
      ], _now);

      final r = plan.upcoming[_id('a', 0, due)]!;
      expect(r.offset, 0);
      expect(r.isOverdue, isFalse);
      expect(r.fireDate, DateTime(2026, 10, 27, 8, 0));
    });

    test('Hari-H yang jamnya sudah lewat dianggap fired, bukan upcoming', () {
      final due = DateTime(2026, 10, 25); // hari ini; 08:00 sudah lewat
      final plan = SchedulePlan.build([
        _bill('a', due, offsets: const [0]),
      ], _now);

      expect(plan.fired, contains(_id('a', 0, due)));
      expect(plan.upcoming.containsKey(_id('a', 0, due)), isFalse);
    });
  });

  group('pengingat harian untuk tagihan telat', () {
    test('sebelum telat sudah terjadwal, mulai pukul 08:00 sehari sesudahnya', () {
      final due = DateTime(2026, 10, 27);
      final plan = SchedulePlan.build([
        _bill('a', due, offsets: const [1]),
      ], _now);

      final r = plan.upcoming[_overdueId('a', due)]!;
      expect(r.isOverdue, isTrue);
      expect(r.fireDate, DateTime(2026, 10, 28, 8, 0));
      expect(plan.fired, isNot(contains(_overdueId('a', due))));
    });

    test('jatuh tempo hari ini: pengingat telat mulai besok', () {
      final due = DateTime(2026, 10, 25);
      final plan = SchedulePlan.build([_bill('a', due)], _now);

      expect(
        plan.upcoming[_overdueId('a', due)]!.fireDate,
        DateTime(2026, 10, 26, 8, 0),
      );
      expect(plan.fired, isNot(contains(_overdueId('a', due))));
    });

    test('sudah telat & lewat 08:00: berikutnya besok 08:00, dan tampil = fired', () {
      final due = DateTime(2026, 10, 20);
      final plan = SchedulePlan.build([_bill('a', due)], _now); // 25 Okt 09:00

      expect(
        plan.upcoming[_overdueId('a', due)]!.fireDate,
        DateTime(2026, 10, 26, 8, 0),
      );
      expect(plan.fired, contains(_overdueId('a', due)));
    });

    test('sudah telat & belum 08:00: berikutnya hari ini pukul 08:00', () {
      final due = DateTime(2026, 10, 20);
      final pagi = DateTime(2026, 10, 25, 7, 0);
      final plan = SchedulePlan.build([_bill('a', due)], pagi);

      expect(
        plan.upcoming[_overdueId('a', due)]!.fireDate,
        DateTime(2026, 10, 25, 8, 0),
      );
    });

    test('overdueFireDate tidak pernah mengembalikan waktu yang sudah lewat', () {
      final due = DateTime(2026, 1, 10);
      for (final jam in [0, 7, 8, 9, 23]) {
        final now = DateTime(2026, 10, 25, jam, 30);
        expect(SchedulePlan.overdueFireDate(due, now).isAfter(now), isTrue);
      }
    });

    test('melunasi menggeser jatuh tempo: jadwal & notifikasi telat lama basi', () {
      final lama = DateTime(2026, 10, 20);
      final sebelum = SchedulePlan.build([_bill('a', lama)], _now);
      final sesudah = SchedulePlan.build([
        _bill('a', DateTime(2026, 11, 20)),
      ], _now);

      expect(
        sesudah.pendingToCancel(sebelum.upcoming.keys),
        contains(_overdueId('a', lama)),
      );
      expect(
        sesudah.activeToCancel([_overdueId('a', lama)]),
        {_overdueId('a', lama)},
      );
    });

    test('notifikasi telat yang sedang tampil dipertahankan selama belum lunas', () {
      final due = DateTime(2026, 10, 20);
      final plan = SchedulePlan.build([_bill('a', due)], _now);

      expect(plan.activeToCancel([_overdueId('a', due)]), isEmpty);
    });

    test('id telat tidak bentrok dengan id H- mana pun', () {
      final due = DateTime(2026, 10, 27);
      final ids = {
        _id('a', 7, due),
        _id('a', 3, due),
        _id('a', 1, due),
        _id('a', 0, due),
        _overdueId('a', due),
      };
      expect(ids, hasLength(5));
    });
  });
}
