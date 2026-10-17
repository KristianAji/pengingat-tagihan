import 'package:intl/intl.dart';

/// Helper format Rupiah & tanggal berbahasa Indonesia.
class Formatters {
  static final _rupiah = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  static String rupiah(double value) => _rupiah.format(value);

  static const List<String> _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];

  static const List<String> _monthsFull = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];

  /// Nama bulan lengkap dari angka 1-12, contoh: "Oktober".
  static String namaBulan(int month) => _monthsFull[month - 1];

  static String tanggal(DateTime d) =>
      '${d.day} ${_months[d.month - 1]} ${d.year}';

  static String tanggalWaktu(DateTime d) {
    final jam = d.hour.toString().padLeft(2, '0');
    final menit = d.minute.toString().padLeft(2, '0');
    return '${tanggal(d)}, $jam:$menit';
  }

  /// Teks countdown menuju hari-H.
  static String countdown(int days) {
    if (days < 0) return 'Terlewat ${-days} hari';
    if (days == 0) return 'Hari ini';
    if (days == 1) return 'Besok';
    return '$days hari lagi';
  }
}
