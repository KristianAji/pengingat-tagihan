import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pengingat_tagihan/utils/rupiah_input.dart';

void main() {
  group('formatAngka', () {
    test('memberi titik pemisah ribuan', () {
      expect(formatAngka(1500000), '1.500.000');
      expect(formatAngka(999), '999');
      expect(formatAngka(1000), '1.000');
      expect(formatAngka(0), '0');
    });
  });

  group('parseRupiah', () {
    test('membaca teks bertitik', () {
      expect(parseRupiah('1.500.000'), 1500000);
      expect(parseRupiah('500'), 500);
    });

    test('null bila tidak ada angka', () {
      expect(parseRupiah(''), isNull);
      expect(parseRupiah(null), isNull);
    });

    test('bolak-balik dengan formatAngka', () {
      expect(parseRupiah(formatAngka(2450000)), 2450000);
    });
  });

  group('RupiahInputFormatter', () {
    final formatter = RupiahInputFormatter();

    TextEditingValue ketik(String text, {int? kursor}) =>
        formatter.formatEditUpdate(
          TextEditingValue.empty,
          TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(offset: kursor ?? text.length),
          ),
        );

    test('mengetik angka mentah jadi bertitik, kursor di ujung', () {
      final hasil = ketik('1500000');
      expect(hasil.text, '1.500.000');
      expect(hasil.selection.baseOffset, hasil.text.length);
    });

    test('menyunting di tengah tidak melompatkan kursor', () {
      // "15|00000" -> "1.5|00.000"
      final hasil = ketik('1500000', kursor: 2);
      expect(hasil.text, '1.500.000');
      expect(hasil.selection.baseOffset, 3);
    });

    test('huruf & simbol dibuang', () {
      expect(ketik('12a3').text, '123');
    });

    test('kolom dikosongkan', () {
      final hasil = ketik('');
      expect(hasil.text, '');
      expect(hasil.selection.baseOffset, 0);
    });
  });
}
