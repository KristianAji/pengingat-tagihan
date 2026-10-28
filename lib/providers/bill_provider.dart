import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/bill.dart';
import '../models/history_entry.dart';
import '../models/user_profile.dart';
import '../services/firebase_error.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import '../services/widget_service.dart';
import '../utils/bill_sort.dart';
import '../utils/burn_rate.dart';
import '../utils/nearest_due.dart';
import '../utils/emergency_cash.dart';

/// State utama aplikasi, kini bersumber dari Firestore (per-pengguna).
/// Data diperbarui otomatis lewat stream snapshots().
class BillProvider extends ChangeNotifier {
  BillProvider(String uid) : _service = FirestoreService(uid) {
    _subscribe();
  }

  final FirestoreService _service;

  StreamSubscription? _billsSub;
  StreamSubscription? _historySub;
  StreamSubscription? _profileSub;

  List<Bill> _bills = [];
  List<HistoryEntry> _history = [];
  UserProfile _profile = UserProfile.empty;
  bool _loading = true;

  /// Pesan kegagalan MEMBACA data (stream). null = tidak ada masalah.
  String? _error;

  /// Pesan kegagalan terakhir yang perlu diketahui pengguna lewat snackbar:
  /// aksi tulis yang gagal, atau stream pendukung yang gagal dimuat.
  String? _lastError;

  // Pilihan sortir halaman Daftar. Disimpan di provider, bukan di screen,
  // karena HomeShell membuang state halaman yang tidak aktif — kalau ditaruh
  // di BillListScreen, pilihannya hilang tiap kali pengguna pindah tab.
  BillSortMode _sortMode = BillSortMode.jatuhTempo;
  bool _sortAscending = BillSortMode.jatuhTempo.defaultAscending;

  List<Bill> get bills => List.unmodifiable(_bills);
  List<HistoryEntry> get history => List.unmodifiable(_history);
  UserProfile get profile => _profile;
  bool get loading => _loading;

  /// Pesan error stream; kalau terisi, Beranda menampilkan layar error.
  String? get error => _error;
  bool get hasError => _error != null;

  /// Pesan kegagalan terakhir, untuk snackbar di layar.
  String? get lastError => _lastError;

  void _subscribe() {
    _billsSub = _service.billsStream().listen((data) {
      _bills = data;
      _loading = false;
      _error = null;
      notifyListeners();
      // Fitur 2: jadwalkan ulang notifikasi tiap kali daftar tagihan berubah.
      // Kegagalannya ditangani di dalam NotificationService, jadi hasilnya
      // tidak perlu ditunggu di sini.
      unawaited(NotificationService.instance.scheduleForBills(_bills));
      // Fitur 4: samakan isi widget Home Screen dengan daftar terbaru.
      unawaited(WidgetService.instance.syncBills(_bills));
    }, onError: _failBills);
    _historySub = _service.historyStream().listen((data) {
      _history = data;
      notifyListeners();
    }, onError: _failSecondary);
    _profileSub = _service.profileStream().listen((data) {
      _profile = data;
      notifyListeners();
    }, onError: _failSecondary);
  }

  /// Kegagalan membaca daftar tagihan — Beranda tidak bisa menampilkan apa pun
  /// tanpa data ini, jadi ditampilkan sebagai layar error penuh.
  ///
  /// [loading] dimatikan supaya Beranda berhenti berputar selamanya dan bisa
  /// menampilkan pesan beserta tombol "Coba lagi".
  void _failBills(Object? e) {
    _error = pesanErrorFirebase(e);
    _loading = false;
    notifyListeners();
  }

  /// Kegagalan stream pendukung (riwayat & profil).
  ///
  /// Beranda masih berguna tanpa keduanya, jadi kegagalannya TIDAK boleh
  /// menutupi seluruh layar dengan layar error seperti dulu. Cukup dicatat
  /// sebagai pesan terakhir; layar yang memang membutuhkan data itu yang
  /// menampilkannya.
  void _failSecondary(Object? e) {
    _lastError = pesanErrorFirebase(e);
    notifyListeners();
  }

  /// Pasang ulang ketiga stream dari awal — dipakai tombol "Coba lagi".
  void retry() {
    _billsSub?.cancel();
    _historySub?.cancel();
    _profileSub?.cancel();
    _loading = true;
    _error = null;
    notifyListeners();
    _subscribe();
  }

  @override
  void dispose() {
    _billsSub?.cancel();
    _historySub?.cancel();
    _profileSub?.cancel();
    super.dispose();
  }

  // ── Getter turunan untuk dashboard ──

  /// Tagihan/belanja yang jatuh tempo bulan ini ATAU sudah terlewat.
  /// Yang telat ikut dihitung supaya tidak hilang begitu bulannya berganti.
  List<Bill> get dueOrOverdue => _bills.where((b) => b.isDueOrOverdue).toList();

