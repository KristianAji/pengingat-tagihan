import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user_profile.dart';
import '../providers/bill_provider.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/profile_display.dart';
import '../widgets/burn_rate_card.dart';
import 'about_screen.dart';

/// Halaman 5: Profil akun.
///
/// Menggantikan tab Tentang Aplikasi di navigasi bawah. Isi Tentang dipindah
/// menjadi menu di sini supaya pengaturan akun (nama panggilan, password,
/// data keuangan, keluar) berada di satu tempat.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BillProvider>();
    final user = FirebaseAuth.instance.currentUser;
    final profile = provider.profile;
    final email = user?.email ?? '-';
    final nama = displayNameFor(profile.namaPanggilan, user?.email);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        const Text(
          'Profil Akun',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 18),
        _header(nama, email),
        const SizedBox(height: 22),

        _sectionTitle('Akun'),
        const SizedBox(height: 10),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(
                  Icons.badge_outlined,
                  color: AppColors.primary,
                ),
                title: const Text('Nama Panggilan'),
                subtitle: Text(nama),
                trailing: const Icon(Icons.edit_outlined, size: 20),
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (_) => _NicknameDialog(profile: profile),
                ),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(
                  Icons.email_outlined,
                  color: AppColors.primary,
                ),
                title: const Text('Email'),
                subtitle: Text(email),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(
                  Icons.lock_outline,
                  color: AppColors.primary,
                ),
                title: const Text('Ubah Password'),
                subtitle: const Text('Ganti kata sandi akun'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (_) => const _PasswordDialog(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),

        _sectionTitle('Keuangan'),
        const SizedBox(height: 10),
        Card(
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            leading: const Icon(
              Icons.account_balance_wallet_outlined,
              color: AppColors.primary,
            ),
            title: const Text('Pemasukan & Tanggal Gajian'),
            subtitle: Text(
              profile.isSet
                  ? '${Formatters.rupiah(profile.totalPemasukan)} / bulan '
                        '• Gajian tgl ${profile.tanggalGajian}'
                  : 'Belum diisi. Ketuk untuk mengatur',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showBurnRateEditor(context),
          ),
        ),
        const SizedBox(height: 22),

        _sectionTitle('Lainnya'),
        const SizedBox(height: 10),
        Card(
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            leading: const Icon(Icons.info_outline, color: AppColors.primary),
            title: const Text('Tentang Aplikasi'),
            subtitle: const Text('Deskripsi & fitur utama'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const AboutScreen())),
          ),
        ),
        const SizedBox(height: 22),

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

  Widget _header(String nama, String email) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: AppRadius.br,
        border: Border.all(color: const Color(0xFFE9ECEF)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.primary,
            child: Text(
              initialsFor(nama),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nama,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  email,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String t) => Text(
    t,
    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
  );

  void _confirmLogout(BuildContext context) {
    showDialog<void>(
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
            onPressed: () async {
              // Ditangkap sebelum await; ctx milik dialog tidak dipakai lagi.
              final auth = ctx.read<AuthService>();
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(ctx);
              try {
                await auth.logout();
              } catch (_) {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Gagal keluar. Coba lagi.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
  }
}

/// Dialog untuk mengubah nama panggilan di dokumen `users/{uid}`.
class _NicknameDialog extends StatefulWidget {
  const _NicknameDialog({required this.profile});

  final UserProfile profile;

  @override
  State<_NicknameDialog> createState() => _NicknameDialogState();
}

class _NicknameDialogState extends State<_NicknameDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _ctrl = TextEditingController(
    text: widget.profile.namaPanggilan,
  );
  bool _saving = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    // Ditangkap sebelum await supaya tidak memakai context setelah async gap.
    final provider = context.read<BillProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final ok = await provider.saveProfile(
      widget.profile.copyWith(namaPanggilan: _ctrl.text.trim()),
    );
    if (!mounted) return;

    if (ok) {
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Nama panggilan diperbarui.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      setState(() => _saving = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(provider.lastError ?? 'Gagal menyimpan.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: AppRadius.shape,
      title: const Text('Nama Panggilan'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: TextFormField(
            controller: _ctrl,
            autofocus: true,
            maxLength: 30,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nama Panggilan',
              counterText: '',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Nama panggilan tidak boleh kosong'
                : null,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Simpan'),
        ),
      ],
    );
  }
}

/// Dialog ganti password. Password lama dipakai untuk autentikasi ulang.
class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog();

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _lama = TextEditingController();
  final _baru = TextEditingController();
  final _ulang = TextEditingController();
  bool _obscure = true;
  bool _saving = false;

  @override
  void dispose() {
    _lama.dispose();
    _baru.dispose();
    _ulang.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final auth = context.read<AuthService>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      await auth.changePassword(
        currentPassword: _lama.text,
        newPassword: _baru.text,
      );
      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Password berhasil diubah.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(AuthService.messageFromCode(e.code)),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Gagal mengubah password. Coba lagi.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: AppRadius.shape,
      title: const Text('Ubah Password'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _lama,
                obscureText: _obscure,
                decoration: const InputDecoration(
                  labelText: 'Password Saat Ini',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                validator: (v) => (v == null || v.isEmpty)
                    ? 'Masukkan password saat ini'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _baru,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: 'Password Baru',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    tooltip: _obscure ? 'Tampilkan' : 'Sembunyikan',
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: (v) => (v == null || v.length < 6)
                    ? 'Password minimal 6 karakter'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _ulang,
                obscureText: _obscure,
                decoration: const InputDecoration(
                  labelText: 'Ulangi Password Baru',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                validator: (v) =>
                    (v != _baru.text) ? 'Password tidak sama' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Simpan'),
        ),
      ],
    );
  }
}
