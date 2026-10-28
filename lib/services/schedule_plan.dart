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

  /// H-berapa (7, 3, 1, ...).
  final int offset;
  final DateTime fireDate;
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
class SchedulePlan {
  SchedulePlan._(this.upcoming, this.fired);

  /// Id -> pengingat yang belum waktunya.
  final Map<int, PlannedReminder> upcoming;

  /// Id pengingat yang waktunya sudah lewat untuk jatuh tempo yang berlaku.
  final Set<int> fired;

  // Notifikasi dikirim pukul 08:00 waktu lokal pada hari pengingat.
  static const int fireHour = 8;
  static const int fireMinute = 0;

  /// Id notifikasi untuk satu pengingat.
  ///
  /// Tanggal jatuh tempo ikut dihitung, jadi tiap PERIODE punya id sendiri.
  /// Setelah tagihan dilunasi dan jatuh temponya maju, notifikasi periode
  /// lama yang masih tampil punya id yang tidak lagi ada di rencana, sehingga
  /// bisa dikenali sebagai basi. Tanpa ini id-nya sama dan tidak bisa
  /// dibedakan dari notifikasi periode baru.
  static int notifId(String billId, int offset, DateTime dueDate) {
    final hari = dueDate.year * 10000 + dueDate.month * 100 + dueDate.day;
    return Object.hash(billId, offset, hari) & 0x7fffffff;
  }

  static DateTime fireDateFor(DateTime dueDate, int offset) {
    final d = dueDate.subtract(Duration(days: offset));
    return DateTime(d.year, d.month, d.day, fireHour, fireMinute);
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
