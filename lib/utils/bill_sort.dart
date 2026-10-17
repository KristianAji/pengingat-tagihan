import 'dart:math' as math;

import '../models/bill.dart';

/// Sudut pandang pengurutan daftar di halaman "Daftar Tagihan & Belanja".
enum BillSortMode { jatuhTempo, jenis, metode, frekuensi }

extension BillSortModeInfo on BillSortMode {
  /// Label yang tampil di chip.
  String get label {
    switch (this) {
      case BillSortMode.jatuhTempo:
        return 'Jatuh Tempo';
      case BillSortMode.jenis:
        return 'Jenis Daftar';
      case BillSortMode.metode:
        return 'Metode Pembayaran';
      case BillSortMode.frekuensi:
        return 'Frekuensi Pengingat';
    }
  }

  /// Arah yang dipakai saat mode ini baru dipilih.
  ///
  /// Keempatnya "naik", karena arah naik sudah berarti hal yang benar di
  /// setiap mode: jatuh tempo terdekat dulu, Tagihan sebelum Belanja,
  /// metode A→Z, dan perulangan terpendek (paling sering) dulu.
  bool get defaultAscending => true;
}

/// Urutkan [bills] sesuai [mode].
///
/// Selalu menyalin dulu supaya daftar asal (mis. `_bills` milik
/// [BillProvider]) tidak ikut berubah urutannya.
List<Bill> sortBills(
  Iterable<Bill> bills,
  BillSortMode mode, {
  bool ascending = true,
}) {
  final list = bills.toList();
  list.sort((a, b) => ascending ? _compare(a, b, mode) : -_compare(a, b, mode));
  return list;
}

/// State sortir berikutnya saat chip [tapped] diketuk.
///
/// Ketuk mode yang sedang aktif = balik arah; ketuk mode lain = pindah mode
/// dan kembali ke arah default mode itu.
({BillSortMode mode, bool ascending}) nextSortState(
  BillSortMode current,
  bool currentAscending,
  BillSortMode tapped,
) {
  if (tapped == current) {
    return (mode: current, ascending: !currentAscending);
  }
  return (mode: tapped, ascending: tapped.defaultAscending);
}

// ── Internal ──

int _compare(Bill a, Bill b, BillSortMode mode) {
  final primary = switch (mode) {
    BillSortMode.jatuhTempo => a.dueDate.compareTo(b.dueDate),
    BillSortMode.jenis => a.type.index.compareTo(b.type.index),
    BillSortMode.metode => _norm(
      a.paymentMethod,
    ).compareTo(_norm(b.paymentMethod)),
    BillSortMode.frekuensi => _compareFrekuensi(a, b),
  };
  if (primary != 0) return primary;

  // Tiebreaker terakhir: nama lalu id, supaya urutan tidak berkedip ketika
  // snapshot Firestore datang dengan urutan dokumen yang berbeda-beda.
  final byName = _norm(a.name).compareTo(_norm(b.name));
  if (byName != 0) return byName;
  return a.id.compareTo(b.id);
}

int _compareFrekuensi(Bill a, Bill b) {
  final byPeriod = _periodeHari(a).compareTo(_periodeHari(b));
  if (byPeriod != 0) return byPeriod;
  // Perulangan sama: pengingat yang paling awal (H-7) tampil dulu.
  return _offsetTerbesar(b).compareTo(_offsetTerbesar(a));
}

/// Teks tanpa peduli huruf besar/kecil & spasi tepi. Metode pembayaran diisi
/// bebas oleh pengguna, jadi "dana" dan "Dana" harus dianggap sama.
String _norm(String s) => s.trim().toLowerCase();

/// Panjang satu periode perulangan dalam hari.
///
/// Bulan dihitung 30 hari supaya "2 Minggu Sekali" (14) tetap berada sebelum
/// "1 Bulan Sekali" (30) — kalau `repeatEvery` dibandingkan mentah, angka 2
/// akan salah menempatkan 2 minggu setelah 1 bulan.
int _periodeHari(Bill b) {
  switch (b.repeatUnit) {
    case RepeatUnit.hari:
      return b.repeatEvery;
    case RepeatUnit.minggu:
      return b.repeatEvery * 7;
    case RepeatUnit.bulan:
      return b.repeatEvery * 30;
  }
}

/// Offset pengingat terjauh milik [b] (H-7 -> 7). 0 bila tidak ada pengingat.
int _offsetTerbesar(Bill b) =>
    b.reminderOffsets.isEmpty ? 0 : b.reminderOffsets.reduce(math.max);
