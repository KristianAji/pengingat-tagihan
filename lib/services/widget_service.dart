import 'dart:convert';

import 'package:home_widget/home_widget.dart';

import '../models/bill.dart';
import '../utils/formatters.dart';

/// Fitur 4 (tahap 1): menyiapkan data untuk widget Home Screen Android.
///
/// Flutter tidak bisa menggambar widget Home Screen — widgetnya harus ditulis
/// di Kotlin (lihat `android/.../widget/BillWidget.kt`). Tugas kelas ini hanya
/// menyerahkan datanya: beberapa tagihan terdekat yang sudah siap ditampilkan,
/// lalu meminta Android menggambar ulang widgetnya.
///
/// Semua metode di sini menelan kegagalannya sendiri: widget adalah pelengkap,
/// jadi gagal menyiapkannya tidak boleh mengganggu aplikasi — pola yang sama
/// dengan NotificationService.
class WidgetService {
  WidgetService._();
  static final WidgetService instance = WidgetService._();

  /// Kelas receiver di sisi Android (lihat BillWidgetReceiver.kt).
  ///
  /// Ditulis lengkap (qualified), bukan nama pendek: plugin menyelesaikan nama
  /// pendek terhadap packageName aplikasi, jadi nama pendek akan salah kalau
  /// kelak applicationId berbeda dari namespace-nya.
  static const String _receiverClass =
      'com.pengingattagihan.app.widget.BillWidgetReceiver';

  /// Kunci data di penyimpanan widget. Sisi Kotlin membaca kunci yang sama
  /// lewat HomeWidgetGlanceState.
  static const String _dataKey = 'tagihan_json';

  /// Jumlah tagihan yang ditampilkan (spesifikasi: 3-5).
  static const int maxItems = 5;

  /// Kirim [bills] ke widget. Dipanggil setiap kali daftar tagihan berubah.
  Future<void> syncBills(List<Bill> bills) async {
    try {
      await HomeWidget.saveWidgetData<String>(_dataKey, _encode(_nearest(bills)));
      await HomeWidget.updateWidget(qualifiedAndroidName: _receiverClass);
    } catch (_) {
      // Diabaikan dengan sengaja.
    }
  }

  /// Kosongkan isi widget — dipakai saat keluar akun, supaya tagihan milik akun
  /// lama tidak tertinggal dan terbaca di Home Screen.
  Future<void> clear() async {
    try {
      await HomeWidget.saveWidgetData<String>(_dataKey, _encode(const []));
      await HomeWidget.updateWidget(qualifiedAndroidName: _receiverClass);
    } catch (_) {
      // Diabaikan dengan sengaja.
    }
  }

  String _encode(List<Bill> bills) => jsonEncode({
        'items': bills
            .map((b) => {
                  'nama': b.name,
                  'nominal': Formatters.rupiah(b.estimatedCost),
                  // Epoch ms, BUKAN teks "3 hari lagi": teks hitungan harinya
                  // dihitung ulang di sisi Kotlin setiap widget digambar, jadi
                  // tidak basi walau aplikasi tidak dibuka berhari-hari.
                  'jatuhTempo': b.dueDate.millisecondsSinceEpoch,
                })
            .toList(),
      });

  /// [maxItems] tagihan dengan jatuh tempo terdekat (yang telat ikut, di depan).
  static List<Bill> _nearest(List<Bill> bills) {
    final sorted = [...bills]
      ..sort((a, b) => a.daysUntilDue.compareTo(b.daysUntilDue));
    return sorted.take(maxItems).toList();
  }
}
