/// Nama yang ditampilkan di Beranda dan halaman Profil.
///
/// Urutan: nama panggilan dari profil → bagian depan email → "Pengguna".
/// Dipakai di dua tempat sekaligus supaya sapaan Beranda dan nama di Profil
/// tidak pernah berbeda.
String displayNameFor(String namaPanggilan, String? email) {
  final nick = namaPanggilan.trim();
  if (nick.isNotEmpty) return nick;

  final mail = (email ?? '').trim();
  if (mail.contains('@')) {
    final depan = mail.split('@').first.trim();
    if (depan.isNotEmpty) return depan;
  }
  return 'Pengguna';
}

/// Inisial 1–2 huruf untuk avatar profil.
///
/// "Kris Suseno" → "KS", "Kris" → "K", kosong → "?".
String initialsFor(String name) {
  final kata = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((k) => k.isNotEmpty)
      .toList();
  if (kata.isEmpty) return '?';
  if (kata.length == 1) {
    return kata.first.substring(0, 1).toUpperCase();
  }
  return (kata.first.substring(0, 1) + kata.last.substring(0, 1)).toUpperCase();
}
