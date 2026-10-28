import '../models/bill.dart';

/// Satu pengingat yang akan dikirim.
class PlannedReminder {
  const PlannedReminder({
    required this.id,
    required this.bill,
    required this.offset,
    required this.fireDate,
  });

  final int id;
  final Bill bill;

  /// H-berapa (7, 3, 1, atau 0 = Hari-H). Nilai [SchedulePlan.overdueOffset]
  /// menandai pengingat HARIAN untuk tagihan yang sudah lewat jatuh tempo.
  final int offset;
  final DateTime fireDate;

  /// true bila ini pengingat harian "tagihan telat", bukan pengingat H-.
  bool get isOverdue => offset == SchedulePlan.overdueOffset;
}

/// Rencana pengingat dari daftar tagihan saat ini — murni (tanpa plugin),
/// supaya aturannya bisa diuji tanpa perangkat.
///
/// Dulu setiap perubahan data memanggil `cancelAll()` lalu menjadwalkan ulang
/// hanya yang masih di masa depan. Akibatnya notifikasi yang SUDAH TAMPIL
/// (termasuk yang sticky) ikut terhapus dan tidak pernah muncul lagi, mis.
/// ketika tagihan lain dilunasi atau aplikasi baru dibuka. Rencana ini
/// membedakan tiga golongan supaya pembersihannya selektif:
///
///  * [upcoming] — belum waktunya; dijadwalkan.
///  * [fired] — sudah waktunya untuk periode jatuh tempo yang berlaku saat
///    ini; kalau tampil di bilah notifikasi, biarkan.
///  * selain keduanya — basi (tagihan dilunasi/dihapus, jatuh tempo
///    bergeser, H- dihilangkan); dibatalkan.
///
/// Selain pengingat H-, setiap tagihan punya SATU pengingat "telat": notifikasi
/// harian pukul 08:00 yang mulai sehari setelah jatuh tempo. Ia sudah
/// dijadwalkan sebelum tagihan telat (jadi tetap berbunyi walau aplikasi tidak
/// dibuka), dan berhenti sendiri begitu tagihan dilunasi, karena jatuh tempo
/// yang maju membuat id-nya basi lalu dibatalkan. Itu sebabnya id telat bisa
/// berada di [upcoming] sekaligus [fired]: masih terjadwal berulang, dan
/// sebagian notifikasinya mungkin sedang tampil.
class SchedulePlan {
  SchedulePlan._(this.upcoming, this.fired);

  /// Id -> pengingat yang belum waktunya.
  final Map<int, PlannedReminder> upcoming;

  /// Id pengingat yang waktunya sudah lewat untuk jatuh tempo yang berlaku.
  final Set<int> fired;

  // Notifikasi dikirim pukul 08:00 waktu lokal pada hari pengingat.
  static const int fireHour = 8;
  static const int fireMinute = 0;

  /// "Offset" khusus untuk pengingat harian tagihan telat. Negatif supaya
  /// tidak pernah sama dengan H-n (0 = Hari-H, 1, 3, 7).
  static const int overdueOffset = -1;

  /// Id notifikasi untuk satu pengingat.
  ///
  /// Tanggal jatuh tempo ikut dihitung, jadi tiap PERIODE punya id sendiri.
  /// Setelah tagihan dilunasi dan jatuh temponya maju, notifikasi periode
  /// lama yang masih tampil punya id yang tidak lagi ada di rencana, sehingga
  /// bisa dikenali sebagai basi. Tanpa ini id-nya sama dan tidak bisa
  /// dibedakan dari notifikasi periode baru.
  ///
  /// Id dihitung dengan FNV-1a atas teks "tagihan|offset|tanggal", BUKAN
  /// `Object.hash`: Hari-H (offset 0) dan pengingat telat (offset -1)
  /// terbukti bertabrakan di `Object.hash`, dan hasilnya tidak dijamin sama
  /// antar versi Dart — padahal id harus tetap sama setelah aplikasi dibuka
  /// ulang agar jadwal lama bisa dikenali.
  static int notifId(String billId, int offset, DateTime dueDate) {
    final hari = dueDate.year * 10000 + dueDate.month * 100 + dueDate.day;
    return _fnv1a('$billId|$offset|$hari') & 0x7fffffff;
  }

