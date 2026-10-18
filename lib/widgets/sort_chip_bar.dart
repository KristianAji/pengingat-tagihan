import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/bill_sort.dart';

/// Pemilih urutan di halaman Daftar: dropdown untuk memilih sudut pandang,
/// ditambah tombol panah untuk membalik arah urutan.
class SortChipBar extends StatelessWidget {
  const SortChipBar({
    super.key,
    required this.mode,
    required this.ascending,
    required this.onSelect,
  });

  /// Mode yang sedang aktif.
  final BillSortMode mode;

  /// Arah urutan yang sedang aktif.
  final bool ascending;

  final ValueChanged<BillSortMode> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text(
          'Urutkan:',
          style: TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.br,
              border: Border.all(color: const Color(0xFFE9ECEF)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<BillSortMode>(
                value: mode,
                isExpanded: true,
                borderRadius: AppRadius.br,
                dropdownColor: Colors.white,
                icon: const Icon(Icons.keyboard_arrow_down),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
                items: BillSortMode.values
                    .map(
                      (m) => DropdownMenuItem<BillSortMode>(
                        value: m,
                        child: Text(m.label),
                      ),
                    )
                    .toList(),
                onChanged: (m) {
                  // Dropdown tetap memanggil onChanged walau item yang sama
                  // dipilih ulang. Tanpa penjagaan ini, arah urutan akan
                  // ikut terbalik (lihat nextSortState).
                  if (m != null && m != mode) onSelect(m);
                },
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Mengetuk mode yang sedang aktif = membalik arah urutan.
        Tooltip(
          message: ascending ? 'Urutan naik' : 'Urutan turun',
          child: InkWell(
            borderRadius: AppRadius.br,
            onTap: () => onSelect(mode),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadius.br,
                border: Border.all(color: const Color(0xFFE9ECEF)),
              ),
              child: Icon(
                ascending ? Icons.arrow_upward : Icons.arrow_downward,
                size: 20,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
