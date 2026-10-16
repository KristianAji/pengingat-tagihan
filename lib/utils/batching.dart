/// Bagi [items] menjadi potongan berukuran maksimum [size].
///
/// Dipakai untuk operasi Firestore: satu `WriteBatch` dibatasi 500 operasi,
/// jadi daftar yang lebih panjang harus dipecah dan di-commit per potongan.
/// Daftar kosong menghasilkan tidak ada potongan sama sekali.
Iterable<List<T>> chunked<T>(List<T> items, int size) sync* {
  assert(size > 0, 'Ukuran potongan harus lebih dari 0.');
  for (var start = 0; start < items.length; start += size) {
    final end = start + size;
    yield items.sublist(start, end < items.length ? end : items.length);
  }
}
