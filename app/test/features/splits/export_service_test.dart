import 'dart:convert';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/core/location/location_service.dart';
import 'package:roamio/features/adventures/domain/adventure.dart';
import 'package:roamio/features/splits/data/export_service.dart';
import 'package:roamio/features/splits/domain/fx_converter.dart';
import 'package:roamio/features/splits/domain/money.dart';
import 'package:roamio/features/splits/domain/split_report.dart';
import 'package:roamio/features/splits/domain/tab_models.dart';
import 'package:roamio/features/tabs/data/tab_service.dart';

final _goa = Adventure(
  id: 'goa',
  name: 'Goa trip',
  countryCode: 'IN',
  startDate: DateTime(2026, 10, 20),
  endDate: DateTime(2026, 11, 2),
  baseCurrency: 'INR',
  leaderUid: 'ari',
  memberUids: const ['ari', 'ben'],
);

/// Spec §6 worked example, with a location.
final _dinner = TabEntry(
  id: 't1',
  description: 'Dinner',
  category: 'food_dining',
  date: DateTime(2026, 10, 27),
  createdBy: 'ari',
  location: const MapPoint(15.55, 73.75),
  split: TabSplit(
    amount: Money(300000, 'INR'),
    payers: const [Payment('ari', 200000), Payment('ben', 100000)],
    participants: const ['ari', 'ben', 'kiko'],
    percentBp: const {'ari': 5000, 'ben': 2500, 'kiko': 2500},
    fxDate: '2026-10-27',
  ),
);

final _taxi = TabEntry(
  id: 't2',
  description: '',
  category: 'local_transportation',
  date: DateTime(2026, 10, 28),
  createdBy: 'ben',
  split: TabSplit(
    amount: Money(45050, 'INR'),
    payers: const [Payment('ben', 45050)],
    participants: const ['ari', 'ben'],
    fxDate: '2026-10-28',
  ),
);

ExportData _data({bool includeLocation = true}) {
  final tabs = [_dinner, _taxi];
  final report = buildReport(
    tabs: [
      for (final t in tabs)
        ReportTab(category: t.category, date: t.date, split: t.split),
    ],
    baseCurrency: 'INR',
    viewerCurrency: 'INR',
    viewer: 'ari',
    ratesFor: (d) => FxRates(date: d, usdRates: const {}),
  );
  return buildExportData(
    adventure: _goa,
    tabs: tabs,
    report: report,
    names: const {'ari': 'Ari Chen', 'ben': 'Ben Roy', 'kiko': 'Kiko'},
    categories: const {
      'food_dining': 'Food & Dining',
      'local_transportation': 'Local Transportation',
    },
    includeLocation: includeLocation,
  );
}

/// A spreadsheet number back in exact minor units (whole numbers read back
/// without decimals).
int _minor(String cell) => cell.startsWith('-')
    ? -parseAmount(cell.substring(1), 'INR')!
    : parseAmount(cell, 'INR')!;

/// The words the PDF draws, in order; it stores each as `[(word)]TJ`.
String _pdfText(List<int> bytes) =>
    RegExp(r'\[\((.*?)\)\]TJ')
        .allMatches(latin1.decode(bytes, allowInvalid: true))
        .map((m) => m.group(1))
        .join(' ');

List<List<String>> _rows(Excel excel, String sheet) => [
  for (final row in excel[sheet].rows)
    [for (final cell in row) cell?.value?.toString() ?? ''],
];

void main() {
  group('buildExportData (spec UC-27)', () {
    test('summary, transfers and every tab, in the trip currency', () {
      final d = _data();
      expect(d.currency, 'INR');
      expect(d.totalMinor, 345050);
      expect(d.balances, [
        ('Ari Chen', 27475),
        ('Ben Roy', 47525),
        ('Kiko', -75000),
      ]);
      expect(d.transfers, [
        ('Kiko', 'Ben Roy', 47525),
        ('Kiko', 'Ari Chen', 27475),
      ]);
      expect(d.tabs.first.paidBy, 'Ari Chen 2000.00, Ben Roy 1000.00');
      expect(d.tabs.first.sharedBy, 'Ari Chen 50%, Ben Roy 25%, Kiko 25%');
      expect(d.tabs.last.description, 'Local Transportation');
      expect(d.tabs.last.sharedBy, 'Ari Chen, Ben Roy (equal)');
      expect(d.tabs.first.location, '15.55, 73.75');
    });

    test('a minor’s export never includes location (spec §7.2)', () {
      final d = _data(includeLocation: false);
      expect(d.tabs.every((t) => t.location == null), isTrue);
    });
  });

  group('buildXlsx', () {
    test('opens with the right totals on each sheet', () {
      final excel = Excel.decodeBytes(buildXlsx(_data()));
      expect(
        excel.tables.keys,
        containsAll(['Summary', 'Who pays whom', 'Tabs']),
      );

      final summary = _rows(excel, 'Summary');
      expect(summary.first.first, 'Goa trip');
      expect(
        _minor(summary.where((r) => r.first == 'Total spend').single[1]),
        345050,
      );
      expect(_minor(summary.where((r) => r.first == 'Kiko').single[1]), -75000);

      final transfers = _rows(excel, 'Who pays whom');
      expect(transfers[1].sublist(0, 2), ['Kiko', 'Ben Roy']);
      expect(_minor(transfers[1][2]), 47525);

      final tabs = _rows(excel, 'Tabs');
      expect(tabs.first, contains('Location'));
      expect(tabs.length, 3); // header + 2 tabs
      expect(tabs[1].sublist(0, 3), ['2026-10-27', 'Dinner', 'Food & Dining']);
      expect(_minor(tabs[1][3]), 300000);
      expect(tabs[1][4], 'INR');
      // The amounts in the sheet add up to the total, to the paisa.
      final sum = tabs
          .skip(1)
          .map((r) => parseAmount(r[3], 'INR')!)
          .reduce((a, b) => a + b);
      expect(sum, 345050);
    });

    test('a minor’s spreadsheet has no Location column', () {
      final excel = Excel.decodeBytes(buildXlsx(_data(includeLocation: false)));
      expect(_rows(excel, 'Tabs').first, isNot(contains('Location')));
    });
  });

  group('buildPdf', () {
    test('is a PDF with the summary, transfers and tabs', () async {
      final bytes = await buildPdf(_data(), compress: false);
      expect(latin1.decode(bytes.sublist(0, 4)), '%PDF');
      final text = _pdfText(bytes);
      for (final s in [
        'Goa trip',
        'INR 3,450.50',
        'Kiko pays Ben Roy',
        'Dinner',
        '15.55, 73.75',
      ]) {
        expect(text, contains(s), reason: s);
      }
    });

    test('a minor’s PDF has no location', () async {
      final bytes = await buildPdf(
        _data(includeLocation: false),
        compress: false,
      );
      expect(
        latin1.decode(bytes, allowInvalid: true),
        isNot(contains('15.55')),
      );
    });
  });
}
