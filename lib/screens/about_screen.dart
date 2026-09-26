import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';

/// Halaman 5: Tentang Aplikasi.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email ?? '-';
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        const Text('Tentang Aplikasi',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 18),
        Center(
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark],
              ),
              borderRadius: AppRadius.br,
            ),
            child: const Icon(Icons.notifications_active,
                color: Colors.white, size: 44),
          ),
        ),
        const SizedBox(height: 14),
        const Center(
          child: Text('Pengingat Tagihan',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        ),
        const Center(
          child: Text('Versi 1.0.0',
              style: TextStyle(color: AppColors.textMuted)),
        ),
        const SizedBox(height: 22),
        _card(
          'Deskripsi',
          'Aplikasi untuk menyimpan kumpulan tagihan sekaligus belanja yang '
              'rutin dilakukan setiap jangka waktu tertentu (tagihan aplikasi, '
              'gaya hidup, belanja bulanan, pajak, dan lainnya).',
        ),
        const SizedBox(height: 12),
        _card(
          'Untuk Siapa?',
          'Orang yang sering lupa terhadap pembayaran seperti tagihan, maupun '
              'kebutuhan sehari-hari yang sering digunakan. Cocok untuk hampir '
              'seluruh kalangan usia.',
        ),
        const SizedBox(height: 12),
        _featureCard(),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: AppRadius.br,
            border: Border.all(color: const Color(0xFFE9ECEF)),
          ),
          child: Row(
            children: [
              const Icon(Icons.account_circle_outlined,
                  color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Masuk sebagai',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textMuted)),
                    Text(email,
                        style:
                            const TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _confirmLogout(context),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.danger,
            side: const BorderSide(color: AppColors.danger),
          ),
          icon: const Icon(Icons.logout, size: 18),
          label: const Text('Keluar'),
        ),
      ],
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: AppRadius.shape,
        title: const Text('Keluar?'),
        content: const Text('Kamu perlu login lagi untuk mengakses datamu.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () {
              Navigator.pop(ctx);
              ctx.read<AuthService>().logout();
            },
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
  }

  Widget _card(String title, String body) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: AppRadius.br,
        border: Border.all(color: const Color(0xFFE9ECEF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 6),
          Text(body,
              style: const TextStyle(
                  color: AppColors.textMuted, height: 1.5, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _featureCard() {
    const features = [
      'Catat tagihan & belanja rutin',
      'Atur frekuensi pengulangan sendiri atau via preset',
      'Pengingat H-7, H-3, H-1 sebelum jatuh tempo',
      'Batas perulangan (contoh cicilan 12x)',
      'Tombol Lunasi & riwayat pembayaran',
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: AppRadius.br,
        border: Border.all(color: const Color(0xFFE9ECEF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Fitur Utama',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 10),
          ...features.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_circle,
                        size: 18, color: AppColors.belanja),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(f,
                          style: const TextStyle(fontSize: 13, height: 1.4)),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
