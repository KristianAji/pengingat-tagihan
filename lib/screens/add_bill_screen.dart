import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/bill.dart';
import '../providers/bill_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/rupiah_input.dart';

/// Preset perulangan (Opsi B).
class _RepeatPreset {
  final String label;
  final int every;
  final RepeatUnit unit;
  const _RepeatPreset(this.label, this.every, this.unit);
}

const _presets = [
  _RepeatPreset('1 Minggu Sekali', 1, RepeatUnit.minggu),
  _RepeatPreset('2 Minggu Sekali', 2, RepeatUnit.minggu),
  _RepeatPreset('1 Bulan Sekali', 1, RepeatUnit.bulan),
  _RepeatPreset('3 Bulan Sekali', 3, RepeatUnit.bulan),
  _RepeatPreset('6 Bulan Sekali', 6, RepeatUnit.bulan),
  _RepeatPreset('1 Tahun Sekali', 12, RepeatUnit.bulan),
];

/// Batas maksimum karakter nama (spesifikasi: 15-20). Dipakai 20.
const int kMaxNameLength = 20;

/// Halaman 3: Menambahkan daftar baru.
class AddBillScreen extends StatefulWidget {
  const AddBillScreen({super.key});

  @override
  State<AddBillScreen> createState() => _AddBillScreenState();
}