  double get totalDue =>
      dueOrOverdue.fold(0.0, (sum, b) => sum + b.estimatedCost);

  /// Dua tagihan terdekat DI ANTARA yang jatuh tempo bulan ini atau telat.
  List<Bill> get nearestDue => nearestDueBills(_bills);

  Map<BillType, double> get spendingByCategory {
    final map = <BillType, double>{};
    for (final b in dueOrOverdue) {
      map[b.type] = (map[b.type] ?? 0) + b.estimatedCost;
    }
    return map;
  }

  // ── Sortir halaman Daftar Tagihan & Belanja ──

  BillSortMode get sortMode => _sortMode;
  bool get sortAscending => _sortAscending;

  /// Seluruh tagihan/belanja, sudah urut sesuai pilihan pengguna.
  List<Bill> get sortedBills =>
      sortBills(_bills, _sortMode, ascending: _sortAscending);

  /// Ketuk chip sortir: mode yang sama membalik arah, mode lain pindah dan
  /// kembali ke arah defaultnya.
  void setSort(BillSortMode mode) {
    final next = nextSortState(_sortMode, _sortAscending, mode);
    if (next.mode == _sortMode && next.ascending == _sortAscending) return;
    _sortMode = next.mode;
    _sortAscending = next.ascending;
    notifyListeners();
  }

  // ── Fitur 1: Budget Burn-Rate & Predictor ──

  /// Hasil perhitungan burn-rate dari profil + tagihan saat ini.
  BurnRateResult get burnRate => BurnRateCalculator.calculate(_profile, _bills);

  /// true jika pengguna sudah mengisi pemasukan & tanggal gajian.
  bool get hasProfile => _profile.isSet;

  // ── Fitur 3: Emergency Cash Reserve Calculator (Dana Darurat) ──

  // Rentang bulan yang dipilih pengguna. Disimpan di provider dengan alasan
  // yang sama seperti pilihan sortir: Beranda dibuang saat pindah tab, jadi
  // kalau disimpan di kartunya, pilihannya hilang dan balik ke bawaan.
  int _emergencyMonths = EmergencyCashCalculator.bulanDefault;

  int get emergencyMonths => _emergencyMonths;

  void setEmergencyMonths(int months) {
    if (months == _emergencyMonths) return;
    _emergencyMonths = months;
    notifyListeners();
  }

  /// Hasil perhitungan dana darurat dari tagihan wajib saat ini.
  EmergencyCashResult get emergencyCash =>
      EmergencyCashCalculator.calculate(_bills, _emergencyMonths);

  /// Tandai/batalkan sebuah item sebagai kebutuhan pokok.
  ///
  /// Berdampak ke dua tempat sekaligus: kartu Dana Darurat dan "Tagihan Wajib"
  /// pada Burn-Rate, karena keduanya membaca penanda yang sama.
  Future<bool> setMandatory(Bill bill, bool value) =>
      updateBill(bill.copyWith(isMandatory: value));

  // ── Aksi (menulis ke Firestore) ──
  //
  // Semuanya mengembalikan true bila berhasil. Pesan kegagalan disimpan di
  // [lastError] supaya layar cukup menampilkan snackbar, tanpa perlu tahu
  // soal FirebaseException.

  /// Jalankan aksi tulis Firestore dan tangkap kegagalannya.
  Future<bool> _run(Future<void> Function() action) async {
    try {
      await action();
      _lastError = null;
      return true;
    } catch (e) {
      _lastError = pesanErrorFirebase(e);
      return false;
    }
  }

  Future<bool> saveProfile(UserProfile profile) =>
      _run(() => _service.saveProfile(profile));

  Future<bool> addBill(Bill bill) => _run(() => _service.addBill(bill));

  Future<bool> updateBill(Bill bill) => _run(() => _service.updateBill(bill));

  Future<bool> deleteBill(String id) => _run(() => _service.deleteBill(id));

  Future<bool> markAsPaid(String id) {
    final i = _bills.indexWhere((b) => b.id == id);
    if (i == -1) {
      _lastError = 'Tagihan tidak ditemukan. Muat ulang daftarnya.';
      return Future.value(false);
    }
    final bill = _bills[i];
    final entry = HistoryEntry(
      id: '${DateTime.now().microsecondsSinceEpoch}',
      billId: bill.id,
      name: bill.name,
      type: bill.type,
      amount: bill.estimatedCost,
      paymentMethod: bill.paymentMethod,
      paidAt: DateTime.now(),
    );
    return _run(() => _service.markAsPaid(bill, entry));
  }

  Future<bool> clearHistory() => _run(() => _service.clearHistory());
}
