import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/bill.dart';
import '../providers/bill_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

/// Halaman 4: Riwayat tagihan yang sudah dibayar.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BillProvider>();
    final history = provider.history;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Riwayat Pembayaran',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            if (history.isNotEmpty)
              TextButton(
                onPressed: () => _confirmClear(context),
                child: const Text('Hapus Semua',
                    style: TextStyle(color: AppColors.danger)),
              ),
          ],
        ),
        const SizedBox(height: 6),
        if (history.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 80),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.history, size: 56, color: AppColors.textMuted),
                  SizedBox(height: 10),
                  Text('Belum ada riwayat pembayaran',
                      style: TextStyle(color: AppColors.textMuted)),
                ],
              ),
            ),
          )
        else
          ...history.map((h) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _historyTile(h),
              )),
      ],
    );
  }

  Widget _historyTile(dynamic h) {
    final isTagihan = h.type == BillType.tagihan;
    final color = AppColors.forType(isTagihan);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: AppRadius.br,
        border: Border.all(color: const Color(0xFFE9ECEF)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: AppRadius.br,
            ),
            child: Icon(Icons.check_circle, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(h.name,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  '${h.paymentMethod} • ${Formatters.tanggalWaktu(h.paidAt)}',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          Text(
            Formatters.rupiah(h.amount),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  void _confirmClear(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: AppRadius.shape,
        title: const Text('Hapus Semua Riwayat?'),
        content: const Text('Seluruh riwayat pembayaran akan dihapus permanen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () {
              context.read<BillProvider>().clearHistory();
              Navigator.pop(ctx);
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }
}
