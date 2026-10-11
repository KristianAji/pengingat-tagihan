import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/bill.dart';

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
  bool _ready = false;

  // ── Channel id per tingkat urgensi ──
  static const String _chLow = 'reminder_low';
  static const String _chMedium = 'reminder_medium';
  static const String _chHigh = 'reminder_high';

  // Notifikasi dikirim pukul 08:00 waktu lokal pada hari pengingat.
  static const int _fireHour = 8;
  static const int _fireMinute = 0;

  /// Inisialisasi plugin + zona waktu + channel + izin. Dipanggil di main().
  Future<void> init() async {
    if (_ready) return;

    tzdata.initializeTimeZones();
    try {
      final localZone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localZone.identifier));
    } catch (_) {
      // Bila gagal mendeteksi zona, biarkan default (UTC).
    }

    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings =
        InitializationSettings(android: androidInit);
    await _plugin.initialize(settings: initSettings);

    await _createChannels();
    await _requestPermissions();
    _ready = true;
  }

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  Future<void> _createChannels() async {
    final android = _android;
    if (android == null) return;

    await android.createNotificationChannel(const AndroidNotificationChannel(
      _chLow,
      'Pengingat Awal (H-7)',
      description: 'Info tenang tanpa suara saat tenggat masih jauh.',
      importance: Importance.low,
      playSound: false,
      enableVibration: false,
    ));
    await android.createNotificationChannel(const AndroidNotificationChannel(
      _chMedium,
      'Peringatan (H-3)',
      description: 'Peringatan standar dengan suara dan getar.',
      importance: Importance.defaultImportance,
    ));
    await android.createNotificationChannel(const AndroidNotificationChannel(
      _chHigh,
      'Kritis (H-1 / Hari H)',
      description: 'Notifikasi penting yang muncul di atas layar.',
      importance: Importance.high,
    ));
  }

  Future<void> _requestPermissions() async {
    final android = _android;
    if (android == null) return;
    await android.requestNotificationsPermission();
    await android.requestExactAlarmsPermission();
  }

  /// Jadwalkan ulang seluruh notifikasi dari daftar [bills].
  /// Dipanggil setiap kali data tagihan berubah.
  Future<void> scheduleForBills(List<Bill> bills) async {
    if (!_ready) return;
    await _plugin.cancelAll();

    final now = DateTime.now();
    for (final bill in bills) {
      for (final offset in bill.reminderOffsets) {
        final fireDate = _fireDateFor(bill.dueDate, offset);
        if (fireDate.isBefore(now)) continue; // lewat, lewati
        await _scheduleOne(bill, offset, fireDate);
      }
    }
  }

  Future<void> cancelAll() => _plugin.cancelAll();

  // ── Internal ──

  DateTime _fireDateFor(DateTime dueDate, int offset) {
    final d = dueDate.subtract(Duration(days: offset));
    return DateTime(d.year, d.month, d.day, _fireHour, _fireMinute);
  }

  _Tier _tierFor(int offset) {
    if (offset >= 7) return _Tier.low;
    if (offset >= 3) return _Tier.medium;
    return _Tier.high;
  }

  int _notifId(String billId, int offset) =>
      (Object.hash(billId, offset)) & 0x7fffffff;

  Future<void> _scheduleOne(Bill bill, int offset, DateTime fireDate) async {
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
        id: _notifId(bill.id, offset),
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
        id: _notifId(bill.id, offset),
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
