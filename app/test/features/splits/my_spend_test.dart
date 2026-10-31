import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/features/splits/domain/fx_converter.dart';
import 'package:roamio/features/splits/domain/money.dart';
import 'package:roamio/features/splits/domain/split_report.dart';
import 'package:roamio/features/splits/domain/tab_models.dart';
import 'package:roamio/features/tabs/domain/tab_status.dart';

ReportTab _tab(
  String category,
  int minor,
  int day,
  List<String> among, {
  TabStatus status = TabStatus.approved,
  String payer = 'ari',
}) => ReportTab(
  category: category,
  date: DateTime(2026, 10, day),
  status: status,
  split: TabSplit(
    amount: Money(minor, 'INR'),
    payers: [Payment(payer, minor)],
    participants: among,
    fxDate: '2026-10-27',
  ),
);

SplitReport _report(List<ReportTab> tabs) => buildReport(
  tabs: tabs,
  baseCurrency: 'INR',
  viewerCurrency: 'INR',
  viewer: 'ari',
  ratesFor: (date) => FxRates(date: date, usdRates: const {}),
);

void main() {
  group('the viewer’s own spend, for their own charts', () {
    test('personal tabs count for the viewer, not the squad', () {
      final r = _report([
        _tab('food', 50000, 27, ['ari'], status: TabStatus.personal),
      ]);
      expect(r.totalSpend, 0);
      expect(r.byCategory, isEmpty);
      expect(r.myByCategory, {'food': 50000});
      expect(r.myByDay, {DateTime(2026, 10, 27): 50000});
    });

    test('shared tabs count at the viewer’s share', () {
      final r = _report([
        _tab('stay', 100001, 26, ['ari', 'ben']),
        _tab('food', 50000, 27, ['ari'], status: TabStatus.personal),
      ]);
      expect(r.myByCategory['stay'], 50001);
      expect(r.myByCategory['food'], 50000);
      expect(r.myByDay[DateTime(2026, 10, 26)], 50001);
    });

    test('they add up to the spent-by-you figure, to the unit', () {
      final r = _report([
        _tab('stay', 100000, 26, ['ari', 'ben', 'cara']),
        _tab('food', 33333, 27, ['ari', 'ben', 'cara'], payer: 'ben'),
        _tab('shop', 7, 28, ['ari'], status: TabStatus.personal),
      ]);
      expect(r.myByCategory.values.reduce((a, b) => a + b), r.myShare);
      expect(r.myByDay.values.reduce((a, b) => a + b), r.myShare);
    });

    test('someone else’s share and waiting tabs stay out', () {
      final r = _report([
        _tab('stay', 100000, 26, ['ben', 'cara'], payer: 'ben'),
        _tab('food', 50000, 27, ['ari', 'ben'], status: TabStatus.waiting),
      ]);
      expect(r.myByCategory, isEmpty);
      expect(r.myByDay, isEmpty);
    });
  });
}
