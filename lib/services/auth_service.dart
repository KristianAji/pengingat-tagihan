import 'package:firebase_auth/firebase_auth.dart';

import 'notification_service.dart';
import 'widget_service.dart';

/// Membungkus FirebaseAuth untuk login/daftar/keluar berbasis email & password.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Stream status login — dipakai sebagai "auth gate" di main.dart.
  Stream<User?> get authState => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> register(String email, String password) {
    return _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<UserCredential> login(String email, String password) {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Mengganti password akun.
  ///
  /// Firebase mewajibkan autentikasi ulang sebelum `updatePassword()` kalau
  /// sesi sudah lama, jadi password lama diverifikasi lebih dulu dengan
  /// `reauthenticateWithCredential`. Password lama yang salah akan memunculkan
  /// `wrong-password`/`invalid-credential` — pesannya sudah diterjemahkan
  /// [messageFromCode].
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'Tidak ada akun yang sedang masuk.',
      );
    }
    final credential = EmailAuthProvider.credential(
      email: email,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(credential);
    await user.updatePassword(newPassword);
  }

  /// Keluar dari akun. Pengingat & isi widget milik akun ini dibersihkan lebih
  /// dulu supaya tagihan akun lama tidak muncul lagi setelah keluar — widget
  /// tetap terlihat di Home Screen walau aplikasinya sudah ditutup.
  Future<void> logout() async {
    try {
      await NotificationService.instance.cancelAll();
      await WidgetService.instance.clear();
    } catch (_) {
      // Gagal membersihkan tidak boleh menghalangi proses keluar.
    }
    await _auth.signOut();
  }

  /// Menerjemahkan kode error FirebaseAuth ke pesan berbahasa Indonesia.
  static String messageFromCode(String code) {
    switch (code) {
      case 'invalid-email':
        return 'Format email tidak valid.';
      case 'user-disabled':
        return 'Akun ini dinonaktifkan.';
      case 'user-not-found':
        return 'Akun tidak ditemukan.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email atau password salah.';
      case 'email-already-in-use':
        return 'Email sudah terdaftar.';
      case 'weak-password':
        return 'Password terlalu lemah (minimal 6 karakter).';
      case 'network-request-failed':
        return 'Gagal terhubung ke jaringan.';
      case 'too-many-requests':
        return 'Terlalu banyak percobaan. Coba lagi nanti.';
      case 'requires-recent-login':
        return 'Sesi sudah lama. Keluar lalu masuk lagi, kemudian coba lagi.';
      case 'no-current-user':
        return 'Tidak ada akun yang sedang masuk.';
      default:
        return 'Terjadi kesalahan. ($code)';
    }
  }
}
