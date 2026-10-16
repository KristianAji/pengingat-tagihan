import '../models/bill.dart';

/// Hasil perhitungan Dana Darurat (Emergency Cash Reserve).
class EmergencyCashResult {
  /// Rentang yang dipilih pengguna: 3, 6, atau 12 bulan.
  final int months;

  /// Total kebutuhan pokok bila dinormalkan ke satu bulan.
  final double monthlyMandatory;

  /// Dana darurat minimal = [monthlyMandatory] x [months].
  final double target;

  /// Berapa item yang ikut dihitung (yang ditandai wajib).
  final int itemCount;

  const EmergencyCashResult({
    required this.months,
    required this.monthlyMandatory,
    required this.target,
    required this.itemCount,
  });

  /// true bila belum ada satu pun item wajib, sehingga angkanya masih nol.
  bool get isEmpty => itemCount == 0;
}

/// Logika murni perhitungan Dana Darurat (dipisah agar mudah diuji).
///
/// Rumus (sesuai spesifikasi):
///   Total Tagihan Wajib per Bulan x 3/6/12 bulan = Dana Darurat Minimal
///
/// Bedanya dengan Burn-Rate: di sini SEMUA item wajib dihitung, bukan hanya
/// yang jatuh tempo dalam satu siklus gaji — karena dananya disiapkan untuk
/// beberapa bulan ke depan, bukan untuk sampai gajian berikutnya.
class EmergencyCashCalculator {
  /// Pilihan rentang bulan yang ditawarkan ke pengguna.
  static const List<int> pilihanBulan = [3, 6, 12];

  /// Rentang bawaan — 6 bulan adalah patokan dana darurat yang paling umum.
  static const int bulanDefault = 6;

  /// Rata-rata panjang satu bulan dalam hari (365,25 / 12).
  ///
  /// Dipakai untuk menormalkan perulangan mingguan/tahunan ke bulanan, supaya
  /// "1 Tahun Sekali" tidak dihitung sama besar dengan "1 Bulan Sekali".
  static const double hariPerBulan = 30.4375;

  /// Biaya item [bill] bila dinormalkan ke satu bulan.
  ///
  /// Contoh: "1 Tahun Sekali" Rp 1.200.000 -> Rp 100.000/bulan,
  /// "1 Minggu Sekali" Rp 50.000 -> sekitar Rp 217.000/bulan.
  static double monthlyCost(Bill bill) {
    final days = _periodeHari(bill);
    // repeatEvery 0 (atau data rusak) tidak punya arti per bulan.
    if (days <= 0) return 0;
    return bill.estimatedCost * hariPerBulan / days;
  }

  /// Panjang satu periode perulangan dalam hari.
  static double _periodeHari(Bill bill) {
    switch (bill.repeatUnit) {
      case RepeatUnit.hari:
        return bill.repeatEvery.toDouble();
      case RepeatUnit.minggu:
        return bill.repeatEvery * 7.0;
      case RepeatUnit.bulan:
        return bill.repeatEvery * hariPerBulan;
    }
  }

  /// Hitung dana darurat minimal dari daftar [bills] untuk [months] bulan.
  ///
  /// Hanya item bertanda [Bill.isMandatory] yang dihitung; status sudah
  /// dibayar atau belum sengaja diabaikan, karena dana darurat menyiapkan
  /// kebutuhan yang berulang tiap bulan — bukan pelunasan siklus berjalan.
  static EmergencyCashResult calculate(List<Bill> bills, int months) {
    final wajib = bills.where((b) => b.isMandatory).toList();
    final perBulan = wajib.fold<double>(0, (sum, b) => sum + monthlyCost(b));

    return EmergencyCashResult(
      months: months,
      monthlyMandatory: perBulan,
      target: perBulan * months,
      itemCount: wajib.length,
    );
  }
}
