import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/bill.dart';
import 'schedule_plan.dart';

/// Tingkat urgensi notifikasi (Barbell System).
enum _Tier { low, medium, high }

/// Fitur 2: Smart Notification Barbell System.
///
/// Mengirim notifikasi berjenjang sesuai jarak ke hari jatuh tempo:
///   H-7  -> Low    (IMPORTANCE_LOW, diam, tanpa suara/getar)
///   H-3  -> Medium (IMPORTANCE_DEFAULT, suara/getar standar)
///   H-1/H-> High   (IMPORTANCE_HIGH, heads-up + sticky/ongoing)
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Plugin sudah siap dipakai menjadwalkan notifikasi.
  ///
  /// Sengaja TIDAK dipengaruhi hasil permintaan izin: pengguna yang menolak
  /// izin tetap bisa memakai aplikasi, dan penjadwalan tetap berjalan
  /// (Android yang menyembunyikan notifikasinya). Dulu satu kegagalan izin
  /// mematikan penjadwalan sampai aplikasi di-restart.
  bool _initialized = false;

  /// Sedang menjalankan [init] — mencegah dua init berjalan bersamaan.
  bool _initializing = false;

  /// Tagihan terakhir yang diterima. null = belum ada snapshot sama sekali.
  ///
  /// [scheduleForBills] dipanggil dari stream Firestore, yang bisa berbunyi
  /// sebelum [init] selesai (init kini dijalankan setelah frame pertama).
  /// Daftarnya disimpan di sini dan dijadwalkan begitu plugin siap.
  List<Bill>? _pendingBills;

  /// Rantai penjadwalan, supaya dua pemanggilan tidak saling sisip. Tanpa ini,
  /// pembersihan milik proses kedua bisa menghapus jadwal yang baru saja
  /// ditulis proses pertama.
  Future<void> _scheduleChain = Future<void>.value();

  // ── Channel id per tingkat urgensi ──
  static const String _chLow = 'reminder_low';
  static const String _chMedium = 'reminder_medium';
  static const String _chHigh = 'reminder_high';

  /// Inisialisasi plugin + zona waktu + channel + izin.
  ///
  /// Aman dipanggil dari mana saja dan tidak pernah melempar: kegagalan cukup
  /// membuat notifikasi nonaktif, aplikasi tetap jalan.
  Future<void> init() async {
    if (_initialized || _initializing) return;
    _initializing = true;
    try {
      tzdata.initializeTimeZones();
      try {
        final localZone = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(localZone.identifier));
      } catch (_) {
        // Zona tetap UTC. Jam pengingat TIDAK ikut bergeser: TZDateTime.from
        // mempertahankan instant absolut, jadi notifikasi tetap dikirim pada
        // pukul 08:00 waktu perangkat.
      }

      try {
        const AndroidInitializationSettings androidInit =
            AndroidInitializationSettings('@mipmap/ic_launcher');
        const InitializationSettings initSettings = InitializationSettings(
          android: androidInit,
        );
        await _plugin.initialize(settings: initSettings);
        await _createChannels();
      } catch (_) {
        // Plugin benar-benar tidak bisa dipakai; penjadwalan tidak akan pernah
        // berhasil, jadi biarkan tetap ditandai belum siap.
        return;
      }

      _initialized = true;

      // Permintaan izin dipisah dari inisialisasi dan kegagalannya sengaja
      // diabaikan — lihat catatan pada [_initialized].
      try {
        await _requestPermissions();
      } catch (_) {}

      await _enqueueSchedule();
    } finally {
      _initializing = false;
    }
  }

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  Future<void> _createChannels() async {
    final android = _android;
    if (android == null) return;

    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        _chLow,
        'Pengingat Awal (H-7)',
        description: 'Info tenang tanpa suara saat tenggat masih jauh.',
        importance: Importance.low,
        playSound: false,
        enableVibration: false,
      ),
    );
    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        _chMedium,
        'Peringatan (H-3)',
        description: 'Peringatan standar dengan suara dan getar.',
        importance: Importance.defaultImportance,
      ),
    );
    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        _chHigh,
        'Kritis (H-1 / Hari H)',
        description: 'Notifikasi penting yang muncul di atas layar.',
        importance: Importance.high,
      ),
    );
  }

  Future<void> _requestPermissions() async {
    final android = _android;
    if (android == null) return;
    await android.requestNotificationsPermission();
    await android.requestExactAlarmsPermission();
  }

  /// Jadwalkan ulang seluruh notifikasi dari daftar [bills].
  /// Dipanggil setiap kali data tagihan berubah.
  ///
  /// Tidak pernah melempar, jadi aman dipanggil tanpa `await`.
  Future<void> scheduleForBills(List<Bill> bills) {
    _pendingBills = bills;
    if (!_initialized) return Future<void>.value();
    return _enqueueSchedule();
  }

  /// Batalkan semua pengingat, termasuk daftar tagihan yang masih tertunda.
  /// Dipakai saat keluar akun supaya notifikasi akun lama tidak muncul lagi.
  Future<void> cancelAll() async {
    _pendingBills = null;
    try {
      await _plugin.cancelAll();
    } catch (_) {
      // Gagal membatalkan tidak boleh menghalangi proses keluar.
    }
  }

  // ── Internal ──

  /// Masukkan satu penjadwalan ke rantai.
  Future<void> _enqueueSchedule() {
    _scheduleChain = _scheduleChain.then((_) => _applySchedule()).catchError((
      Object _,
    ) {
      // Kegagalan menjadwalkan tidak boleh memutus rantai berikutnya.
    });
    return _scheduleChain;
  }

  Future<void> _applySchedule() async {
    final bills = _pendingBills;
    // Belum ada snapshot: jangan hapus jadwal yang sudah ada.
    if (bills == null) return;

    final plan = SchedulePlan.build(bills, DateTime.now());
    await _cleanUp(plan);

    // zonedSchedule dengan id yang sama menimpa jadwal lama, jadi aman
    // dipanggil ulang untuk yang tidak berubah.
    for (final reminder in plan.upcoming.values) {
      try {
        await _scheduleOne(reminder);
      } catch (_) {
        // Satu tagihan gagal tidak boleh menggagalkan tagihan lainnya.
      }
    }
  }

  /// Bersihkan HANYA yang basi — bukan `cancelAll()`, supaya notifikasi yang
  /// sudah tampil dan masih berlaku (mis. H-1 sticky tagihan lain) tidak ikut
  /// hilang setiap kali data berubah atau aplikasi dibuka.
  Future<void> _cleanUp(SchedulePlan plan) async {
    try {
      final pending = await _plugin.pendingNotificationRequests();
      for (final id in plan.pendingToCancel(pending.map((r) => r.id))) {
        await _plugin.cancel(id: id);
      }
    } catch (_) {
      // Gagal membersihkan tidak boleh menghalangi penjadwalan.
    }
    try {
      final active = await _plugin.getActiveNotifications();
      final ids = active.map((n) => n.id).whereType<int>();
      for (final id in plan.activeToCancel(ids)) {
        await _plugin.cancel(id: id);
      }
    } catch (_) {
      // getActiveNotifications bisa tidak didukung di platform tertentu.
    }
  }

  _Tier _tierFor(int offset) {
    if (offset >= 7) return _Tier.low;
    if (offset >= 3) return _Tier.medium;
    return _Tier.high;
  }

  Future<void> _scheduleOne(PlannedReminder reminder) async {
    final bill = reminder.bill;
    final offset = reminder.offset;
    final id = reminder.id;
    final fireDate = reminder.fireDate;
    final tier = _tierFor(offset);
    final details = _detailsFor(tier);
    final tzTime = tz.TZDateTime.from(fireDate, tz.local);

    final String title = tier == _Tier.high
        ? '⚠️ ${bill.name} segera jatuh tempo'
        : 'Pengingat: ${bill.name}';
    final String body = offset <= 0
        ? 'Jatuh tempo hari ini. Jangan lupa dibayar.'
        : 'Jatuh tempo dalam $offset hari lagi (H-$offset).';

    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tzTime,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: bill.id,
      );
    } on Exception {
      // Fallback bila izin alarm presisi tidak diberikan (Android 12+).
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tzTime,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: bill.id,
      );
    }
  }

  NotificationDetails _detailsFor(_Tier tier) {
    switch (tier) {
      case _Tier.low:
        return const NotificationDetails(
          android: AndroidNotificationDetails(
            _chLow,
            'Pengingat Awal (H-7)',
            importance: Importance.low,
            priority: Priority.low,
            playSound: false,
            enableVibration: false,
          ),
        );
      case _Tier.medium:
        return const NotificationDetails(
          android: AndroidNotificationDetails(
            _chMedium,
            'Peringatan (H-3)',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
        );
      case _Tier.high:
        return const NotificationDetails(
          android: AndroidNotificationDetails(
            _chHigh,
            'Kritis (H-1 / Hari H)',
            importance: Importance.high,
            priority: Priority.high,
            ongoing: true, // sticky: tidak bisa digeser hilang
            autoCancel: false,
            fullScreenIntent: false,
          ),
        );
    }
  }
}
