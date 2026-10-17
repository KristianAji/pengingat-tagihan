import 'package:flutter/material.dart';

import '../models/bill.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

/// Badge kecil untuk kategori Tagihan / Belanja.
class TypeBadge extends StatelessWidget {
  const TypeBadge({super.key, required this.type});
  final BillType type;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.forType(type == BillType.tagihan);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        type.label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Komponen "entri daftar dashboard" — kotak dalam kotak.
class DashboardBillCard extends StatelessWidget {
  const DashboardBillCard({super.key, required this.bill, required this.onPay});

  final Bill bill;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    final days = bill.daysUntilDue;
    final urgent = days <= 3;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.br,
        border: Border.all(color: const Color(0xFFE9ECEF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Baris atas: nama + kategori (kiri), countdown (kanan)
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        bill.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TypeBadge(type: bill.type),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: (urgent ? AppColors.danger : AppColors.textMuted)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  Formatters.countdown(days),
                  style: TextStyle(
                    color: urgent ? AppColors.danger : AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Baris tengah: metode bayar (kiri) + frekuensi pengingat (kanan)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _iconText(
                Icons.account_balance_wallet_outlined,
                bill.paymentMethod,
              ),
              _iconText(
                Icons.notifications_active_outlined,
                bill.repeatDescription,
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Baris bawah: jumlah (kiri) + tombol lunasi (kanan)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                Formatters.rupiah(bill.estimatedCost),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: AppColors.textDark,
                ),
              ),
              SizedBox(
                height: 36,
                child: ElevatedButton(
                  onPressed: onPay,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    backgroundColor: AppColors.belanja,
                  ),
                  child: const Text('Lunasi'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _iconText(IconData icon, String text) {
    return Flexible(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.textMuted),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}
