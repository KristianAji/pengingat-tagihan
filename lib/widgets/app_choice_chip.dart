import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Chip pilihan bergaya aplikasi — dipakai bilah sortir halaman Daftar.
///
/// Gayanya sama dengan tombol H-7/H-3/H-1 di halaman Tambah: biru penuh saat
/// terpilih, putih bergaris saat tidak.
class AppChoiceChip extends StatelessWidget {
  const AppChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.trailing,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Ikon kecil di kanan label — dipakai untuk panah arah urutan.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.card,
          borderRadius: AppRadius.br,
          border: Border.all(
            color: selected ? AppColors.primary : const Color(0xFFE9ECEF),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : AppColors.textMuted,
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 4),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}
