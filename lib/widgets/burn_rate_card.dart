import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user_profile.dart';
import '../providers/bill_provider.dart';
import '../theme/app_theme.dart';
import '../utils/burn_rate.dart';
import '../utils/formatters.dart';
import '../utils/rupiah_input.dart';

/// Fitur 1: kartu Budget Burn-Rate & Predictor untuk Dashboard.
///
/// Menampilkan batas aman belanja harian hingga tanggal gajian berikutnya,
/// lengkap dengan indikator status (hijau/kuning/merah) & progress alokasi.
class BurnRateCard extends StatelessWidget {
  const BurnRateCard({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BillProvider>();

    if (!provider.hasProfile) {
      return _SetupPrompt(onTap: () => showBurnRateEditor(context));
    }

    final r = provider.burnRate;
    final color = _statusColor(r.status);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, _darken(color)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.br,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.account_balance_wallet,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Batas Aman Harian',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _statusChip(r.status),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => showBurnRateEditor(context),
                icon: const Icon(Icons.edit, color: Colors.white70, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            r.status == BurnRateStatus.overbudget
                ? '- ${Formatters.rupiah(r.batasAmanHarian.abs())} / hari'
                : '${Formatters.rupiah(r.batasAmanHarian)} / hari',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _message(r),
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 14),

          // Progress alokasi tagihan terhadap pemasukan.
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: r.allocationRatio,
              minHeight: 8,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation(Colors.white),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _miniStat('Sisa Uang Bebas', Formatters.rupiah(r.freeCashFlow)),
              _miniStat(
                'Tagihan Wajib',
                Formatters.rupiah(r.totalTagihanWajib),
              ),
              _miniStat('Gajian', '${r.sisaHari} hari lagi'),
            ],
          ),
        ],
      ),
    );
  }

  String _message(BurnRateResult r) {
    switch (r.status) {
      case BurnRateStatus.aman:
        return 'Keuanganmu aman sampai ${Formatters.tanggal(r.nextPayday)}.';
      case BurnRateStatus.terbatas:
        return 'Hati-hati, anggaran harian cukup terbatas.';
      case BurnRateStatus.kritis:
        return 'Sisa uang harian sangat tipis. Kurangi belanja non-wajib.';
      case BurnRateStatus.overbudget:
        return 'Tagihan melebihi pemasukan. Tunda belanja non-wajib!';
    }
  }

  Widget _miniStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white60, fontSize: 10),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _statusChip(BurnRateStatus status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  static Color _statusColor(BurnRateStatus status) {
    switch (status) {
      case BurnRateStatus.aman:
        return AppColors.belanja; // hijau
      case BurnRateStatus.terbatas:
        return AppColors.warning; // kuning/oranye
      case BurnRateStatus.kritis:
      case BurnRateStatus.overbudget:
        return AppColors.danger; // merah
    }
  }

  static Color _darken(Color c) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness - 0.12).clamp(0.0, 1.0)).toColor();
  }
}

/// Kartu ajakan mengisi profil keuangan bila belum di-set.
class _SetupPrompt extends StatelessWidget {
  const _SetupPrompt({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: AppRadius.br,
        border: Border.all(color: const Color(0xFFE9ECEF)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.savings_outlined,
            color: AppColors.primary,
            size: 32,
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Aktifkan Budget Harian',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 2),
                Text(
                  'Isi pemasukan & tanggal gajian untuk melihat batas aman belanja per hari.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: onTap,
            icon: const Icon(Icons.arrow_forward),
          ),
        ],
      ),
    );
  }
}

/// Dialog untuk mengisi/mengubah pemasukan & tanggal gajian.
Future<void> showBurnRateEditor(BuildContext context) async {
  final provider = context.read<BillProvider>();
  final profile = provider.profile;

  final incomeCtrl = TextEditingController(
    text: profile.totalPemasukan > 0 ? formatAngka(profile.totalPemasukan) : '',
  );
  int payday = profile.tanggalGajian;
  final formKey = GlobalKey<FormState>();

  await showDialog<void>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          shape: AppRadius.shape,
          title: const Text('Profil Keuangan'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: incomeCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [RupiahInputFormatter()],
                  decoration: const InputDecoration(
                    labelText: 'Total Pemasukan / Bulan',
                    prefixText: 'Rp ',
                  ),
                  validator: (v) {
                    final n = parseRupiah(v);
                    if (n == null || n <= 0) {
                      return 'Masukkan nominal yang valid';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<int>(
                  initialValue: payday,
                  decoration: const InputDecoration(
                    labelText: 'Tanggal Gajian',
                  ),
                  items: List.generate(31, (i) => i + 1)
                      .map(
                        (n) => DropdownMenuItem(
                          value: n,
                          child: Text('Tanggal $n'),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setLocal(() => payday = v ?? 1),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                // Ditangkap sebelum await supaya tidak memakai context
                // setelah async gap.
                final messenger = ScaffoldMessenger.of(context);
                final navigator = Navigator.of(ctx);
                final ok = await provider.saveProfile(
                  UserProfile(
                    namaPanggilan: profile.namaPanggilan,
                    totalPemasukan: parseRupiah(incomeCtrl.text) ?? 0,
                    tanggalGajian: payday,
                  ),
                );
                if (ok) {
                  navigator.pop();
                } else {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(provider.lastError ?? 'Gagal menyimpan.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      );
    },
  );

  incomeCtrl.dispose();
}
