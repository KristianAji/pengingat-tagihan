import 'package:flutter/services.dart';

/// Bantuan untuk kolom input nominal Rupiah.
///
/// Angka mentah seperti `1500000` sulit dibaca sekilas (mudah tertukar dengan
/// `15000000`), jadi kolomnya menampilkan pemisah ribuan titik ala Indonesia:
/// `1.500.000`. Nilai yang disimpan tetap angka polos — pakai [parseRupiah]
/// untuk membacanya kembali.

/// Kelompokkan digit dengan titik tiap tiga angka: `1500000` -> `1.500.000`.
String formatAngka(num value) {
  final bulat = value.round();
  final digits = bulat.abs().toString();
  return '${bulat < 0 ? '-' : ''}${_group(digits)}';
}

String _group(String digits) {
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// Baca nominal dari teks yang mungkin bertitik: `"1.500.000"` -> `1500000`.
/// Mengembalikan null bila tidak ada angka sama sekali.
double? parseRupiah(String? text) {
  final digits = (text ?? '').replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return null;
  return double.tryParse(digits);
}

/// Menambahkan pemisah ribuan sambil pengguna mengetik.
///
/// Posisi kursor dijaga relatif terhadap jumlah digit di sebelah kirinya,
/// supaya menyunting di tengah angka tidak melompat ke ujung.
class RupiahInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final raw = newValue.text;
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    // Kolom dikosongkan: biarkan kosong supaya validator yang berbicara.
    if (digits.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    final grouped = _group(digits);

    final caretInRaw = newValue.selection.baseOffset.clamp(0, raw.length);
    final digitsBeforeCaret = raw
        .substring(0, caretInRaw)
        .replaceAll(RegExp(r'[^0-9]'), '')
        .length;

    var caret = grouped.length;
    var seen = 0;
    for (var i = 0; i < grouped.length; i++) {
      if (seen == digitsBeforeCaret) {
        caret = i;
        break;
      }
      if (grouped[i] != '.') seen++;
    }

    return TextEditingValue(
      text: grouped,
      selection: TextSelection.collapsed(offset: caret),
    );
  }
}
