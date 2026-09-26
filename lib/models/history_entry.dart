import 'dart:convert';

import 'bill.dart';

/// Catatan riwayat setiap kali sebuah tagihan/belanja ditandai lunas.
class HistoryEntry {
  final String id;
  final String billId;
  final String name;
  final BillType type;
  final double amount;
  final String paymentMethod;
  final DateTime paidAt;

  const HistoryEntry({
    required this.id,
    required this.billId,
    required this.name,
    required this.type,
    required this.amount,
    required this.paymentMethod,
    required this.paidAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'billId': billId,
        'name': name,
        'type': type.index,
        'amount': amount,
        'paymentMethod': paymentMethod,
        'paidAt': paidAt.toIso8601String(),
      };

  factory HistoryEntry.fromMap(Map<String, dynamic> map) => HistoryEntry(
        id: map['id'] as String,
        billId: map['billId'] as String,
        name: map['name'] as String,
        type: BillType.values[map['type'] as int],
        amount: (map['amount'] as num).toDouble(),
        paymentMethod: map['paymentMethod'] as String,
        paidAt: DateTime.parse(map['paidAt'] as String),
      );

  String toJson() => jsonEncode(toMap());
  factory HistoryEntry.fromJson(String source) =>
      HistoryEntry.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
