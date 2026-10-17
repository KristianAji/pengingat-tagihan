import 'package:flutter_test/flutter_test.dart';
import 'package:pengingat_tagihan/utils/profile_display.dart';

void main() {
  group('displayNameFor', () {
    test('memakai nama panggilan lebih dulu', () {
      expect(displayNameFor('Kris', 'kris@contoh.com'), 'Kris');
    });

    test('jatuh ke bagian depan email bila nama panggilan kosong', () {
      expect(displayNameFor('  ', 'kris@contoh.com'), 'kris');
    });

    test('jatuh ke email bila profil lama belum punya nama panggilan', () {
      expect(displayNameFor('', 'budi.santoso@contoh.com'), 'budi.santoso');
    });

    test('memakai "Pengguna" bila email juga tidak ada', () {
      expect(displayNameFor('', null), 'Pengguna');
      expect(displayNameFor('', ''), 'Pengguna');
    });
  });

  group('initialsFor', () {
    test('dua kata mengambil huruf pertama dan terakhir', () {
      expect(initialsFor('Kris Suseno'), 'KS');
      expect(initialsFor('budi santoso'), 'BS');
    });

    test('satu kata mengambil satu huruf', () {
      expect(initialsFor('Kris'), 'K');
    });

    test('spasi berlebih tidak dihitung sebagai kata', () {
      expect(initialsFor('  Kris   Suseno  '), 'KS');
    });

    test('nama kosong memakai tanda tanya', () {
      expect(initialsFor(''), '?');
      expect(initialsFor('   '), '?');
    });
  });
}
