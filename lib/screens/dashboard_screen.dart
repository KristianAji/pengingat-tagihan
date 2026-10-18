import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/bill.dart';
import '../providers/bill_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/profile_display.dart';
import '../widgets/category_pie_chart.dart';
import '../widgets/dashboard_bill_card.dart';
import '../widgets/burn_rate_card.dart';
import '../widgets/emergency_cash_card.dart';
import 'add_bill_screen.dart';
import 'bill_list_screen.dart';

/// Halaman 1: Dashboard Aplikasi.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BillProvider>();

    if (provider.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (provider.hasError) {
      return _errorState(provider);
    }

    final dueBills = provider.dueOrOverdue;

    // Sapaan: nama panggilan dari profil. Kalau belum ada (akun lama), jatuh
    // ke bagian depan email — aturannya sama dengan halaman Profil.
    final name = displayNameFor(
      provider.profile.namaPanggilan,
      FirebaseAuth.instance.currentUser?.email,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Text(
          'Halo, $name 👋',
          style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 2),
        const SizedBox(height: 18),

        // ── Fitur 1: Budget Burn-Rate & Predictor (kartu utama) ──
        const BurnRateCard(),
        const SizedBox(height: 14),

        // ── Fitur 3: Emergency Cash Reserve Calculator ──
        const EmergencyCashCard(),
        const SizedBox(height: 22),

        // ── Section 1: total + 2 tagihan terdekat ──
        _sectionTitle('Meowminder untuk bulan ini'),
        const SizedBox(height: 10),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 5,
                child: _totalBox(dueBills.length, provider.totalDue),
              ),
              const SizedBox(width: 12),
              Expanded(flex: 6, child: _nearestBoxes(provider.nearestDue)),
            ],
          ),
        ),
        const SizedBox(height: 22),

        // ── Section 2: diagram pengeluaran per kategori ──
        _sectionTitle('Pengeluaran'),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: CategoryPieChart(
              slices: _slices(provider.spendingByCategory),
            ),
          ),
        ),
        const SizedBox(height: 22),

        // ── Section 3: daftar tagihan bulan ini ──
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Expanded supaya judul yang panjang tidak meluber di layar sempit.
            Expanded(child: _sectionTitle('Moewlist Bulan ini & Meowdue')),
            TextButton(
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const BillListScreen())),
              child: const Text('Lihat semua'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (dueBills.isEmpty)
          _emptyState(context)
        else
          ...dueBills
              .take(4)
              .map(
                (b) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DashboardBillCard(
                    bill: b,
                    onPay: () => _confirmPay(context, b),
                  ),
                ),
              ),
      ],
    );
  }

  List<PieSlice> _slices(Map<BillType, double> data) {
    return [
      if ((data[BillType.tagihan] ?? 0) > 0)
        PieSlice('Tagihan', data[BillType.tagihan]!, AppColors.tagihan),
      if ((data[BillType.belanja] ?? 0) > 0)
        PieSlice('Belanja', data[BillType.belanja]!, AppColors.belanja),
    ];
  }

  Widget _sectionTitle(String t) => Text(
    t,
    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
  );

  Widget _totalBox(int count, double total) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.br,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Total Pengeluaran',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Text(
            Formatters.rupiah(total),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$count Meowlist Bulan ini',
            style: const TextStyle(color: Colors.white70, fontSize: 8),
          ),
        ],
      ),
    );
  }

  Widget _nearestBoxes(List<Bill> nearest) {
    if (nearest.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: AppRadius.br,
          border: Border.all(color: const Color(0xFFE9ECEF)),
        ),
        child: const Center(
          child: Text(
            'Tidak ada tenggat dekat',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ),
      );
    }
    return Column(
      children: nearest.map((b) {
        final urgent = b.daysUntilDue <= 3;
        return Container(
          margin: EdgeInsets.only(bottom: b == nearest.last ? 0 : 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: AppRadius.br,
            border: Border.all(
              color: urgent ? AppColors.danger : const Color(0xFFE9ECEF),
            ),
          ),
          child: Row(
            children: [
              Icon(
                urgent ? Icons.warning_amber_rounded : Icons.schedule,
                size: 18,
                color: urgent ? AppColors.danger : AppColors.warning,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      b.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      Formatters.countdown(b.daysUntilDue),
                      style: TextStyle(
                        fontSize: 11,
                        color: urgent ? AppColors.danger : AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// Ditampilkan saat stream Firestore gagal, supaya Beranda tidak berputar
  /// selamanya dan pengguna tetap punya jalan keluar.
  Widget _errorState(BillProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 56, color: AppColors.danger),
            const SizedBox(height: 12),
            const Text(
              'Gagal memuat data',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              provider.error ?? 'Terjadi kesalahan.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: provider.retry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Coba lagi'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      alignment: Alignment.center,
      child: Column(
        children: [
          const Icon(
            Icons.inbox_outlined,
            size: 48,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: 8),
          const Text(
            'Belum ada tagihan bulan ini',
            style: TextStyle(color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const AddBillScreen())),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Tambah Meowlist'),
          ),
        ],
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
              if (!await provider.markAsPaid(bill.id)) {
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
}
