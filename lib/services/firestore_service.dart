import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/bill.dart';
import '../models/history_entry.dart';
import '../models/user_profile.dart';

/// Akses data Firestore per-pengguna:
///   users/{uid}                     -> profil keuangan (burn-rate)
///   users/{uid}/bills/{billId}
///   users/{uid}/history/{historyId}
class FirestoreService {
  FirestoreService(this.uid);

  final String uid;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get _userDoc =>
      _db.collection('users').doc(uid);

  CollectionReference<Map<String, dynamic>> get _bills =>
      _userDoc.collection('bills');

  CollectionReference<Map<String, dynamic>> get _history =>
      _userDoc.collection('history');

  Stream<List<Bill>> billsStream() {
    return _bills.orderBy('dueDate').snapshots().map(
          (snap) => snap.docs.map((d) => Bill.fromMap(d.data())).toList(),
        );
  }

  Stream<List<HistoryEntry>> historyStream() {
    return _history.orderBy('paidAt', descending: true).snapshots().map(
          (snap) =>
              snap.docs.map((d) => HistoryEntry.fromMap(d.data())).toList(),
        );
  }

  /// Stream profil keuangan pengguna (burn-rate). Mengembalikan
  /// [UserProfile.empty] jika dokumen/field belum ada.
  Stream<UserProfile> profileStream() {
    return _userDoc.snapshots().map((snap) {
      final data = snap.data();
      if (data == null || data['tanggalGajian'] == null) {
        return UserProfile.empty;
      }
      return UserProfile.fromMap(data);
    });
  }

  Future<void> saveProfile(UserProfile profile) =>
      _userDoc.set(profile.toMap(), SetOptions(merge: true));

  Future<void> addBill(Bill bill) => _bills.doc(bill.id).set(bill.toMap());

  Future<void> updateBill(Bill bill) => _bills.doc(bill.id).set(bill.toMap());

  Future<void> deleteBill(String id) => _bills.doc(id).delete();

  Future<void> addHistory(HistoryEntry entry) =>
      _history.doc(entry.id).set(entry.toMap());

  /// Tandai lunas dalam satu batch: catat riwayat + ubah/hapus tagihan.
  Future<void> markAsPaid(Bill bill, HistoryEntry entry) async {
    final batch = _db.batch();
    batch.set(_history.doc(entry.id), entry.toMap());

    // Tanggal jatuh tempo berikutnya dihitung dari hari ini, agar tagihan
    // yang sudah telat langsung melompat ke jadwal berikutnya di masa depan.
    final nextDue = bill.nextDueDateAfter(DateTime.now());

    if (bill.repeatLimit != null) {
      final newRemaining = (bill.remaining ?? bill.repeatLimit!) - 1;
      if (newRemaining <= 0) {
        batch.delete(_bills.doc(bill.id)); // perulangan habis -> hapus
      } else {
        final updated = bill.copyWith(
          remaining: newRemaining,
          dueDate: nextDue,
        );
        batch.set(_bills.doc(bill.id), updated.toMap());
      }
    } else {
      final updated = bill.copyWith(dueDate: nextDue);
      batch.set(_bills.doc(bill.id), updated.toMap());
    }

    await batch.commit();
  }

  Future<void> clearHistory() async {
    final snap = await _history.get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}
