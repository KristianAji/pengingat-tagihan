import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/bill.dart';
import '../models/history_entry.dart';
import '../models/user_profile.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import '../utils/burn_rate.dart';

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

  List<Bill> get bills => List.unmodifiable(_bills);
  List<HistoryEntry> get history => List.unmodifiable(_history);
  UserProfile get profile => _profile;
  bool get loading => _loading;

  void _subscribe() {
    _billsSub = _service.billsStream().listen((data) {
      _bills = data;
      _loading = false;
      notifyListeners();
      // Fitur 2: jadwalkan ulang notifikasi tiap kali daftar tagihan berubah.
      NotificationService.instance.scheduleForBills(_bills);
    });
    _historySub = _service.historyStream().listen((data) {
      _history = data;
      notifyListeners();
    });
    _profileSub = _service.profileStream().listen((data) {
      _profile = data;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _billsSub?.cancel();
    _historySub?.cancel();
    _profileSub?.cancel();
    super.dispose();
  }

  // ── Getter turunan untuk dashboard ──

  List<Bill> get upcoming => _bills;

  List<Bill> get dueThisMonth =>
      _bills.where((b) => b.isDueThisMonth).toList();

  double get totalThisMonth =>
      dueThisMonth.fold(0.0, (sum, b) => sum + b.estimatedCost);

  List<Bill> get nearestDue {
    final sorted = [..._bills]
      ..sort((a, b) => a.daysUntilDue.compareTo(b.daysUntilDue));
    return sorted.take(2).toList();
  }

  Map<BillType, double> get spendingByCategory {
    final map = <BillType, double>{};
    for (final b in dueThisMonth) {
      map[b.type] = (map[b.type] ?? 0) + b.estimatedCost;
    }
    return map;
  }

  // ── Fitur 1: Budget Burn-Rate & Predictor ──

  /// Hasil perhitungan burn-rate dari profil + tagihan saat ini.
  BurnRateResult get burnRate =>
      BurnRateCalculator.calculate(_profile, _bills);

  /// true jika pengguna sudah mengisi pemasukan & tanggal gajian.
  bool get hasProfile => _profile.isSet;

  Future<void> saveProfile(UserProfile profile) =>
      _service.saveProfile(profile);

  // ── Aksi (menulis ke Firestore) ──

  Future<void> addBill(Bill bill) => _service.addBill(bill);

  Future<void> updateBill(Bill bill) => _service.updateBill(bill);

  Future<void> deleteBill(String id) => _service.deleteBill(id);

  Future<void> markAsPaid(String id) async {
    final i = _bills.indexWhere((b) => b.id == id);
    if (i == -1) return;
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
    await _service.markAsPaid(bill, entry);
  }

  Future<void> clearHistory() => _service.clearHistory();
}