class _AddBillScreenState extends State<AddBillScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  final _paymentCtrl = TextEditingController();
  final _limitCtrl = TextEditingController();

  BillType _type = BillType.tagihan;
  bool _useCustomRepeat = false; // false = Pilih Preset, true = Atur Sendiri
  int _customEvery = 1;
  RepeatUnit _customUnit = RepeatUnit.bulan;
  int _presetIndex = 2;
  final Set<int> _offsets = {7, 3, 1};
  bool _hasLimit = false;
  bool _saving = false;

  /// Penanda kebutuhan pokok (dasar perhitungan Dana Darurat).
  ///
  /// Bawaannya mengikuti jenis: Tagihan = wajib, Belanja = tidak. Begitu
  /// pengguna mengubahnya sendiri, [\_mandatoryTouched] menahan agar pilihan
  /// itu tidak ikut tertimpa saat jenisnya diganti.
  bool _isMandatory = true;
  bool _mandatoryTouched = false;

  /// "Ingatkan Pada": tanggal (1-31) & bulan pengingat. Tahunnya diambil
  /// otomatis dari kemunculan terdekat.
  int? _reminderDay;
  int? _reminderMonth;

  /// Tanggal jatuh tempo hasil pilihan "Ingatkan Pada".
  ///
  /// Karena tahun tidak dipilih, tahun diambil dari kemunculan terdekat:
  /// tahun ini bila tanggalnya belum lewat, kalau sudah lewat tahun depan.
  DateTime? get _dueDate {
    final day = _reminderDay;
    final month = _reminderMonth;
    if (day == null || month == null) return null;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final thisYear = Bill.dateInMonth(now.year, month, day);
    if (thisYear.isBefore(today)) {
      return Bill.dateInMonth(now.year + 1, month, day);
    }
    return thisYear;
  }

  Future<void> _save() async {
    if (_saving) return; // cegah dobel-submit selagi penyimpanan berjalan
    if (!_formKey.currentState!.validate()) return;
    final dueDate = _dueDate;
    if (dueDate == null) {
      _showSnack('Silakan pilih tanggal & bulan pada "Ingatkan Pada"');
      return;
    }
    if (_offsets.isEmpty) {
      _showSnack('Pilih minimal satu waktu pengingat (H-7/H-3/H-1)');
      return;
    }

    final every = _useCustomRepeat
        ? _customEvery
        : _presets[_presetIndex].every;
    final unit = _useCustomRepeat ? _customUnit : _presets[_presetIndex].unit;
    final limit = _hasLimit ? int.tryParse(_limitCtrl.text) : null;
    final offsets = _offsets.toList()..sort((a, b) => b.compareTo(a));

    final bill = Bill(
      id: '${DateTime.now().microsecondsSinceEpoch}',
      name: _nameCtrl.text.trim(),
      type: _type,
      repeatEvery: every,
      repeatUnit: unit,
      dueDate: dueDate,
      reminderOffsets: offsets,
      estimatedCost: parseRupiah(_costCtrl.text) ?? 0,
      paymentMethod: _paymentCtrl.text.trim(),
      repeatLimit: limit,
      remaining: limit,
      createdAt: DateTime.now(),
      isMandatory: _isMandatory,
    );

    // Ditangkap sebelum await supaya tidak memakai context setelah async gap.
    final provider = context.read<BillProvider>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _saving = true);
    final ok = await provider.addBill(bill);
    if (!mounted) return;
    setState(() => _saving = false);

    if (!ok) {
      // Form sengaja dibiarkan terbuka supaya isian tidak hilang saat gagal.
      messenger.showSnackBar(
        SnackBar(
          content: Text(provider.lastError ?? 'Gagal menyimpan. Coba lagi.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    navigator.pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text('"${bill.name}" berhasil ditambahkan'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Tambah Daftar Baru',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          // Keyboard ditutup begitu form digeser. Kalau kolom "Nama Daftar"
          // dibiarkan tetap fokus, Flutter menggeser daftar kembali ke kolom
          // itu setiap kali pilihan di bawahnya ditutup.
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _label('Nama Daftar'),
            TextFormField(
              controller: _nameCtrl,
              maxLength: kMaxNameLength,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                hintText: 'Contoh: Stok Skincare',
                counterText: '',
                prefixIcon: Icon(Icons.edit_note),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Nama wajib diisi' : null,
            ),
            _charCounter(),
            const SizedBox(height: 16),
            _label('Jenis'),
            _typeSelector(),
            const SizedBox(height: 16),
            _mandatorySection(),
            const SizedBox(height: 16),
            _label('Diulang Setiap'),
            _repeatSection(),
            const SizedBox(height: 16),
            _label('Ingatkan Pada'),
            _reminderSection(),
            const SizedBox(height: 16),
            _label('Ingatkan Sebelum Hari-H'),
            _offsetSelector(),
            const SizedBox(height: 16),
            _label('Estimasi Biaya'),
            TextFormField(
              controller: _costCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [RupiahInputFormatter()],
              decoration: const InputDecoration(
                hintText: '0',
                prefixText: 'Rp ',
                prefixIcon: Icon(Icons.payments_outlined),
              ),
              validator: (v) => (v == null || v.isEmpty)
                  ? 'Estimasi biaya wajib diisi'
                  : null,
            ),
            const SizedBox(height: 16),
            _label('Metode Pembayaran'),
            TextFormField(
              controller: _paymentCtrl,
              decoration: const InputDecoration(
                hintText: 'Contoh: Dana, OVO, Transfer BCA',
                prefixIcon: Icon(Icons.account_balance_wallet_outlined),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Metode pembayaran wajib diisi'
                  : null,
            ),
            const SizedBox(height: 16),
            _limitSection(),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check),
                label: Text(_saving ? 'Menyimpan...' : 'Simpan Daftar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      t,
      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
    ),
  );

  Widget _charCounter() => Align(
    alignment: Alignment.centerRight,
    child: AnimatedBuilder(
      animation: _nameCtrl,
      builder: (context, _) => Text(
        '${_nameCtrl.text.length}/$kMaxNameLength',
        style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
      ),
    ),
  );

  Widget _typeSelector() {
    return Row(
      children: BillType.values.map((t) {
        final selected = _type == t;
        final color = AppColors.forType(t == BillType.tagihan);
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: t == BillType.tagihan ? 10 : 0),
            child: GestureDetector(
              onTap: () => setState(() {
                _type = t;
                // Ikutkan bawaan penanda wajib ke jenis yang baru dipilih,
                // kecuali pengguna sudah menentukan sendiri.
                if (!_mandatoryTouched) {
                  _isMandatory = t == BillType.tagihan;
                }
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected
                      ? color.withValues(alpha: 0.12)
                      : AppColors.card,
                  borderRadius: AppRadius.br,
                  border: Border.all(
                    color: selected ? color : const Color(0xFFE9ECEF),
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  t.label,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: selected ? color : AppColors.textMuted,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  /// Penanda kebutuhan pokok — dipakai kartu Dana Darurat & Burn-Rate.
  Widget _mandatorySection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: AppRadius.br,
        border: Border.all(color: const Color(0xFFE9ECEF)),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Masuk Kebutuhan Pokok',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  'Dihitung sebagai tagihan wajib di kartu Dana Darurat.',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          Switch(
            value: _isMandatory,
            activeThumbColor: AppColors.primary,
            onChanged: (v) => setState(() {
              _isMandatory = v;
              _mandatoryTouched = true;
            }),
          ),
        ],
      ),
    );
  }

  Widget _repeatSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: AppRadius.br,
        border: Border.all(color: const Color(0xFFE9ECEF)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _repeatTab(
                'Pilih Preset',
                !_useCustomRepeat,
                () => setState(() => _useCustomRepeat = false),
              ),
              const SizedBox(width: 8),
              _repeatTab(
                'Atur Sendiri',
                _useCustomRepeat,
                () => setState(() => _useCustomRepeat = true),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _useCustomRepeat ? _customRepeatRow() : _presetGrid(),
        ],
      ),
    );
  }

  Widget _repeatTab(String label, bool selected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.surface,
            borderRadius: AppRadius.br,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }

  Widget _customRepeatRow() {
    final max = _customUnit == RepeatUnit.hari ? 30 : 12;
    if (_customEvery > max) _customEvery = max;
    return Row(
      children: [
        const Text('Setiap', style: TextStyle(color: AppColors.textMuted)),
        const SizedBox(width: 10),
        Expanded(
          child: DropdownButtonFormField<int>(
            initialValue: _customEvery,
            isExpanded: true,
            decoration: const InputDecoration(
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: List.generate(max, (i) => i + 1)
                .map((n) => DropdownMenuItem(value: n, child: Text('$n')))
                .toList(),
            onChanged: (v) => setState(() => _customEvery = v ?? 1),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: DropdownButtonFormField<RepeatUnit>(
            initialValue: _customUnit,
            isExpanded: true,
            decoration: const InputDecoration(
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: RepeatUnit.values
                .map((u) => DropdownMenuItem(value: u, child: Text(u.label)))
                .toList(),
            onChanged: (v) =>
                setState(() => _customUnit = v ?? RepeatUnit.bulan),
          ),
        ),
        const SizedBox(width: 6),
        const Text('sekali', style: TextStyle(color: AppColors.textMuted)),
      ],
    );
  }

  Widget _presetGrid() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(_presets.length, (i) {
        final selected = _presetIndex == i;
        return GestureDetector(
          onTap: () => setState(() => _presetIndex = i),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? AppColors.primary : AppColors.surface,
              borderRadius: AppRadius.br,
            ),
            child: Text(
              _presets[i].label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.textDark,
              ),
            ),
          ),
        );
      }),
    );
  }

  /// "Ingatkan Pada": pilih tanggal (1-31) & bulan — tanpa tahun.
  Widget _reminderSection() {
    final due = _dueDate;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                initialValue: _reminderDay,
                isExpanded: true,
                hint: const Text('Pilih tanggal'),
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                items: List.generate(31, (i) => i + 1)
                    .map(
                      (d) =>
                          DropdownMenuItem(value: d, child: Text('Tanggal $d')),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _reminderDay = v),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<int>(
                initialValue: _reminderMonth,
                isExpanded: true,
                hint: const Text('Pilih bulan'),
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                items: List.generate(12, (i) => i + 1)
                    .map(
                      (m) => DropdownMenuItem(
                        value: m,
                        child: Text(Formatters.namaBulan(m)),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _reminderMonth = v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (due == null)
          const Padding(
            padding: EdgeInsets.only(left: 4),
            child: Text(
              'Pilih tanggal & bulan pengingat',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          )
        else
          _reminderSummary(due),
      ],
    );
  }

  Widget _reminderSummary(DateTime due) {
    final day = _reminderDay!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.10),
        borderRadius: AppRadius.br,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.event_repeat, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Setiap Tanggal $day',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Pengingat pertama: ${Formatters.tanggal(due)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
                if (day > 28) ...[
                  const SizedBox(height: 2),
                  const Text(
                    'Di bulan yang lebih pendek, pengingat jatuh pada tanggal '
                    'terakhir bulan itu.',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Tombol H-7/H-3/H-1: biru penuh saat dipilih, putih saat tidak.
  Widget _offsetSelector() {
    return Wrap(
      spacing: 8,
      children: [7, 3, 1].map((d) {
        final selected = _offsets.contains(d);
        return GestureDetector(
          onTap: () =>
              setState(() => selected ? _offsets.remove(d) : _offsets.add(d)),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: selected ? AppColors.primary : AppColors.card,
              borderRadius: AppRadius.br,
              border: Border.all(
                color: selected ? AppColors.primary : const Color(0xFFE9ECEF),
              ),
            ),
            child: Text(
              'H-$d',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : AppColors.textMuted,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _limitSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: AppRadius.br,
        border: Border.all(color: const Color(0xFFE9ECEF)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Batas Perulangan',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      'Contoh: cicilan motor 12x, terhapus saat lunas semua',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _hasLimit,
                activeThumbColor: AppColors.primary,
                onChanged: (v) => setState(() => _hasLimit = v),
              ),
            ],
          ),
          if (_hasLimit) ...[
            const SizedBox(height: 8),
            TextFormField(
              controller: _limitCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                hintText: 'Jumlah perulangan, contoh: 12',
                suffixText: 'kali',
              ),
              validator: (v) {
                if (!_hasLimit) return null;
                final n = int.tryParse(v ?? '');
                if (n == null || n < 1) return 'Masukkan jumlah yang valid';
                return null;
              },
            ),
          ],
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _costCtrl.dispose();
    _paymentCtrl.dispose();
    _limitCtrl.dispose();
    super.dispose();
  }
}
