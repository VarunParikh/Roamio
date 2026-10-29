import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/core/location/location_service.dart';
import 'package:roamio/features/adventures/domain/adventure.dart';
import 'package:roamio/features/auth/domain/session.dart';
import 'package:roamio/features/splits/domain/money.dart';
import 'package:roamio/features/splits/domain/tab_models.dart';
import 'package:roamio/features/tabs/data/tab_service.dart';

import '../../support/fake_adventure_service.dart';
import '../../support/fake_auth_service.dart';
import '../../support/fake_share_files.dart';
import '../../support/fake_tab_service.dart';

final _goa = Adventure(
  id: 'bkk',
  name: 'Goa trip',
  countryCode: 'IN',
  startDate: DateTime(2026, 10, 20),
  endDate: DateTime(2026, 11, 2),
  baseCurrency: 'INR',
  leaderUid: 'ari',
  memberUids: const ['ari', 'mia'],
);

final _dinner = TabEntry(
  id: 't1',
  description: 'Dinner',
  category: 'food_dining',
  date: DateTime(2026, 10, 27),
  createdBy: 'ari',
  location: const MapPoint(15.55, 73.75),
  split: TabSplit(
    amount: Money(300000, 'INR'),
    payers: const [Payment('ari', 300000)],
    participants: const ['ari', 'mia'],
    fxDate: '2026-10-27',
  ),
);

Future<SharedFiles> _export(
  WidgetTester tester,
  String format, {
  String as = 'ari',
  String ageStatus = 'adult',
  bool enabled = true,
}) async {
  final shared = SharedFiles();
  await pumpRoamio(
    tester,
    FakeAuthService(
      initial: SessionFacts(uid: as, hasAccount: true, ageStatus: ageStatus),
    ),
    adventures: FakeAdventureService([_goa]),
    tabs: FakeTabService([_dinner]),
    sharedFiles: shared,
    exportEnabled: enabled,
  );
  await tester.tap(find.text('Split'));
  await tester.pumpAndSettle();
  if (!enabled) return shared;
  await tester.tap(find.text('Export'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(format));
  await tester.pumpAndSettle();
  return shared;
}

List<String> _tabHeader(List<int> bytes) => [
  for (final c in Excel.decodeBytes(bytes)['Tabs'].rows.first)
    c?.value?.toString() ?? '',
];

void main() {
  group('export (spec UC-27)', () {
    testWidgets('shares an Excel file of the split', (tester) async {
      final shared = await _export(tester, 'Excel (.xlsx)');
      final (name, mime, bytes) = shared.files.single;
      expect(name, 'Goa trip split.xlsx');
      expect(mime, contains('spreadsheetml'));
      expect(_tabHeader(bytes), contains('Location'));
    });

    testWidgets('shares a PDF', (tester) async {
      final shared = await _export(tester, 'PDF');
      final (name, mime, bytes) = shared.files.single;
      expect(name, 'Goa trip split.pdf');
      expect(mime, 'application/pdf');
      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    });

    testWidgets('a minor’s export leaves location out (spec §7.2)', (
      tester,
    ) async {
      final shared = await _export(
        tester,
        'Excel (.xlsx)',
        as: 'mia',
        ageStatus: 'minor_active',
      );
      expect(_tabHeader(shared.files.single.$3), isNot(contains('Location')));
    });

    testWidgets('hidden when export_enabled is off (spec §11)', (tester) async {
      await _export(tester, 'PDF', enabled: false);
      expect(find.text('Export'), findsNothing);
    });
  });
}
