import 'package:flutter/material.dart';

import '../models/bill.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import 'dashboard_bill_card.dart';

/// Komponen daftar pada Halaman 2 — bisa di-expand untuk melihat detail.
class ExpandableBillCard extends StatelessWidget {
  const ExpandableBillCard({
    super.key,
    required this.bill,
    required this.expanded,
    required this.onToggle,
    required this.onPay,
    required this.onDelete,
    required this.onToggleMandatory,
  });

  final Bill bill;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onPay;
  final VoidCallback onDelete;

  /// Ubah penanda kebutuhan pokok (dasar perhitungan Dana Darurat).
  final VoidCallback onToggleMandatory;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: AppRadius.br,
          border: Border.all(
            color: expanded ? AppColors.primary : const Color(0xFFE9ECEF),
            width: expanded ? 1.5 : 1,
          ),
        ),
        child: expanded ? _expandedView(context) : _collapsedView(),
      ),
    );
  }

  Widget _collapsedView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
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
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              Formatters.rupiah(bill.estimatedCost),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            Row(
              children: [
                const Text(
                  'Detail',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const Icon(
                  Icons.expand_more,
                  color: AppColors.primary,
                  size: 20,
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _expandedView(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Nama lebih besar, jenis pindah ke baris baru
        Text(
          bill.name,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 19),
        ),
        const SizedBox(height: 6),
        TypeBadge(type: bill.type),
        const SizedBox(height: 14),
        const Text(
          'Detail',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 8),
        _detailRow('Metode Pembayaran', bill.paymentMethod),
        _detailRow('Diingatkan Setiap', bill.repeatDescription),
        _detailRow('Ingatkan Pada', Formatters.tanggal(bill.dueDate)),
        _detailRow('Pengingat', bill.reminderDescription),
        _detailRow(
          'Kebutuhan Pokok',
          bill.isMandatory ? 'Dihitung' : 'Tidak dihitung',
        ),
        _detailRow(
          'Perulangan',
          bill.repeatLimit == null
              ? 'Tanpa batas'
              : '${bill.remaining ?? bill.repeatLimit} dari ${bill.repeatLimit}x tersisa',
        ),
        const SizedBox(height: 8),
        Text(
          Formatters.rupiah(bill.estimatedCost),
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        const SizedBox(height: 6),
        // Switch-nya ada di dalam GestureDetector induk (yang membuka/tutup
        // kartu); tap di sini dimenangkan anak, jadi kartunya tidak ikut
        // terlipat — sama seperti tombol Hapus & Lunasi di bawah.
        Row(
          children: [
            const Icon(
              Icons.shield_outlined,
              size: 18,
              color: AppColors.primary,
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Hitung di Dana Darurat',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
            Switch(
              value: bill.isMandatory,
              activeThumbColor: AppColors.primary,
              onChanged: (_) => onToggleMandatory(),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            OutlinedButton.icon(
              onPressed: onDelete,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                side: const BorderSide(color: AppColors.danger),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('Hapus'),
            ),
            ElevatedButton.icon(
              onPressed: onPay,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.belanja,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: const Text('Lunasi'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
