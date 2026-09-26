import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/bill.dart';
import '../models/history_entry.dart';

/// Akses data Firestore per-pengguna:
///   users/{uid}/bills/{billId}
///   users/{uid}/history/{historyId}
class FirestoreService {
  FirestoreService(this.uid);

  final String uid;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _bills =>
      _db.collection('users').doc(uid).collection('bills');

  CollectionReference<Map<String, dynamic>> get _history =>
      _db.collection('users').doc(uid).collection('history');

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

  Future<void> addBill(Bill bill) => _bills.doc(bill.id).set(bill.toMap());

  Future<void> updateBill(Bill bill) => _bills.doc(bill.id).set(bill.toMap());

  Future<void> deleteBill(String id) => _bills.doc(id).delete();

  Future<void> addHistory(HistoryEntry entry) =>
      _history.doc(entry.id).set(entry.toMap());

  /// Tandai lunas dalam satu batch: catat riwayat + ubah/hapus tagihan.
  Future<void> markAsPaid(Bill bill, HistoryEntry entry) async {
    final batch = _db.batch();
    batch.set(_history.doc(entry.id), entry.toMap());

    if (bill.repeatLimit != null) {
      final newRemaining = (bill.remaining ?? bill.repeatLimit!) - 1;
      if (newRemaining <= 0) {
        batch.delete(_bills.doc(bill.id)); // perulangan habis -> hapus
      } else {
        final updated = bill.copyWith(
          remaining: newRemaining,
          dueDate: bill.nextDueDate,
        );
        batch.set(_bills.doc(bill.id), updated.toMap());
      }
    } else {
      final updated = bill.copyWith(dueDate: bill.nextDueDate);
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
