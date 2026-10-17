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
//     subjeknya dikecilkan ke dalam kotak tengah 72%, bukan memenuhi bidang.
//
// Latar dijadikan bening dengan flood fill dari tepi potongan: hanya putih
// yang tersambung ke luar yang dibuang. Kertas tagihan yang juga putih tetap
// utuh karena dikelilingi garis gelap, jadi tidak ikut hilang.
import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Ukuran kanvas keluaran. 1024 px cukup untuk semua kerapatan layar Android.
const int _kanvas = 1024;

/// Bagian kanvas yang ditempati sisi terpanjang subjek.
/// Diperbesar 2026-10-17: 0,82 → 0,88 (icon lama) dan 0,66 → 0,72 (adaptif).
const double _rasioIconLama = 0.88;
const double _rasioAdaptif = 0.72;

/// Ditambahkan di sekeliling subjek supaya tidak menempel tepi potongan.
const double _margin = 0.06;

/// Piksel dianggap latar bila ketiga kanalnya di atas ambang ini.
const int _ambangPutih = 243;

/// Ambang untuk membuang latar. Latar JPEG di gambar sumber berwarna
/// sekitar 252, sedangkan badan kucing paling terang berwarna 254/244/233 —
/// kanal birunya jauh di bawah ambang, jadi tidak ikut terbuang.
const int _ambangLatar = 243;

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

  // JPEG tidak punya kanal alpha; konversi dulu supaya flood fill bisa
  // benar-benar menulis alpha 0 (tanpa ini latar jadi hitam pekat).
  final potongan = img
      .copyCrop(asal, x: x, y: y, width: lebar, height: tinggi)
      .convert(numChannels: 4);
  final dibuang = _buangLatar(potongan);
  stdout.writeln('Latar dibuang: $dibuang piksel putih yang tersambung ke tepi.');

  Directory(tujuan).createSync(recursive: true);

  // Icon lama (Android < 8, juga dipakai di beberapa tempat lain): latar bening.
  _tulis(
    nama: 'app_icon.png',
    tujuan: tujuan,
    potongan: potongan,
    rasio: _rasioIconLama,
  );

  // Lapisan depan icon adaptif: subjek di dalam kotak tengah 72%, latar bening.
  _tulis(
    nama: 'app_icon_foreground.png',
    tujuan: tujuan,
    potongan: potongan,
    rasio: _rasioAdaptif,
  );

  stdout.writeln('Subjek terdeteksi: ${kotak.lebar}x${kotak.tinggi} px '
      'di ($x,$y), dipotong jadi ${potongan.width}x${potongan.height} px.');
}

void _tulis({
  required String nama,
  required String tujuan,
  required img.Image potongan,
  required double rasio,
}) {
  // Skala dihitung dari SUBJEK yang tersisa setelah latar dibuang, bukan dari
  // kotak potongan (yang masih membawa margin 6%). Dengan begitu angka 72% /
  // 88% benar-benar berarti ukuran maskot yang terlihat.
  final sisiTerpanjang = _sisiSubjek(potongan);
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
  final ketebalanLatar = 'alpha ${sudut.a.toInt()} (bening)';

  stdout.writeln('  $nama  ${_kanvas}x$_kanvas  '
      '(skala ${skala.toStringAsFixed(3)}, ${keluar.lengthSync() ~/ 1024} KB) '
      '| sudut: $ketebalanLatar');
}

/// Sisi terpanjang piksel subjek (yang tidak bening) pada [gambar].
int _sisiSubjek(img.Image gambar) {
  var kiri = gambar.width, atas = gambar.height, kanan = -1, bawah = -1;
  for (var y = 0; y < gambar.height; y++) {
    for (var x = 0; x < gambar.width; x++) {
      if (gambar.getPixel(x, y).a < 8) continue;
      if (x < kiri) kiri = x;
      if (x > kanan) kanan = x;
      if (y < atas) atas = y;
      if (y > bawah) bawah = y;
    }
  }
  if (kanan < 0) return gambar.width;
  final lebar = kanan - kiri + 1;
  final tinggi = bawah - atas + 1;
  return lebar > tinggi ? lebar : tinggi;
}

/// Buang latar putih yang tersambung ke tepi [gambar] (flood fill).
///
/// Hanya putih yang bisa dicapai dari tepi yang dijadikan bening. Bagian
/// putih yang terkunci garis gelap — misalnya kertas tagihan — tidak
/// tersentuh, jadi tidak perlu memotong manual.
/// Mengembalikan jumlah piksel yang dibuang.
int _buangLatar(img.Image gambar) {
  final lebar = gambar.width;
  final tinggi = gambar.height;
  final dikunjungi = Uint8List(lebar * tinggi);
  final antrean = <int>[];

  bool putih(int x, int y) {
    final p = gambar.getPixel(x, y);
    return p.a > 0 &&
        p.r >= _ambangLatar &&
        p.g >= _ambangLatar &&
        p.b >= _ambangLatar;
  }

  void periksa(int x, int y) {
    if (x < 0 || y < 0 || x >= lebar || y >= tinggi) return;
    final i = y * lebar + x;
    if (dikunjungi[i] != 0) return;
    dikunjungi[i] = 1;
    if (putih(x, y)) antrean.add(i);
  }

  // Latar selalu menyentuh tepi karena potongan diberi margin di sekeliling
  // subjek, jadi semua piksel tepi aman dijadikan titik awal.
  for (var x = 0; x < lebar; x++) {
    periksa(x, 0);
    periksa(x, tinggi - 1);
  }
  for (var y = 0; y < tinggi; y++) {
    periksa(0, y);
    periksa(lebar - 1, y);
  }

  var kepala = 0;
  while (kepala < antrean.length) {
    final i = antrean[kepala++];
    final x = i % lebar;
    final y = i ~/ lebar;
    gambar.setPixelRgba(x, y, 0, 0, 0, 0);
    periksa(x - 1, y);
    periksa(x + 1, y);
    periksa(x, y - 1);
    periksa(x, y + 1);
  }
  return antrean.length;
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
