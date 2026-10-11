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

  /// "Diulang setiap": angka + satuan (contoh: 30 Hari sekali).
  final int repeatEvery;
  final RepeatUnit repeatUnit;

  /// "Ingatkan Pada": tanggal jatuh tempo berikutnya.
  final DateTime dueDate;

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

  const Bill({
    required this.id,
    required this.name,
    required this.type,
    required this.repeatEvery,
    required this.repeatUnit,
    required this.dueDate,
    required this.reminderOffsets,
    required this.estimatedCost,
    required this.paymentMethod,
    this.repeatLimit,
    this.remaining,
    required this.createdAt,
  });

  /// Jumlah hari menuju jatuh tempo (bisa negatif jika terlewat).
  int get daysUntilDue {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    return due.difference(today).inDays;
  }

  bool get isDueThisMonth {
    final now = DateTime.now();
    return dueDate.year == now.year && dueDate.month == now.month;
  }

  /// Deskripsi perulangan, contoh: "30 Hari Sekali".
  String get repeatDescription => '$repeatEvery ${repeatUnit.label} Sekali';

  /// Deskripsi offset pengingat, contoh: "H-7, H-3, H-1".
  String get reminderDescription =>
      reminderOffsets.map((d) => 'H-$d').join(', ');

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

  /// Majukan [from] sebanyak satu periode perulangan.
  DateTime _advanceFrom(DateTime from) {
    switch (repeatUnit) {
      case RepeatUnit.hari:
        return from.add(Duration(days: repeatEvery));
      case RepeatUnit.minggu:
        return from.add(Duration(days: repeatEvery * 7));
      case RepeatUnit.bulan:
        return DateTime(
          from.year,
          from.month + repeatEvery,
          from.day,
          from.hour,
          from.minute,
        );
    }
  }

  Bill copyWith({
    String? name,
    BillType? type,
    int? repeatEvery,
    RepeatUnit? repeatUnit,
    DateTime? dueDate,
    List<int>? reminderOffsets,
    double? estimatedCost,
    String? paymentMethod,
    int? repeatLimit,
    int? remaining,
  }) {
    return Bill(
      id: id,
      name: name ?? this.name,
      type: type ?? this.type,
      repeatEvery: repeatEvery ?? this.repeatEvery,
      repeatUnit: repeatUnit ?? this.repeatUnit,
      dueDate: dueDate ?? this.dueDate,
      reminderOffsets: reminderOffsets ?? this.reminderOffsets,
      estimatedCost: estimatedCost ?? this.estimatedCost,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      repeatLimit: repeatLimit ?? this.repeatLimit,
      remaining: remaining ?? this.remaining,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'type': type.index,
        'repeatEvery': repeatEvery,
        'repeatUnit': repeatUnit.index,
        'dueDate': dueDate.toIso8601String(),
        'reminderOffsets': reminderOffsets,
        'estimatedCost': estimatedCost,
        'paymentMethod': paymentMethod,
        'repeatLimit': repeatLimit,
        'remaining': remaining,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Bill.fromMap(Map<String, dynamic> map) => Bill(
        id: map['id'] as String,
        name: map['name'] as String,
        type: BillType.values[map['type'] as int],
        repeatEvery: map['repeatEvery'] as int,
        repeatUnit: RepeatUnit.values[map['repeatUnit'] as int],
        dueDate: DateTime.parse(map['dueDate'] as String),
        reminderOffsets:
            (map['reminderOffsets'] as List).map((e) => e as int).toList(),
        estimatedCost: (map['estimatedCost'] as num).toDouble(),
        paymentMethod: map['paymentMethod'] as String,
        repeatLimit: map['repeatLimit'] as int?,
        remaining: map['remaining'] as int?,
        createdAt: DateTime.parse(map['createdAt'] as String),
      );

  String toJson() => jsonEncode(toMap());
  factory Bill.fromJson(String source) =>
      Bill.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
