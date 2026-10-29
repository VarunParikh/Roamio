import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:roamio/features/adventures/domain/adventure.dart';
import 'package:roamio/features/adventures/ui/adventure_format.dart';
import 'package:roamio/features/auth/domain/age.dart';
import 'package:roamio/features/splits/domain/money.dart';
import 'package:roamio/features/splits/domain/split_report.dart';
import 'package:roamio/features/tabs/data/tab_service.dart';
import 'package:roamio/features/tabs/domain/new_tab.dart';
import 'package:roamio/features/tabs/domain/tab_list.dart';

/// One tab as a line of the export.
class ExportTab {
  const new({
    required this.date,
    required this.description,
    required this.category,
    required this.amountMinor,
    required this.currency,
    required this.paidBy,
    required this.sharedBy,
    this.location,
  });

  final String date;
  final String description;
  final String category;
  final int amountMinor;
  final String currency;
  final String paidBy;
  final String sharedBy;

  /// "lat, lng"; always null in a minor's export (spec §7.2).
  final String? location;
}

/// Everything an adventure's export holds (spec UC-27), with amounts in
/// the trip's currency so it reads the same for whoever receives it.
class ExportData {
  const new({
    required this.title,
    required this.dates,
    required this.currency,
    required this.totalMinor,
    required this.balances,
    required this.transfers,
    required this.tabs,
    required this.includeLocation,
  });

  final String title;
  final String dates;
  final String currency;
  final int totalMinor;
  final List<(String, int)> balances;
  final List<(String, String, int)> transfers;
  final List<ExportTab> tabs;
  final bool includeLocation;
}

/// Gathers [adventure]'s summary, transfers and tabs. [names] covers
/// members and pals; [includeLocation] is false for minors.
ExportData buildExportData({
  required Adventure adventure,
  required List<TabEntry> tabs,
  required SplitReport report,
  required Map<String, String> names,
  required Map<String, String> categories,
  required bool includeLocation,
}) {
  final base = adventure.baseCurrency;
  String who(String id) => names[id] ?? 'Someone who left';
  final sorted = [...tabs]..sort((a, b) => a.date.compareTo(b.date));
  return ExportData(
    title: adventure.name,
    dates: formatDateRange(adventure.startDate, adventure.endDate),
    currency: base,
    totalMinor: report.currency == base ? report.totalSpend : 0,
    balances: [
      for (final MapEntry(:key, :value) in report.baseBalances.entries)
        (who(key), value),
    ],
    transfers: [
      for (final t in report.baseTransfers)
        (who(t.from), who(t.to), t.amount.minor),
    ],
    tabs: [
      for (final t in sorted)
        ExportTab(
          date: isoDate(t.date),
          description: t.description.isEmpty
              ? categories[t.category] ?? t.category
              : t.description,
          category: categories[t.category] ?? t.category,
          amountMinor: t.amount.minor,
          currency: t.amount.currency,
          paidBy: [
            for (final p in t.split.payers)
              '${who(p.payer)} ${amountText(p.amountMinor, t.amount.currency)}',
          ].join(', '),
          sharedBy: switch (t.split.percentBp) {
            final bp? => [
              for (final id in t.split.participants)
                '${who(id)} ${formatBasisPoints(bp[id] ?? 0)}',
            ].join(', '),
            null => '${t.split.participants.map(who).join(', ')} (equal)',
          },
          location: includeLocation && t.location != null
              ? '${t.location!.lat}, ${t.location!.lng}'
              : null,
        ),
    ],
    includeLocation: includeLocation,
  );
}

/// A spreadsheet number. Money stays in exact minor units until this one
/// conversion at the edge of the file; Excel cells are numbers.
DoubleCellValue _number(int minor, String currency) => DoubleCellValue(
  double.parse('${minor < 0 ? '-' : ''}${amountText(minor, currency)}'),
);

/// Summary, Who pays whom and Tabs sheets.
Uint8List buildXlsx(ExportData d) {
  final excel = Excel.createExcel();
  final defaultSheet = excel.getDefaultSheet()!;
  final summary = excel['Summary']
    ..appendRow([TextCellValue(d.title)])
    ..appendRow([TextCellValue(d.dates)])
    ..appendRow([TextCellValue('Amounts in ${d.currency}')])
    ..appendRow([])
    ..appendRow([
      TextCellValue('Total spend'),
      _number(d.totalMinor, d.currency),
    ])
    ..appendRow([])
    ..appendRow([TextCellValue('Person'), TextCellValue('Balance')]);
  for (final (name, minor) in d.balances) {
    summary.appendRow([TextCellValue(name), _number(minor, d.currency)]);
  }

  final transfers = excel['Who pays whom']
    ..appendRow([
      TextCellValue('From'),
      TextCellValue('To'),
      TextCellValue('Amount'),
    ]);
  for (final (from, to, minor) in d.transfers) {
    transfers.appendRow([
      TextCellValue(from),
      TextCellValue(to),
      _number(minor, d.currency),
    ]);
  }

  final tabs = excel['Tabs']
    ..appendRow([
      for (final h in [
        'Date',
        'Description',
        'Category',
        'Amount',
        'Currency',
        'Paid by',
        'Shared by',
        if (d.includeLocation) 'Location',
      ])
        TextCellValue(h),
    ]);
  for (final t in d.tabs) {
    tabs.appendRow([
      TextCellValue(t.date),
      TextCellValue(t.description),
      TextCellValue(t.category),
      _number(t.amountMinor, t.currency),
      TextCellValue(t.currency),
      TextCellValue(t.paidBy),
      TextCellValue(t.sharedBy),
      if (d.includeLocation) TextCellValue(t.location ?? ''),
    ]);
  }
  excel
    ..setDefaultSheet('Summary')
    ..delete(defaultSheet);
  return Uint8List.fromList(excel.encode()!);
}

/// The same as a PDF. Amounts use currency codes ("INR 500.00"): the
/// built-in PDF font has no ₹ or ฿.
Future<Uint8List> buildPdf(ExportData d, {bool compress = true}) {
  String money(int minor, [String? currency]) =>
      formatMoney(Money(minor, currency ?? d.currency));
  final doc = pw.Document(compress: compress, title: '${d.title} split')
    ..addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(level: 0, text: d.title),
          pw.Text('${d.dates} · amounts in ${d.currency}'),
          pw.SizedBox(height: 12),
          pw.Text(
            'Total spend: ${money(d.totalMinor)}',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.Header(text: 'Balances'),
          pw.TableHelper.fromTextArray(
            headers: ['Person', 'Balance'],
            data: [
              for (final (name, minor) in d.balances) [name, money(minor)],
            ],
          ),
          pw.Header(text: 'Who pays whom'),
          if (d.transfers.isEmpty)
            pw.Text('Everyone is square.')
          else
            for (final (from, to, minor) in d.transfers)
              pw.Bullet(text: '$from pays $to ${money(minor)}'),
          pw.Header(text: 'Tabs'),
          pw.TableHelper.fromTextArray(
            headers: [
              'Date',
              'Description',
              'Amount',
              'Paid by',
              'Shared by',
              if (d.includeLocation) 'Location',
            ],
            data: [
              for (final t in d.tabs)
                [
                  t.date,
                  t.description,
                  money(t.amountMinor, t.currency),
                  t.paidBy,
                  t.sharedBy,
                  if (d.includeLocation) t.location ?? '',
                ],
            ],
            cellStyle: const pw.TextStyle(fontSize: 8),
            headerStyle: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  return doc.save();
}