  /// FNV-1a 32-bit. Perkalian 32-bit x 24-bit muat di int 64-bit milik Dart
  /// VM (Android), jadi tidak ada pembulatan.
  static int _fnv1a(String teks) {
    var h = 0x811c9dc5;
    for (final unit in teks.codeUnits) {
      h ^= unit;
      h = (h * 0x01000193) & 0xffffffff;
    }
    return h;
  }

  static DateTime fireDateFor(DateTime dueDate, int offset) {
    final d = dueDate.subtract(Duration(days: offset));
    return DateTime(d.year, d.month, d.day, fireHour, fireMinute);
  }

  /// Kapan pengingat telat pertama berbunyi untuk [dueDate].
  ///
  /// Normalnya pukul 08:00 sehari setelah jatuh tempo. Bila itu sudah lewat
  /// (tagihan sudah telat saat jadwal dibuat), dipakai pukul 08:00 berikutnya
  /// — hari ini kalau [now] belum 08:00, selain itu besok. Notifikasi harian
  /// lalu berulang tiap hari pada jam yang sama.
  static DateTime overdueFireDate(DateTime dueDate, DateTime now) {
    final pertama = DateTime(
      dueDate.year,
      dueDate.month,
      dueDate.day + 1,
      fireHour,
      fireMinute,
    );
    if (!pertama.isBefore(now)) return pertama;

    final hariIni = DateTime(now.year, now.month, now.day, fireHour, fireMinute);
    if (hariIni.isAfter(now)) return hariIni;
    return DateTime(now.year, now.month, now.day + 1, fireHour, fireMinute);
  }

  factory SchedulePlan.build(List<Bill> bills, DateTime now) {
    final upcoming = <int, PlannedReminder>{};
    final fired = <int>{};
    for (final bill in bills) {
      for (final offset in bill.reminderOffsets) {
        final id = notifId(bill.id, offset, bill.dueDate);
        final fireDate = fireDateFor(bill.dueDate, offset);
        if (fireDate.isBefore(now)) {
          fired.add(id);
        } else {
          upcoming[id] = PlannedReminder(
            id: id,
            bill: bill,
            offset: offset,
            fireDate: fireDate,
          );
        }
      }

      // Pengingat telat: selalu dijadwalkan, terlepas dari H- yang dipilih.
      final overdueId = notifId(bill.id, overdueOffset, bill.dueDate);
      final mulai = DateTime(
        bill.dueDate.year,
        bill.dueDate.month,
        bill.dueDate.day + 1,
        fireHour,
        fireMinute,
      );
      upcoming[overdueId] = PlannedReminder(
        id: overdueId,
        bill: bill,
        offset: overdueOffset,
        fireDate: overdueFireDate(bill.dueDate, now),
      );
      // Sudah mulai berbunyi: notifikasi yang sedang tampil jangan dihapus.
      if (mulai.isBefore(now)) fired.add(overdueId);
    }
    return SchedulePlan._(upcoming, fired);
  }

  /// Id jadwal tertunda yang harus dibatalkan: yang tidak ada di [upcoming].
  Set<int> pendingToCancel(Iterable<int> pendingIds) => {
    for (final id in pendingIds)
      if (!upcoming.containsKey(id)) id,
  };

  /// Id notifikasi tampil yang harus dihapus: yang bukan [fired] berlaku.
  Set<int> activeToCancel(Iterable<int> activeIds) => {
    for (final id in activeIds)
      if (!fired.contains(id)) id,
  };
}
