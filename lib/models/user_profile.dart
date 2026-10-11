import 'dart:convert';

/// Profil keuangan pengguna untuk fitur Budget Burn-Rate & Predictor.
///
/// Disimpan di dokumen root `users/{uid}` (bukan sub-collection) karena
/// hanya ada satu profil per pengguna.
class UserProfile {
  /// Total pemasukan / gaji per bulan (Rupiah).
  final double totalPemasukan;

  /// Tanggal gajian setiap bulan (1 - 31).
  final int tanggalGajian;

  const UserProfile({
    required this.totalPemasukan,
    required this.tanggalGajian,
  });

  /// Profil default (belum diisi): dipakai sebagai nilai awal UI.
  static const UserProfile empty =
      UserProfile(totalPemasukan: 0, tanggalGajian: 1);

  /// true jika pengguna sudah mengisi datanya (dipakai untuk prompt setup).
  bool get isSet => totalPemasukan > 0;

  UserProfile copyWith({double? totalPemasukan, int? tanggalGajian}) {
    return UserProfile(
      totalPemasukan: totalPemasukan ?? this.totalPemasukan,
      tanggalGajian: tanggalGajian ?? this.tanggalGajian,
    );
  }

  Map<String, dynamic> toMap() => {
        'totalPemasukan': totalPemasukan,
        'tanggalGajian': tanggalGajian,
      };

  factory UserProfile.fromMap(Map<String, dynamic> map) => UserProfile(
        totalPemasukan: (map['totalPemasukan'] as num?)?.toDouble() ?? 0,
        tanggalGajian: (map['tanggalGajian'] as num?)?.toInt() ?? 1,
      );

  String toJson() => jsonEncode(toMap());
  factory UserProfile.fromJson(String source) =>
      UserProfile.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
