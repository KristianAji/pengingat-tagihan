import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/bill_provider.dart';
import '../theme/app_theme.dart';
import '../utils/emergency_cash.dart';
import '../utils/formatters.dart';
import 'app_choice_chip.dart';

/// Fitur 3: kartu Emergency Cash Reserve Calculator (Dana Darurat).
///
/// Versi yang tersambung ke [BillProvider]. Bagian tampilannya dipisah ke
/// [EmergencyCashCardView] supaya tata letaknya bisa diukur di widget test
/// tanpa perlu Firebase.
class EmergencyCashCard extends StatelessWidget {
  const EmergencyCashCard({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BillProvider>();
    return EmergencyCashCardView(
      result: provider.emergencyCash,
      selectedMonths: provider.emergencyMonths,
      onSelectMonths: provider.setEmergencyMonths,
    );
  }
}

/// Tampilan kartu Dana Darurat — murni dari data yang diberikan.
///
/// Sengaja TIDAK memakai gradien seperti kartu Burn-Rate: dua kartu berwarna
/// penuh yang ditumpuk membuat keduanya kehilangan penekanan. Kartu ini putih
/// dengan angka berwarna, jadi kartu utama di atasnya tetap menonjol.
class EmergencyCashCardView extends StatelessWidget {
  const EmergencyCashCardView({
    super.key,
    required this.result,
    required this.selectedMonths,
    required this.onSelectMonths,
  });

  final EmergencyCashResult result;
  final int selectedMonths;
  final ValueChanged<int> onSelectMonths;

  @override
  Widget build(BuildContext context) {
    final r = result;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: AppRadius.br,
        border: Border.all(color: const Color(0xFFE9ECEF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.shield_outlined,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Dana Darurat',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Siapkan minimal untuk ${r.months} bulan kebutuhan pokok.',
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),

          // Angka utama dibungkus FittedBox: dengan ukuran huruf sistem yang
          // diperbesar di layar sempit, nominal panjang bisa meluber kalau
          // dibiarkan — ini mengecilkannya, bukan memotongnya.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              Formatters.rupiah(r.target),
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryDark,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _caption(r),
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 14),

          // Pemilih rentang bulan.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: EmergencyCashCalculator.pilihanBulan
                .map(
                  (m) => AppChoiceChip(
                    label: '$m bulan',
                    selected: m == selectedMonths,
                    onTap: () => onSelectMonths(m),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 10),
          const Text(
            'Khusus item berlabel "wajib". Ubah di halaman Daftar.',
            style: TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  /// Keterangan di bawah nominal.
  String _caption(EmergencyCashResult r) {
    if (r.isEmpty) {
      return 'Belum ada item wajib. Tandai kebutuhan pokokmu lebih dulu.';
    }
    return '≈ ${Formatters.rupiah(r.monthlyMandatory)} / bulan '
        'dari ${r.itemCount} item wajib';
  }
}
