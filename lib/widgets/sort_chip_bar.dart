import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/bill_sort.dart';
import 'app_choice_chip.dart';

/// Bilah chip untuk memilih sudut pandang pengurutan di halaman Daftar.
///
/// Sengaja memakai [Wrap], bukan [Row]: label "Frekuensi Pengingat" panjang
/// dan bertambah ikon panah saat aktif, jadi harus bisa turun ke baris
/// berikutnya alih-alih meluber di layar sempit.
class SortChipBar extends StatelessWidget {
  const SortChipBar({
    super.key,
    required this.mode,
    required this.ascending,
    required this.onSelect,
  });

  /// Mode yang sedang aktif.
  final BillSortMode mode;

  /// Arah urutan yang sedang aktif; hanya ditampilkan pada chip yang aktif.
  final bool ascending;

  final ValueChanged<BillSortMode> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Urutkan:',
          style: TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: BillSortMode.values.map((m) {
            final active = m == mode;
            return AppChoiceChip(
              label: m.label,
              selected: active,
              onTap: () => onSelect(m),
              // Panah hanya muncul di chip yang aktif, jadi arah urutan
              // selalu terbaca tanpa perlu teks tambahan.
              trailing: active
                  ? Icon(
                      ascending ? Icons.arrow_upward : Icons.arrow_downward,
                      size: 14,
                      color: Colors.white,
                    )
                  : null,
            );
          }).toList(),
        ),
      ],
    );
  }
}
