import 'package:flutter_test/flutter_test.dart';

import 'package:pengingat_tagihan/utils/batching.dart';

void main() {
  group('chunked', () {
    test('daftar kosong tidak menghasilkan potongan', () {
      expect(chunked(const <int>[], 500), isEmpty);
    });

    test('lebih pendek dari batas jadi satu potongan utuh', () {
      final hasil = chunked([1, 2, 3], 500).toList();
      expect(hasil, [
        [1, 2, 3],
      ]);
    });

    test('tepat di batas tidak dipecah', () {
      final items = List.generate(500, (i) => i);
      final hasil = chunked(items, 500).toList();
      expect(hasil.length, 1);
      expect(hasil.single.length, 500);
    });

    // Inti perbaikannya: satu operasi lebih dari 500 harus jadi dua potongan,
    // karena Firestore menolak WriteBatch dengan lebih dari 500 operasi.
    test('satu di atas batas dipecah dua', () {
      final items = List.generate(501, (i) => i);
      final hasil = chunked(items, 500).toList();
      expect(hasil.length, 2);
      expect(hasil[0].length, 500);
      expect(hasil[1].length, 1);
    });

    test('jauh di atas batas dipecah rata', () {
      final items = List.generate(1000, (i) => i);
      final hasil = chunked(items, 500).toList();
      expect(hasil.map((c) => c.length), [500, 500]);
    });

    test('tidak ada item yang hilang atau terduplikasi', () {
      final items = List.generate(1234, (i) => i);
      final hasil = chunked(items, 500).toList();
      expect(hasil.expand((c) => c).toList(), items);
    });

    test('setiap potongan tidak melebihi batas', () {
      for (final total in [0, 1, 499, 500, 501, 999, 1000, 1001, 2500]) {
        final items = List.generate(total, (i) => i);
        for (final potongan in chunked(items, 500)) {
          expect(potongan.length, lessThanOrEqualTo(500),
              reason: 'total $total menghasilkan potongan terlalu besar');
        }
      }
    });
  });
}
