import 'package:flutter_test/flutter_test.dart';

import 'package:pengingat_tagihan/models/bill.dart';
import 'package:pengingat_tagihan/utils/bill_sort.dart';

Bill _bill({
  required String id,
  String? name,
  BillType type = BillType.tagihan,
  int repeatEvery = 1,
  RepeatUnit repeatUnit = RepeatUnit.bulan,
  DateTime? dueDate,
  List<int> reminderOffsets = const [7, 3, 1],
  String paymentMethod = 'Dana',
}) {
  return Bill(
    id: id,
    name: name ?? id,
    type: type,
    repeatEvery: repeatEvery,
    repeatUnit: repeatUnit,
    dueDate: dueDate ?? DateTime(2026, 1, 10),
    reminderOffsets: reminderOffsets,
    estimatedCost: 100000,
    paymentMethod: paymentMethod,
    createdAt: DateTime(2026, 1, 1),
  );
}

List<String> _ids(List<Bill> bills) => bills.map((b) => b.id).toList();

void main() {
  group('sortBills — jatuhTempo', () {
    final bills = [
      _bill(id: 'c', dueDate: DateTime(2026, 3, 1)),
      _bill(id: 'a', dueDate: DateTime(2026, 1, 1)),
      _bill(id: 'b', dueDate: DateTime(2026, 2, 1)),
    ];

    test('naik: jatuh tempo terdekat dulu', () {
      expect(_ids(sortBills(bills, BillSortMode.jatuhTempo)), ['a', 'b', 'c']);
    });

    test('turun: jatuh tempo terjauh dulu', () {
      final hasil = sortBills(bills, BillSortMode.jatuhTempo, ascending: false);
      expect(_ids(hasil), ['c', 'b', 'a']);
    });
  });

  group('sortBills — jenis', () {
    final bills = [
      _bill(id: 'belanja', type: BillType.belanja),
      _bill(id: 'tagihan', type: BillType.tagihan),
    ];

    test('naik: Tagihan sebelum Belanja', () {
      expect(_ids(sortBills(bills, BillSortMode.jenis)), [
        'tagihan',
        'belanja',
      ]);
    });

    test('turun: Belanja sebelum Tagihan', () {
      expect(_ids(sortBills(bills, BillSortMode.jenis, ascending: false)), [
        'belanja',
        'tagihan',
      ]);
    });
  });

  group('sortBills — metode', () {
    test('naik: A→Z', () {
      final bills = [
        _bill(id: 'ovo', paymentMethod: 'OVO'),
        _bill(id: 'dana', paymentMethod: 'Dana'),
        _bill(id: 'bca', paymentMethod: 'Transfer BCA'),
      ];
      expect(_ids(sortBills(bills, BillSortMode.metode)), [
        'dana',
        'ovo',
        'bca',
      ]);
    });

    test('turun: Z→A', () {
      final bills = [
        _bill(id: 'ovo', paymentMethod: 'OVO'),
        _bill(id: 'dana', paymentMethod: 'Dana'),
      ];
      expect(_ids(sortBills(bills, BillSortMode.metode, ascending: false)), [
        'ovo',
        'dana',
      ]);
    });

    // Metode diisi bebas oleh pengguna, jadi beda huruf besar/kecil tidak
    // boleh dianggap berbeda — yang menentukan adalah tiebreaker nama.
    test('beda huruf besar/kecil dianggap sama, nama yang menentukan', () {
      final bills = [
        _bill(id: 'kedua', name: 'Beta', paymentMethod: 'dana'),
        _bill(id: 'pertama', name: 'Alpha', paymentMethod: 'Dana'),
      ];
      expect(_ids(sortBills(bills, BillSortMode.metode)), ['pertama', 'kedua']);
    });
  });

  group('sortBills — frekuensi', () {
    // Inti fitur ini: repeatEvery mentah tidak bisa dibandingkan langsung
    // (2 minggu vs 1 bulan), jadi harus dinormalkan ke hari dulu.
    test('naik: perulangan terpendek dulu, dinormalkan ke hari', () {
      final bills = [
        _bill(id: 'tahun', repeatEvery: 12, repeatUnit: RepeatUnit.bulan),
        _bill(id: 'tigaBulan', repeatEvery: 3, repeatUnit: RepeatUnit.bulan),
        _bill(id: 'sebulan', repeatEvery: 1, repeatUnit: RepeatUnit.bulan),
        _bill(id: 'duaMinggu', repeatEvery: 2, repeatUnit: RepeatUnit.minggu),
        _bill(id: 'seminggu', repeatEvery: 1, repeatUnit: RepeatUnit.minggu),
      ];
      expect(_ids(sortBills(bills, BillSortMode.frekuensi)), [
        'seminggu', // 7 hari
        'duaMinggu', // 14 hari
        'sebulan', // 30 hari
        'tigaBulan', // 90 hari
        'tahun', // 360 hari
      ]);
    });

    test('turun: perulangan terpanjang dulu', () {
      final bills = [
        _bill(id: 'seminggu', repeatEvery: 1, repeatUnit: RepeatUnit.minggu),
        _bill(id: 'sebulan', repeatEvery: 1, repeatUnit: RepeatUnit.bulan),
      ];
      expect(_ids(sortBills(bills, BillSortMode.frekuensi, ascending: false)), [
        'sebulan',
        'seminggu',
      ]);
    });

    test('perulangan sama: pengingat paling awal (H-7) dulu', () {
      final bills = [
        _bill(id: 'h1', reminderOffsets: const [1]),
        _bill(id: 'h7', reminderOffsets: const [7, 3, 1]),
        _bill(id: 'h3', reminderOffsets: const [3, 1]),
      ];
      expect(_ids(sortBills(bills, BillSortMode.frekuensi)), [
        'h7',
        'h3',
        'h1',
      ]);
    });

    test('tanpa pengingat ditaruh paling akhir saat naik', () {
      final bills = [
        _bill(id: 'tanpa', reminderOffsets: const []),
        _bill(id: 'dengan', reminderOffsets: const [7]),
      ];
      expect(_ids(sortBills(bills, BillSortMode.frekuensi)), [
        'dengan',
        'tanpa',
      ]);
    });
  });

  group('sortBills — ketahanan', () {
    test('daftar kosong tidak error', () {
      expect(sortBills(const <Bill>[], BillSortMode.metode), isEmpty);
    });

    test('satu elemen tidak error', () {
      final bills = [_bill(id: 'a')];
      expect(_ids(sortBills(bills, BillSortMode.metode)), ['a']);
    });

    test('tidak mengubah urutan daftar asal', () {
      final asal = [
        _bill(id: 'c', dueDate: DateTime(2026, 3, 1)),
        _bill(id: 'a', dueDate: DateTime(2026, 1, 1)),
        _bill(id: 'b', dueDate: DateTime(2026, 2, 1)),
      ];
      sortBills(asal, BillSortMode.jatuhTempo);
      expect(_ids(asal), ['c', 'a', 'b']);
    });

    // Dua tagihan yang sama persis kecuali id harus punya urutan tetap,
    // supaya daftar tidak berkedip saat snapshot Firestore datang lagi.
    test('urutan deterministik untuk data yang serupa', () {
      final bills = [
        _bill(id: 'b', name: 'Sama', paymentMethod: 'Dana'),
        _bill(id: 'a', name: 'Sama', paymentMethod: 'Dana'),
      ];
      final pertama = _ids(sortBills(bills, BillSortMode.metode));
      final kedua = _ids(sortBills(bills.reversed, BillSortMode.metode));
      expect(pertama, ['a', 'b']);
      expect(kedua, pertama);
    });
  });

  group('nextSortState', () {
    test('ketuk mode yang sedang aktif membalik arah', () {
      final hasil = nextSortState(
        BillSortMode.metode,
        true,
        BillSortMode.metode,
      );
      expect(hasil.mode, BillSortMode.metode);
      expect(hasil.ascending, isFalse);
    });

    test('ketuk mode lain pindah mode + kembali ke arah default', () {
      final hasil = nextSortState(
        BillSortMode.metode,
        false, // sedang turun
        BillSortMode.frekuensi,
      );
      expect(hasil.mode, BillSortMode.frekuensi);
      expect(hasil.ascending, BillSortMode.frekuensi.defaultAscending);
    });

    test('arah default semua mode adalah naik', () {
      for (final mode in BillSortMode.values) {
        expect(mode.defaultAscending, isTrue);
      }
    });

    test('label tiap mode tidak kosong dan unik', () {
      final labels = BillSortMode.values.map((m) => m.label).toList();
      expect(labels.toSet().length, BillSortMode.values.length);
      expect(labels.every((l) => l.trim().isNotEmpty), isTrue);
    });
  });
}
