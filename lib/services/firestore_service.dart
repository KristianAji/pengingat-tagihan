import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/bill.dart';
import '../models/history_entry.dart';
import '../models/user_profile.dart';
import '../utils/batching.dart';

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
    return _bills
        .orderBy('dueDate')
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => Bill.tryFromMap(d.data()))
              .whereType<Bill>() // dokumen rusak dilewati, bukan menggagalkan
              .toList(),
        );
  }

  Stream<List<HistoryEntry>> historyStream() {
    return _history
        .orderBy('paidAt', descending: true)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => HistoryEntry.fromMap(d.data())).toList(),
        );
  }

  /// Stream profil pengguna (nama panggilan + data burn-rate).
  /// Mengembalikan [UserProfile.empty] jika dokumennya belum ada.
  Stream<UserProfile> profileStream() {
    return _userDoc.snapshots().map((snap) {
      final data = snap.data();
      if (data == null) return UserProfile.empty;
      return UserProfile.fromMap(data);
    });
  }

  /// Menyimpan nama panggilan saja — dipakai saat pendaftaran akun baru,
  /// supaya tidak menimpa data keuangan yang mungkin sudah ada.
  Future<void> saveNamaPanggilan(String nama) =>
      _userDoc.set({'namaPanggilan': nama}, SetOptions(merge: true));

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

  /// Firestore menolak satu `WriteBatch` dengan lebih dari 500 operasi.
  static const int _batchLimit = 500;

  /// Hapus seluruh riwayat, dipecah per [._batchLimit] operasi.
  ///
  /// Tanpa pemecahan ini, tombol "Hapus semua riwayat" gagal permanen begitu
  /// jumlah riwayatnya lewat 500 — dan pesannya cuma "gagal menghapus".
  Future<void> clearHistory() async {
    final snap = await _history.get();
    for (final chunk in chunked(snap.docs, _batchLimit)) {
      final batch = _db.batch();
      for (final doc in chunk) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }
}
