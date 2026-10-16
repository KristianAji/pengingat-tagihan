// Pemeriksaan sementara: latar + batas subjek tiap aset icon.
// Bening dan putih sama-sama terlihat putih di penampil gambar, jadi harus
// dibaca dari pikselnya, bukan dinilai dari mata. Batas subjek perlu diketahui
// karena lapisan adaptif punya padding bening bawaan (subjek sengaja
// dikecilkan ke kotak tengah 66% oleh tool/buat_icon.dart).
import 'dart:io';

import 'package:image/image.dart' as img;

void main() {
  for (final nama in ['app_icon.png', 'app_icon_foreground.png']) {
    final gambar = img.decodePng(File('assets/icon/$nama').readAsBytesSync())!;
    final sudut = gambar.getPixel(0, 0);

    var kiri = gambar.width, atas = gambar.height, kanan = -1, bawah = -1;
    for (var y = 0; y < gambar.height; y++) {
      for (var x = 0; x < gambar.width; x++) {
        if (gambar.getPixel(x, y).a < 8) continue; // bening = latar
        if (x < kiri) kiri = x;
        if (x > kanan) kanan = x;
        if (y < atas) atas = y;
        if (y > bawah) bawah = y;
      }
    }

    final lebar = kanan - kiri + 1;
    final tinggi = bawah - atas + 1;
    final sisi = lebar > tinggi ? lebar : tinggi;
    stdout.writeln('$nama  ${gambar.width}x${gambar.height}  '
        'sudut: rgba(${sudut.r.toInt()},${sudut.g.toInt()},'
        '${sudut.b.toInt()},${sudut.a.toInt()})');
    stdout.writeln('   subjek: ${lebar}x$tinggi di ($kiri,$atas) '
        '| sisi terpanjang = ${(sisi / gambar.width * 100).toStringAsFixed(1)}% '
        'kanvas | rasio kanvas/subjek = '
        '${(gambar.width / sisi).toStringAsFixed(4)}');
  }
}
