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
import 'package:roamio/features/tabs/domain/payment_method.dart';
import 'package:roamio/features/tabs/domain/tab_status.dart';

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
    payers: const [
      Payment('ari', 200000, method: PaymentMethod.bankTransfer),
      Payment('ben', 100000, method: PaymentMethod.cash),
    ],
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
    payers: const [Payment('ben', 45050)], // an older tab: no method
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
      expect(
        d.tabs.first.paidBy,
        'Ari Chen 2000.00 (Bank transfer), Ben Roy 1000.00 (Cash)',
      );
      expect(d.tabs.last.paidBy, 'Ben Roy 450.50 (Other)');
      expect(d.tabs.first.sharedBy, 'Ari Chen 50%, Ben Roy 25%, Kiko 25%');
      expect(d.tabs.last.description, 'Local Transportation');
      expect(d.tabs.last.sharedBy, 'Ari Chen, Ben Roy (equal)');
      expect(d.tabs.first.location, '15.55, 73.75');
    });

    test('only approved tabs are listed (spec UC-21a)', () {
      final waiting = TabEntry(
        id: 't3',
        description: 'Not yet',
        category: 'food_dining',
        date: DateTime(2026, 10, 27),
        createdBy: 'ben',
        status: TabStatus.waiting,
        split: _dinner.split,
      );
      final rejected = TabEntry(
        id: 't4',
        description: 'Refused',
        category: 'food_dining',
        date: DateTime(2026, 10, 27),
        createdBy: 'ben',
        status: TabStatus.rejected,
        split: _dinner.split,
      );
      final personal = TabEntry(
        id: 't5',
        description: 'Just me',
        category: 'food_dining',
        date: DateTime(2026, 10, 27),
        createdBy: 'ari',
        status: TabStatus.personal,
        split: _dinner.split,
      );
      final report = buildReport(
        tabs: const [],
        baseCurrency: 'INR',
        viewerCurrency: 'INR',
        viewer: 'ari',
        ratesFor: (date) => FxRates(date: date, usdRates: const {'INR': '84'}),
      );
      final data = buildExportData(
        adventure: _goa,
        tabs: [_dinner, waiting, rejected, personal],
        report: report,
        names: const {},
        categories: const {},
        includeLocation: true,
      );
      expect(data.tabs.map((t) => t.description), ['Dinner']);
    });

    test('a minor’s export never includes location (spec §7.2)', () {
      final d = _data(includeLocation: false);
      expect(d.tabs.every((t) => t.location == null), isTrue);
    });
  });

  group('buildXlsx', () {
    test(
      'the largest amounts come out exact, to the paisa (follow-up C13)',
      () {
        // Spreadsheet cells are always binary numbers; check the one
        // conversion at the edge of the file loses nothing, even at the top.
        final biggest = maxTabMinor('INR') - 1; // ₹99,99,999.99
        final tab = TabEntry(
          id: 'big',
          description: 'Villa',
          category: 'food_dining',
          date: DateTime(2026, 10, 27),
          createdBy: 'ari',
          split: TabSplit(
            amount: Money(biggest, 'INR'),
            payers: [Payment('ari', biggest)],
            participants: const ['ari', 'ben', 'kiko'],
            fxDate: '2026-10-27',
          ),
        );
        final report = buildReport(
          tabs: [
            ReportTab(category: tab.category, date: tab.date, split: tab.split),
          ],
          baseCurrency: 'INR',
          viewerCurrency: 'INR',
          viewer: 'ari',
          ratesFor: (d) => FxRates(date: d, usdRates: const {}),
        );
        final excel = Excel.decodeBytes(
          buildXlsx(
            buildExportData(
              adventure: _goa,
              tabs: [tab],
              report: report,
              names: const {
                'ari': 'Ari Chen',
                'ben': 'Ben Roy',
                'kiko': 'Kiko',
              },
              categories: const {'food_dining': 'Food & Dining'},
              includeLocation: false,
            ),
          ),
        );
        final summary = _rows(excel, 'Summary');
        expect(
          _minor(summary.where((r) => r.first == 'Total spend').single[1]),
          biggest,
        );
        expect(_minor(_rows(excel, 'Tabs')[1][3]), biggest);
        // Ari paid it all and owes a third: 666666666 paise, exactly.
        expect(
          _minor(summary.where((r) => r.first == 'Ari Chen').single[1]),
          666666666,
        );
      },
    );

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

    test('Paid by shows how they paid by name, never the emoji', () {
      final excel = Excel.decodeBytes(buildXlsx(_data()));
      final tabs = _rows(excel, 'Tabs');
      final paidBy = tabs.first.indexOf('Paid by');
      expect(
        tabs[1][paidBy],
        'Ari Chen 2000.00 (Bank transfer), Ben Roy 1000.00 (Cash)',
      );
      expect(tabs[2][paidBy], 'Ben Roy 450.50 (Other)');
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

    test('Paid by shows how they paid by name', () async {
      final bytes = await buildPdf(_data(), compress: false);
      final text = _pdfText(bytes);
      for (final s in ['Bank', 'transfer', 'Cash', 'Other']) {
        expect(text, contains(s), reason: s);
      }
      // The PDF's built-in font has no emoji.
      for (final m in PaymentMethod.values) {
        expect(latin1.decode(bytes), isNot(contains(m.emoji)));
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
