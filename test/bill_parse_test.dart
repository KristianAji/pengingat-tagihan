import 'package:flutter_test/flutter_test.dart';

import 'package:pengingat_tagihan/models/bill.dart';

Map<String, dynamic> _validMap() => {
  'id': 'b1',
  'name': 'Listrik',
  'type': BillType.tagihan.index,
  'repeatEvery': 1,
  'repeatUnit': RepeatUnit.bulan.index,
  'dueDate': DateTime(2026, 11, 5).toIso8601String(),
  'anchorDay': 5,
  'reminderOffsets': [7, 3, 1],
  'estimatedCost': 350000,
  'paymentMethod': 'Dana',
  'repeatLimit': null,
  'remaining': null,
  'createdAt': DateTime(2026, 1, 1).toIso8601String(),
  'isMandatory': true,
};

void main() {
  group('Bill.tryFromMap', () {
    test('dokumen sehat dibaca seperti fromMap', () {
      final bill = Bill.tryFromMap(_validMap());

      expect(bill, isNotNull);
      expect(bill!.id, 'b1');
      expect(bill.name, 'Listrik');
      expect(bill.estimatedCost, 350000);
      expect(bill.reminderOffsets, [7, 3, 1]);
    });

    test('dokumen lama tanpa anchorDay & isMandatory tetap terbaca', () {
      final map = _validMap()
        ..remove('anchorDay')
        ..remove('isMandatory');

      final bill = Bill.tryFromMap(map);

      expect(bill, isNotNull);
      expect(bill!.anchorDay, isNull);
      expect(bill.isMandatory, isTrue); // bawaan jenis Tagihan
    });

    test('field wajib hilang -> null, tidak melempar', () {
      final map = _validMap()..remove('name');

      expect(Bill.tryFromMap(map), isNull);
    });

    test('tipe field salah -> null', () {
      final map = _validMap()..['estimatedCost'] = 'seratus ribu';

      expect(Bill.tryFromMap(map), isNull);
    });

    test('tanggal tidak terbaca -> null', () {
      final map = _validMap()..['dueDate'] = 'bukan-tanggal';

      expect(Bill.tryFromMap(map), isNull);
    });

    test('indeks enum di luar jangkauan -> null', () {
      final map = _validMap()..['type'] = 99;

      expect(Bill.tryFromMap(map), isNull);
    });

    test('map kosong -> null', () {
      expect(Bill.tryFromMap(<String, dynamic>{}), isNull);
    });

    test('satu dokumen rusak tidak membuang dokumen sehat di sekitarnya', () {
      // Meniru persis rantai di FirestoreService.billsStream.
      final docs = <Map<String, dynamic>>[
        _validMap()..['id'] = 'a',
        _validMap()..remove('dueDate'),
        _validMap()..['id'] = 'c',
      ];

      final bills = docs
          .map(Bill.tryFromMap)
          .whereType<Bill>()
          .toList();

      expect(bills.map((b) => b.id), ['a', 'c']);
    });
  });
}
