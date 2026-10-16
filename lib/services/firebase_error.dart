import 'package:firebase_core/firebase_core.dart';

/// Terjemahkan error Firebase/Firestore ke pesan berbahasa Indonesia.
///
/// Dipakai [BillProvider] untuk mengisi pesan kegagalan baca (stream) maupun
/// tulis, supaya layar tidak perlu mengimpor cloud_firestore hanya untuk
/// membaca kode error.
String pesanErrorFirebase(Object? error) {
  if (error is FirebaseException) {
    switch (error.code) {
      case 'permission-denied':
        return 'Akses data ditolak. Coba keluar lalu masuk lagi.';
      case 'unavailable':
        return 'Tidak ada koneksi ke server. Periksa internetmu.';
      case 'unauthenticated':
        return 'Sesi login berakhir. Silakan masuk lagi.';
      case 'failed-precondition':
        return 'Data belum siap di server (indeks belum dibuat).';
      case 'deadline-exceeded':
        return 'Server tidak merespons. Coba lagi.';
      case 'not-found':
        return 'Data tidak ditemukan.';
      case 'resource-exhausted':
        return 'Kuota server habis. Coba lagi nanti.';
      default:
        return 'Terjadi kesalahan. (${error.code})';
    }
  }
  return 'Terjadi kesalahan. Coba lagi.';
}
