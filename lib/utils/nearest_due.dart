import '../models/bill.dart';

/// Tagihan/belanja yang paling dekat jatuh temponya, khusus untuk kotak
/// "Meowminder untuk bulan ini" di Beranda.
///
/// Hanya item yang jatuh tempo bulan ini ATAU sudah telat yang ikut
/// ([Bill.isDueOrOverdue]) — aturan yang sama dengan daftar dan total di
/// bagian yang sama. Dulu semua tagihan dipertimbangkan, sehingga kotak ini
/// bisa menampilkan tagihan bulan depan di bawah judul "bulan ini".
///
/// Diurutkan menurut jumlah hari ke jatuh tempo, jadi yang paling telat
/// (angka paling negatif) berada di depan.
List<Bill> nearestDueBills(List<Bill> bills, {int limit = 2}) {
  final sorted = bills.where((b) => b.isDueOrOverdue).toList()
    ..sort((a, b) => a.daysUntilDue.compareTo(b.daysUntilDue));
  return sorted.take(limit).toList();
}
