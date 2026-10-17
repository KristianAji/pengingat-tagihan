import 'dart:convert';

/// Profil pengguna: identitas (nama panggilan) + data keuangan untuk fitur
/// Budget Burn-Rate & Predictor.
///
/// Disimpan di dokumen root `users/{uid}` (bukan sub-collection) karena
/// hanya ada satu profil per pengguna.
class UserProfile {
  /// Nama panggilan yang dipakai menyapa pengguna di Beranda.
  /// Kosong berarti belum diisi (dipakai fallback dari email).
  final String namaPanggilan;

  /// Total pemasukan / gaji per bulan (Rupiah).
  final double totalPemasukan;

  /// Tanggal gajian setiap bulan (1 - 31).
  final int tanggalGajian;

  const UserProfile({
    this.namaPanggilan = '',
    required this.totalPemasukan,
    required this.tanggalGajian,
  });

  /// Profil default (belum diisi): dipakai sebagai nilai awal UI.
  static const UserProfile empty = UserProfile(
    totalPemasukan: 0,
    tanggalGajian: 1,
  );

  /// true jika pengguna sudah mengisi datanya (dipakai untuk prompt setup).
  bool get isSet => totalPemasukan > 0;

  UserProfile copyWith({
    String? namaPanggilan,
    double? totalPemasukan,
    int? tanggalGajian,
  }) {
    return UserProfile(
      namaPanggilan: namaPanggilan ?? this.namaPanggilan,
      totalPemasukan: totalPemasukan ?? this.totalPemasukan,
      tanggalGajian: tanggalGajian ?? this.tanggalGajian,
    );
  }

  Map<String, dynamic> toMap() => {
    'namaPanggilan': namaPanggilan,
    'totalPemasukan': totalPemasukan,
    'tanggalGajian': tanggalGajian,
  };

  factory UserProfile.fromMap(Map<String, dynamic> map) => UserProfile(
    namaPanggilan: (map['namaPanggilan'] as String?)?.trim() ?? '',
    totalPemasukan: (map['totalPemasukan'] as num?)?.toDouble() ?? 0,
    tanggalGajian: (map['tanggalGajian'] as num?)?.toInt() ?? 1,
  );

  String toJson() => jsonEncode(toMap());
  factory UserProfile.fromJson(String source) =>
      UserProfile.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
