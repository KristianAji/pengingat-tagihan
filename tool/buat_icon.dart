// Menyiapkan berkas icon dari gambar sumber menjadi aset siap pakai.
//
// Jalankan setiap kali gambar sumbernya diganti:
//   1. dart run tool/buat_icon.dart
//   2. dart run flutter_launcher_icons
//
// Kenapa gambarnya perlu diolah dulu:
//   - Gambar sumber punya margin putih lebar, jadi kalau dipakai apa adanya
//     icon-nya terlihat kecil. Skrip ini mencari batas subjeknya lebih dulu,
//     memotongnya, lalu memusatkannya kembali.
//   - Android 8+ memasking icon (lingkaran/squircle); hanya bagian tengah yang
//     dijamin terlihat. Karena itu lapisan depan icon adaptif dibuat terpisah:
//     subjeknya dikecilkan ke dalam kotak tengah 66%, bukan memenuhi bidang.
//
// Latar sengaja TIDAK dibuat transparan: latar gambar sumber putih dan kertas
// tagihannya juga putih, jadi kalau putihnya dibuang, kertas tagihannya ikut
// hilang. Latar adaptif karena itu disetel putih juga supaya menyatu
// (lihat flutter_launcher_icons di pubspec.yaml).
import 'dart:io';

import 'package:image/image.dart' as img;

/// Ukuran kanvas keluaran. 1024 px cukup untuk semua kerapatan layar Android.
const int _kanvas = 1024;

/// Bagian kanvas yang ditempati sisi terpanjang subjek.
const double _rasioIconLama = 0.82;
const double _rasioAdaptif = 0.66;

/// Ditambahkan di sekeliling subjek supaya tidak menempel tepi potongan.
const double _margin = 0.06;

/// Piksel dianggap latar bila ketiga kanalnya di atas ambang ini.
const int _ambangPutih = 243;

const String _sumberDefault = r'C:\Semester 5\Mobile\Icon-apliksi-3.jpeg';
const String _tujuanDefault = 'assets/icon';

void main(List<String> args) {
  final sumber = args.isNotEmpty ? args[0] : _sumberDefault;
  final tujuan = args.length > 1 ? args[1] : _tujuanDefault;

  final berkas = File(sumber);
  if (!berkas.existsSync()) {
    stderr.writeln('Gambar sumber tidak ada: $sumber');
    exit(1);
  }

  final asal = img.decodeImage(berkas.readAsBytesSync());
  if (asal == null) {
    stderr.writeln('Gambar tidak bisa dibaca: $sumber');
    exit(1);
  }

  final kotak = _batasSubjek(asal);
  if (kotak == null) {
    stderr.writeln('Gambar tidak berisi subjek (seluruhnya putih).');
    exit(1);
  }

  final margin = (kotak.sisiTerpanjang * _margin).round();
  final x = (kotak.kiri - margin).clamp(0, asal.width - 1);
  final y = (kotak.atas - margin).clamp(0, asal.height - 1);
  final lebar = (kotak.lebar + margin * 2).clamp(1, asal.width - x);
  final tinggi = (kotak.tinggi + margin * 2).clamp(1, asal.height - y);

  final potongan = img.copyCrop(asal, x: x, y: y, width: lebar, height: tinggi);

  Directory(tujuan).createSync(recursive: true);

  // Icon lama (Android < 8, juga dipakai di beberapa tempat lain): latar putih.
  _tulis(
    nama: 'app_icon.png',
    tujuan: tujuan,
    potongan: potongan,
    rasio: _rasioIconLama,
    transparan: false,
  );

  // Lapisan depan icon adaptif: subjek di dalam kotak tengah 66%, latar bening.
  _tulis(
    nama: 'app_icon_foreground.png',
    tujuan: tujuan,
    potongan: potongan,
    rasio: _rasioAdaptif,
    transparan: true,
  );

  stdout.writeln('Subjek terdeteksi: ${kotak.lebar}x${kotak.tinggi} px '
      'di ($x,$y), dipotong jadi ${potongan.width}x${potongan.height} px.');
}

void _tulis({
  required String nama,
  required String tujuan,
  required img.Image potongan,
  required double rasio,
  required bool transparan,
}) {
  final sisiTerpanjang = potongan.width > potongan.height
      ? potongan.width
      : potongan.height;
  final skala = _kanvas * rasio / sisiTerpanjang;

  final gambar = img.copyResize(
    potongan,
    width: (potongan.width * skala).round(),
    height: (potongan.height * skala).round(),
    interpolation: img.Interpolation.cubic,
  );

  final kanvas = img.Image(
    width: _kanvas,
    height: _kanvas,
    numChannels: 4,
  );
  if (!transparan) {
    img.fill(kanvas, color: img.ColorRgba8(255, 255, 255, 255));
  }

  img.compositeImage(
    kanvas,
    gambar,
    dstX: (_kanvas - gambar.width) ~/ 2,
    dstY: (_kanvas - gambar.height) ~/ 2,
  );

  final keluar = File('$tujuan/$nama');
  keluar.writeAsBytesSync(img.encodePng(kanvas));

  // Dibaca ulang dari berkas yang barusan ditulis: memastikan latarnya benar
  // (bening untuk lapisan adaptif, putih untuk icon lama) tidak bisa dinilai
  // dari tampilan gambar, karena bening dan putih sama-sama terlihat putih.
  final kembali = img.decodePng(keluar.readAsBytesSync())!;
  final sudut = kembali.getPixel(0, 0);
  final ketebalanLatar = transparan
      ? 'alpha ${sudut.a.toInt()} (bening)'
      : 'RGB ${sudut.r.toInt()},${sudut.g.toInt()},${sudut.b.toInt()} '
          'alpha ${sudut.a.toInt()}';

  stdout.writeln('  $nama  ${_kanvas}x$_kanvas  '
      '(skala ${skala.toStringAsFixed(3)}, ${keluar.lengthSync() ~/ 1024} KB) '
      '| sudut: $ketebalanLatar');
}

/// Batas piksel yang bukan latar putih.
_Batas? _batasSubjek(img.Image gambar) {
  var kiri = gambar.width, atas = gambar.height, kanan = -1, bawah = -1;

  for (var y = 0; y < gambar.height; y++) {
    for (var x = 0; x < gambar.width; x++) {
      final p = gambar.getPixel(x, y);
      if (p.r > _ambangPutih && p.g > _ambangPutih && p.b > _ambangPutih) {
        continue;
      }
      if (x < kiri) kiri = x;
      if (x > kanan) kanan = x;
      if (y < atas) atas = y;
      if (y > bawah) bawah = y;
    }
  }

  if (kanan < 0) return null;
  return _Batas(kiri, atas, kanan - kiri + 1, bawah - atas + 1);
}

class _Batas {
  const _Batas(this.kiri, this.atas, this.lebar, this.tinggi);
  final int kiri;
  final int atas;
  final int lebar;
  final int tinggi;

  int get sisiTerpanjang => lebar > tinggi ? lebar : tinggi;
}
