import 'dart:convert';

/// Jenis daftar: tagihan atau belanja.
enum BillType { tagihan, belanja }

/// Satuan waktu untuk perulangan.
enum RepeatUnit { hari, minggu, bulan }

extension BillTypeLabel on BillType {
  String get label => this == BillType.tagihan ? 'Tagihan' : 'Belanja';
}

extension RepeatUnitLabel on RepeatUnit {
  String get label {
    switch (this) {
      case RepeatUnit.hari:
        return 'Hari';
      case RepeatUnit.minggu:
        return 'Minggu';
      case RepeatUnit.bulan:
        return 'Bulan';
    }
  }
}

/// Model utama sebuah tagihan / daftar belanja.
class Bill {
  final String id;
  final String name;
  final BillType type;

  /// true bila item ini termasuk kebutuhan pokok.
  ///
  /// Dipakai sebagai dasar perhitungan Dana Darurat (fitur 3) dan tagihan
  /// wajib pada Burn-Rate (fitur 1). Bila tidak diisi saat membuat objek,
  /// nilainya mengikuti [type]: Tagihan dianggap wajib, Belanja tidak.
  final bool isMandatory;

  /// "Diulang setiap": angka + satuan (contoh: 30 Hari sekali).
  final int repeatEvery;
  final RepeatUnit repeatUnit;

  /// "Ingatkan Pada": tanggal jatuh tempo berikutnya.
  final DateTime dueDate;

  /// Tanggal yang dimaksud pengguna untuk perulangan bulanan (1-31).
  ///
  /// Perlu disimpan terpisah dari [dueDate]: begitu jatuh tempo terpotong ke
  /// bulan yang lebih pendek (31 Jan -> 28 Feb), `dueDate.day` sudah 28 dan
  /// tanggal asli 31 tidak bisa dipulihkan darinya. Tanpa ini, tagihan
  /// tanggal 31 melorot ke tanggal 28 selamanya.
  ///
  /// null = dokumen lama atau perulangan bukan bulanan; dalam kasus itu
  /// dipakai `dueDate.day` seperti sebelumnya.
  final int? anchorDay;

  /// H-berapa saja pengingat dikirim, contoh [7, 3, 1].
  final List<int> reminderOffsets;

  /// Estimasi biaya dalam Rupiah.
  final double estimatedCost;

  /// Metode pembayaran, contoh: Dana, OVO.
  final String paymentMethod;

  /// Batas perulangan (contoh cicilan 12x). null = tanpa batas.
  final int? repeatLimit;

  /// Sisa perulangan yang belum lunas. null jika tanpa batas.
  final int? remaining;

  final DateTime createdAt;

  /// [isMandatory] sengaja opsional dan TIDAK `const`: kalau tidak diisi,
  /// nilainya diturunkan dari [type] (Tagihan = wajib, Belanja = tidak).
  /// Dengan begitu dokumen lama yang belum punya field ini tetap terhitung
  /// benar tanpa perlu migrasi data.
  Bill({
    required this.id,
    required this.name,
    required this.type,
    required this.repeatEvery,
    required this.repeatUnit,
    required this.dueDate,
    this.anchorDay,
    required this.reminderOffsets,
    required this.estimatedCost,
    required this.paymentMethod,
    this.repeatLimit,
    this.remaining,
    required this.createdAt,
    bool? isMandatory,
  }) : isMandatory = isMandatory ?? (type == BillType.tagihan);

  /// Jumlah hari menuju jatuh tempo (bisa negatif jika terlewat).
  int get daysUntilDue {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    return due.difference(today).inDays;
  }

  /// true bila jatuh tempo bulan ini ATAU sudah terlewat (belum dibayar).
  ///
  /// Dipakai Beranda supaya tagihan telat dari bulan lalu tetap ikut terhitung,
  /// bukan menghilang begitu bulannya berganti.
  bool get isDueOrOverdue {
    final now = DateTime.now();
    // DateTime(y, m + 1, 0) = hari terakhir bulan ini.
    final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    return !dueDate.isAfter(endOfMonth);
  }

  /// Deskripsi perulangan, contoh: "30 Hari Sekali".
  String get repeatDescription => '$repeatEvery ${repeatUnit.label} Sekali';

  /// Deskripsi offset pengingat, contoh: "H-7, H-3, H-1, Hari-H".
  String get reminderDescription =>
      reminderOffsets.map((d) => d == 0 ? 'Hari-H' : 'H-$d').join(', ');

  /// Tanggal jatuh tempo berikutnya setelah dibayar (maju satu periode).
  DateTime get nextDueDate => _advanceFrom(dueDate);

  /// Tanggal jatuh tempo berikutnya yang benar-benar SETELAH [ref]
  /// (biasanya hari ini). Untuk tagihan yang sudah telat beberapa periode,
  /// tanggal terus dimajukan per periode penuh sampai berada di masa depan,
  /// sehingga tagihan telat tidak lagi "jatuh tempo" setelah dilunasi.
  DateTime nextDueDateAfter(DateTime ref) {
    var next = _advanceFrom(dueDate);
    var guard = 0;
    while (!next.isAfter(ref) && guard < 20000) {
      next = _advanceFrom(next);
      guard++;
    }
    return next;
  }

  /// Batas pengaman putaran hitung [occurrencesUntil].
  static const int _maxOccurrences = 1000;

