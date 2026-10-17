import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_logo.dart';

/// Halaman Tentang Aplikasi.
///
/// Dibuka dari menu "Tentang Aplikasi" di halaman Profil, bukan lagi tab
/// tersendiri di navigasi bawah.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tentang Aplikasi')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            // Logo aplikasi tanpa kotak latar — samakan dengan halaman Login.
            const Center(child: AppLogo()),
            const SizedBox(height: 14),
            const Center(
              child: Text(
                'Pengingat Tagihan',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
            const Center(
              child: Text(
                'Versi 1.0.0',
                style: TextStyle(color: AppColors.textMuted),
              ),
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
          ],
        ),
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
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: const TextStyle(
              color: AppColors.textMuted,
              height: 1.5,
              fontSize: 13,
            ),
          ),
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
          const Text(
            'Fitur Utama',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
          const SizedBox(height: 10),
          ...features.map(
            (f) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_circle,
                    size: 18,
                    color: AppColors.belanja,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      f,
                      style: const TextStyle(fontSize: 13, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
