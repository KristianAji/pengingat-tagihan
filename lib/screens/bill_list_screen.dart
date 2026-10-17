import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/bill.dart';
import '../providers/bill_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_logo.dart';
import '../widgets/expandable_bill_card.dart';
import '../widgets/sort_chip_bar.dart';
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
    final bills = provider.sortedBills;
    final canPop = Navigator.of(context).canPop();

    return Scaffold(
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
            if (bills.isNotEmpty) ...[
              SortChipBar(
                mode: provider.sortMode,
                ascending: provider.sortAscending,
                onSelect: provider.setSort,
              ),
              const SizedBox(height: 18),
            ],
            if (bills.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: Center(
                  child: Column(
                    children: [
                      AppLogo(size: 96),
                      SizedBox(height: 4),
                      Text(
                        'Belum ada daftar.\nTambahkan tagihan atau belanja pertamamu.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    ],
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
                    onToggleMandatory: () => _toggleMandatory(context, b),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Ubah penanda kebutuhan pokok langsung dari kartu.
  ///
  /// Dipakai sebagai jalan pintas karena layar "edit daftar" belum ada —
  /// tanpa ini, penanda hanya bisa diisi saat item dibuat, sehingga item lama
  /// tidak bisa dikeluarkan dari hitungan Dana Darurat.
  Future<void> _toggleMandatory(BuildContext context, Bill bill) async {
    final provider = context.read<BillProvider>();
    final messenger = ScaffoldMessenger.of(context);
    // Berhasil = diam; Firestore mengirim perubahan lokalnya sendiri sehingga
    // switch langsung bergerak tanpa perlu setState di sini.
    if (await provider.setMandatory(bill, !bill.isMandatory)) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(provider.lastError ?? 'Gagal menyimpan perubahan.'),
        behavior: SnackBarBehavior.floating,
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
            onPressed: () async {
              // Ditangkap sebelum await supaya tidak memakai context yang
              // sudah di-pop saat menampilkan pesan gagal.
              final provider = context.read<BillProvider>();
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(ctx);
              final ok = await provider.markAsPaid(bill.id);
              if (!mounted) return;
              setState(() => _expandedId = null);
              if (!ok) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      provider.lastError ?? 'Gagal menandai lunas.',
                    ),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
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
            onPressed: () async {
              final provider = context.read<BillProvider>();
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(ctx);
              final ok = await provider.deleteBill(bill.id);
              if (!mounted) return;
              setState(() => _expandedId = null);
              if (!ok) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(provider.lastError ?? 'Gagal menghapus.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }
}