  /// Berapa kali item ini harus dibayar dari [now] sampai [end] (inklusif).
  ///
  /// Dipakai Burn-Rate: tagihan mingguan bisa jatuh tempo beberapa kali
  /// sebelum gajian, dan tiap kalinya memakai uang yang sama.
  ///
  ///  * Jatuh tempo yang sedang menunggu ([dueDate]) dihitung SATU kali,
  ///    juga bila sudah telat.
  ///  * Periode telat yang terlewat TIDAK dihitung ulang: markAsPaid memajukan
  ///    jatuh tempo ke periode pertama SETELAH hari ini ([nextDueDateAfter]),
  ///    jadi satu pelunasan menutup semuanya.
  ///  * Sesudah itu setiap periode yang jatuh sebelum atau tepat pada [end]
  ///    ikut dihitung.
  ///  * Cicilan ber-batas ([repeatLimit]) tidak dihitung melebihi sisanya.
  ///
  /// Mengembalikan 0 bila jatuh tempo berikutnya sudah melewati [end].
  int occurrencesUntil(DateTime end, DateTime now) {
    if (dueDate.isAfter(end)) return 0;

    // Data rusak (periode 0) akan membuat putaran tak maju; hitung sekali.
    if (repeatEvery <= 0) return 1;

    var count = 1;
    var next = nextDueDateAfter(now);
    var guard = 0;
    while (!next.isAfter(end) && guard < _maxOccurrences) {
      count++;
      next = _advanceFrom(next);
      guard++;
    }

    final limit = repeatLimit;
    if (limit != null) {
      final sisa = remaining ?? limit;
      if (count > sisa) count = sisa > 0 ? sisa : 0;
    }
    return count;
  }

  /// Majukan [from] sebanyak satu periode perulangan.
  DateTime _advanceFrom(DateTime from) {
    switch (repeatUnit) {
      case RepeatUnit.hari:
        return from.add(Duration(days: repeatEvery));
      case RepeatUnit.minggu:
        return from.add(Duration(days: repeatEvery * 7));
      case RepeatUnit.bulan:
        return _addMonths(from, repeatEvery);
    }
  }

  /// Majukan [from] sebanyak [months] bulan.
  ///
  /// Tanggal yang dituju adalah [anchorDay] (tanggal asli), bukan `from.day`,
  /// supaya bulan pendek tidak menggeser tanggalnya untuk bulan-bulan
  /// berikutnya: 31 Jan -> 28 Feb -> 31 Mar, bukan 28 Mar.
  DateTime _addMonths(DateTime from, int months) {
    final total = from.month - 1 + months;
    final target = anchorDay;
    final day = (target != null && target >= 1 && target <= 31)
        ? target
        : from.day;
    return dateInMonth(
      from.year + total ~/ 12,
      total % 12 + 1,
      day,
      hour: from.hour,
      minute: from.minute,
    );
  }

  /// Tanggal [day] pada bulan [month] tahun [year].
  ///
  /// Bila bulan itu tidak punya tanggal tersebut — contoh tanggal 31 di
  /// Februari — dipakai tanggal terakhir bulan itu, sehingga pengingat tidak
  /// melompat ke bulan berikutnya.
  static DateTime dateInMonth(
    int year,
    int month,
    int day, {
    int hour = 0,
    int minute = 0,
  }) {
    final lastDay = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, day <= lastDay ? day : lastDay, hour, minute);
  }

  Bill copyWith({
    String? name,
    BillType? type,
    int? repeatEvery,
    RepeatUnit? repeatUnit,
    DateTime? dueDate,
    int? anchorDay,
    List<int>? reminderOffsets,
    double? estimatedCost,
    String? paymentMethod,
    int? repeatLimit,
    int? remaining,
    bool? isMandatory,
  }) {
    return Bill(
      id: id,
      name: name ?? this.name,
      type: type ?? this.type,
      repeatEvery: repeatEvery ?? this.repeatEvery,
      repeatUnit: repeatUnit ?? this.repeatUnit,
      dueDate: dueDate ?? this.dueDate,
      anchorDay: anchorDay ?? this.anchorDay,
      reminderOffsets: reminderOffsets ?? this.reminderOffsets,
      estimatedCost: estimatedCost ?? this.estimatedCost,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      repeatLimit: repeatLimit ?? this.repeatLimit,
      remaining: remaining ?? this.remaining,
      createdAt: createdAt,
      isMandatory: isMandatory ?? this.isMandatory,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'type': type.index,
    'repeatEvery': repeatEvery,
    'repeatUnit': repeatUnit.index,
    'dueDate': dueDate.toIso8601String(),
    'anchorDay': anchorDay,
    'reminderOffsets': reminderOffsets,
    'estimatedCost': estimatedCost,
    'paymentMethod': paymentMethod,
    'repeatLimit': repeatLimit,
    'remaining': remaining,
    'createdAt': createdAt.toIso8601String(),
    'isMandatory': isMandatory,
  };

  factory Bill.fromMap(Map<String, dynamic> map) {
    final type = BillType.values[map['type'] as int];
    return Bill(
      id: map['id'] as String,
      name: map['name'] as String,
      type: type,
      repeatEvery: map['repeatEvery'] as int,
      repeatUnit: RepeatUnit.values[map['repeatUnit'] as int],
      dueDate: DateTime.parse(map['dueDate'] as String),
      // Dokumen lama belum punya field ini -> null (pakai dueDate.day).
      anchorDay: map['anchorDay'] as int?,
      reminderOffsets: (map['reminderOffsets'] as List)
          .map((e) => e as int)
          .toList(),
      estimatedCost: (map['estimatedCost'] as num).toDouble(),
      paymentMethod: map['paymentMethod'] as String,
      repeatLimit: map['repeatLimit'] as int?,
      remaining: map['remaining'] as int?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      // Dokumen lama belum menyimpan field ini -> pakai bawaan dari jenisnya.
      isMandatory: map['isMandatory'] as bool? ?? (type == BillType.tagihan),
    );
  }

  String toJson() => jsonEncode(toMap());
  factory Bill.fromJson(String source) =>
      Bill.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
