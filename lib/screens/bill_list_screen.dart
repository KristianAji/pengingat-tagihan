import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/bill.dart';
import '../providers/bill_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/expandable_bill_card.dart';
import 'add_bill_screen.dart';

/// Halaman 2: Daftar Tagihan & Belanja.
class BillListScreen extends StatefulWidget {
  const BillListScreen({super.key});

  @override
  State<BillListScreen> createState() => _BillListScreenState();
}

class _BillListScreenState extends State<BillListScreen> {
  String? _expandedId;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BillProvider>();
    final bills = provider.upcoming;
    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Row(
              children: [
                if (canPop)
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                if (canPop) const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Daftar Tagihan & Belanja',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Section 1.5: tombol tambah daftar baru
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AddBillScreen()),
                ),
                icon: const Icon(Icons.add, size: 20),
                label: const Text('Tambah Daftar Baru'),
              ),
            ),
            const SizedBox(height: 18),
            if (bills.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 60),
                child: Center(
                  child: Text(
                    'Belum ada daftar.\nTambahkan tagihan atau belanja pertamamu.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                ),
              )
            else
              ...bills.map(
                (b) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ExpandableBillCard(
                    bill: b,
                    expanded: _expandedId == b.id,
                    onToggle: () => setState(
                      () => _expandedId = _expandedId == b.id ? null : b.id,
                    ),
                    onPay: () => _confirmPay(context, b),
                    onDelete: () => _confirmDelete(context, b),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _confirmPay(BuildContext context, Bill bill) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: AppRadius.shape,
        title: const Text('Tandai Lunas?'),
        content: Text('Tandai "${bill.name}" sebagai sudah dibayar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<BillProvider>().markAsPaid(bill.id);
              Navigator.pop(ctx);
              setState(() => _expandedId = null);
            },
            child: const Text('Ya, Lunasi'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, Bill bill) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: AppRadius.shape,
        title: const Text('Hapus Daftar?'),
        content: Text('Hapus "${bill.name}" secara permanen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () {
              context.read<BillProvider>().deleteBill(bill.id);
              Navigator.pop(ctx);
              setState(() => _expandedId = null);
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }
}
