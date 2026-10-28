import '../models/bill.dart';
import '../models/user_profile.dart';

/// Status indikator Budget Burn-Rate, dari yang paling longgar:
///  * aman       — batas harian >= [BurnRateCalculator.batasAman]
///  * terbatas   — di antara [BurnRateCalculator.batasTerbatas] dan batas aman
///  * kritis     — masih positif tapi di bawah [BurnRateCalculator.batasTerbatas]
///  * overbudget — tagihan wajib melebihi pemasukan (Free Cash Flow negatif)
enum BurnRateStatus { aman, terbatas, kritis, overbudget }

extension BurnRateStatusLabel on BurnRateStatus {
  String get label {
    switch (this) {
      case BurnRateStatus.aman:
        return 'Aman';
      case BurnRateStatus.terbatas:
        return 'Terbatas';
      case BurnRateStatus.kritis:
        return 'Kritis';
      case BurnRateStatus.overbudget:
        return 'Overbudget';
    }
  }
}

/// Hasil perhitungan Budget Burn-Rate & Predictor.
class BurnRateResult {
  final double totalPemasukan;
  final double totalTagihanWajib;
  final double freeCashFlow;
  final int sisaHari;
  final double batasAmanHarian;
  final DateTime nextPayday;
  final BurnRateStatus status;

  const BurnRateResult({
    required this.totalPemasukan,
    required this.totalTagihanWajib,
    required this.freeCashFlow,
    required this.sisaHari,
    required this.batasAmanHarian,
    required this.nextPayday,
    required this.status,
  });

  /// Rasio alokasi tagihan terhadap pemasukan (0..1) untuk progress bar.
  double get allocationRatio {
    if (totalPemasukan <= 0) return 0;
    final r = totalTagihanWajib / totalPemasukan;
    return r.clamp(0.0, 1.0);
  }
}

/// Logika murni perhitungan burn-rate (dipisah agar mudah diuji).
///
/// Rumus (sesuai spesifikasi):
///   Free Cash Flow = Gaji - Total Tagihan Wajib Belum Dibayar
///   Sisa Hari      = Tanggal Gajian Berikutnya - Hari Ini
///   Batas Aman Harian = Free Cash Flow / Sisa Hari
class BurnRateCalculator {
  /// Batas harian (Rupiah per hari) untuk status Aman. Tepat di batas = aman.
  static const double batasAman = 30000;

  /// Batas harian untuk status Terbatas; di bawahnya Kritis.
  static const double batasTerbatas = 10000;

  /// Hitung tanggal gajian berikutnya dari [tanggalGajian] (1-31).
  /// Hari dibatasi ke jumlah hari bulan terkait (mis. 31 -> 28/29 di Feb).
  static DateTime nextPayday(int tanggalGajian, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);

    DateTime candidate = _clampedDate(now.year, now.month, tanggalGajian);
    // Jika gajian bulan ini sudah lewat / tepat hari ini -> maju ke bulan depan.
    if (!candidate.isAfter(today)) {
      candidate = _clampedDate(now.year, now.month + 1, tanggalGajian);
    }
    return candidate;
  }

  /// Buat DateTime yang aman walau [day] melebihi jumlah hari di bulan itu.
  static DateTime _clampedDate(int year, int month, int day) {
    // Hari ke-0 bulan berikutnya = hari terakhir bulan ini.
    final lastDay = DateTime(year, month + 1, 0).day;
    final safeDay = day > lastDay ? lastDay : day;
    return DateTime(year, month, safeDay);
  }

  static BurnRateResult calculate(
    UserProfile profile,
    List<Bill> bills, {
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    final payday = nextPayday(profile.tanggalGajian, current);

    final today = DateTime(current.year, current.month, current.day);
    final sisaHari = payday.difference(today).inDays.clamp(1, 366);

    // Tagihan wajib = item bertanda wajib (bawaannya: jenis Tagihan) yang
    // jatuh tempo sebelum/pada tanggal gajian berikutnya (satu siklus gaji).
    //
    // Tiap item dihitung sebanyak jumlah jatuh temponya dalam siklus itu:
    // tagihan mingguan yang jatuh tempo 4x sebelum gajian memakai uang 4x,
    // bukan sekali (lihat Bill.occurrencesUntil).
    //
    // Memakai Bill.isMandatory, bukan langsung jenisnya, supaya angkanya
    // sejalan dengan kartu Dana Darurat yang memakai penanda yang sama —
    // kalau tidak, dua kartu bisa menyebut "tagihan wajib" dengan nilai beda.
    final totalWajib = bills
        .where((b) => b.isMandatory)
        .fold<double>(
          0,
          (sum, b) => sum + b.estimatedCost * b.occurrencesUntil(payday, current),
        );

    final freeCashFlow = profile.totalPemasukan - totalWajib;
    final batasHarian = freeCashFlow / sisaHari;

    final BurnRateStatus status;
    if (freeCashFlow < 0) {
      status = BurnRateStatus.overbudget;
    } else if (batasHarian >= batasAman) {
      status = BurnRateStatus.aman;
    } else if (batasHarian >= batasTerbatas) {
      status = BurnRateStatus.terbatas;
    } else {
      status = BurnRateStatus.kritis;
    }

    return BurnRateResult(
      totalPemasukan: profile.totalPemasukan,
      totalTagihanWajib: totalWajib,
      freeCashFlow: freeCashFlow,
      sisaHari: sisaHari,
      batasAmanHarian: batasHarian,
      nextPayday: payday,
      status: status,
    );
  }
}
