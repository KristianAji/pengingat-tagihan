import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pengingat_tagihan/models/bill.dart';
import 'package:pengingat_tagihan/theme/app_theme.dart';
import 'package:pengingat_tagihan/widgets/expandable_bill_card.dart';

Bill _bill({bool isMandatory = true}) => Bill(
  id: 'a',
  name: 'Kos',
  type: BillType.tagihan,
  repeatEvery: 1,
  repeatUnit: RepeatUnit.bulan,
  dueDate: DateTime(2026, 1, 10),
  reminderOffsets: const [7, 3, 1],
  estimatedCost: 1000000,
  paymentMethod: 'Transfer BCA',
  createdAt: DateTime(2026, 1, 1),
  isMandatory: isMandatory,
);

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.light,
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  // Kartu ini dibungkus GestureDetector yang melipat/membuka kartu. Switch di
  // dalamnya harus memenangkan tap-nya sendiri — kalau tidak, setiap kali
  // penanda diubah kartunya ikut terlipat dan pengguna kehilangan konteksnya.
  testWidgets('tap Switch mengubah penanda tanpa melipat kartu', (
    tester,
  ) async {
    var toggleMandatory = 0;
    var toggleCard = 0;

    await tester.pumpWidget(
      _wrap(
        ExpandableBillCard(
          bill: _bill(),
          expanded: true,
          onToggle: () => toggleCard++,
          onPay: () {},
          onDelete: () {},
          onToggleMandatory: () => toggleMandatory++,
        ),
      ),
    );

    await tester.tap(find.byType(Switch));

    expect(toggleMandatory, 1);
    expect(toggleCard, 0);
  });

  testWidgets('detail menyebut apakah item dihitung di Dana Darurat', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        ExpandableBillCard(
          bill: _bill(isMandatory: false),
          expanded: true,
          onToggle: () {},
          onPay: () {},
          onDelete: () {},
          onToggleMandatory: () {},
        ),
      ),
    );

    expect(find.text('Kebutuhan Pokok'), findsOneWidget);
    expect(find.text('Tidak dihitung'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
  });

  testWidgets('tap di luar Switch tetap melipat kartu', (tester) async {
    var toggleCard = 0;

    await tester.pumpWidget(
      _wrap(
        ExpandableBillCard(
          bill: _bill(),
          expanded: true,
          onToggle: () => toggleCard++,
          onPay: () {},
          onDelete: () {},
          onToggleMandatory: () {},
        ),
      ),
    );

    await tester.tap(find.text('Kos'));
    expect(toggleCard, 1);
  });
}
