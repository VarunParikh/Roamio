import 'package:roamio/features/splits/domain/money.dart';

/// What a scanned bill seems to say. Every field may be missing; the
/// person always checks it before saving (spec UC-21).
class ReceiptGuess {
  const new({this.amountMinor, this.date, this.merchant});

  /// The total, in minor units of the tab's currency.
  final int? amountMinor;
  final DateTime? date;
  final String? merchant;

  bool get isEmpty => amountMinor == null && date == null && merchant == null;
}

/// Reads OCR text from a bill: the total, the date and the merchant.
/// [currency] decides the decimals; [today] rules out future dates.
ReceiptGuess parseReceipt(
  String text, {
  required String currency,
  required DateTime today,
}) {
  final lines = [
    for (final l in text.split('\n'))
      if (l.trim().isNotEmpty) l.trim(),
  ];
  return ReceiptGuess(
    amountMinor: _total(lines, currency),
    date: _date(lines, today, monthFirst: currency == 'USD'),
    merchant: _merchant(lines),
  );
}

// ---------- amount ----------

final _number = RegExp(r'\d[\d.,]*\d|\d');

/// Words that mark the final amount, strongest first. Lines with
/// "subtotal", "total items" and the like are never the total.
const _strongTotals = [
  'grand tot',
  'grandtot',
  'amount due',
  'total due',
  'balance due',
  'net amount', //
  'net payable', 'amount payable', 'total amount', 'total ttc', 'totale',
  'bill amount', 'to pay', 'summe', 'gesamt', 'ยอดรวม', 'รวมทั้งสิ้น',
];
const _weakTotals = ['total', 'รวม', 'montant'];
const _notTotals = [
  'subtotal', 'sub total', 'sub-total', 'item total', 'total ht', //
  'total items', 'total qty', 'total tax', 'total discount', 'items:', 'qty',
  'auto pay', 'autopay',
];

/// Rows whose amounts can be higher than the bill: money handed over, or
/// what it would have cost.
const _notTheBill = [
  'cash', 'tender', 'received', 'change', 'balance', 'mrp', 'sav', //
  'contanti', 'espèces', 'especes', 'rendu', 'monnaie', 'gegeben', 'rückgeld',
  'เงินสด', 'ทอน',
];

/// OCR joins the pieces of a row with at least two spaces.
final _cellGap = RegExp(r'\s{2,}');

/// A row holding nothing but an amount, with at most a currency mark.
final _loneAmount = RegExp(
  r'^(?:[^\w\s]|rs\.?|inr|usd|eur|thb)?\s*\d[\d.,]*\s*(?:[^\w\s]|inr|usd|eur|thb)?$',
  caseSensitive: false,
);

/// Only a labelled total is used: with no label, the biggest number on a bill
/// is as likely to be a phone number or pin code, so the person types it.
int? _total(List<String> lines, String currency) {
  int? believable(String line) {
    final amount = _trailingAmount(line, currency);
    return amount != null && amount > 0 && amount <= maxTabMinor(currency)
        ? amount
        : null;
  }

  int? onLineWith(List<String> words) {
    for (var i = lines.length - 1; i >= 0; i--) {
      final cells = lines[i].split(_cellGap);
      // OCR often reads the O in TOTAL as a zero and the L as a one.
      final labels = [
        for (final cell in cells)
          cell.toLowerCase().replaceAll('0', 'o').replaceAll('1', 'l'),
      ];
      final at = labels.lastIndexWhere(
        (l) => words.any(l.contains) && !_notTotals.any(l.contains),
      );
      if (at < 0 ||
          labels.skip(at + 1).any((l) => _notTotals.any(l.contains))) {
        continue;
      }
      final amount =
          believable(cells.skip(at).join(' ')) ??
          (i + 1 < lines.length && _loneAmount.hasMatch(lines[i + 1])
              ? believable(lines[i + 1])
              : null);
      if (amount != null) return amount;
    }
    return null;
  }

  final strong = onLineWith(_strongTotals);
  if (strong != null) return strong;
  // A bare "Total" can belong to a tax table, so a higher amount elsewhere
  // means it isn't trusted: an empty amount beats a wrong one.
  final weak = onLineWith(_weakTotals);
  return weak != null && _highestPrice(lines, currency) > weak ? null : weak;
}

/// The highest amount written with the currency's decimals, which rules out
/// phone numbers and codes, on rows that could be part of the bill. Zero for a
/// currency with no decimals.
int _highestPrice(List<String> lines, String currency) {
  final digits = minorUnitDigits(currency);
  if (digits == 0) return 0;
  // Not part of a date, and not a rate or a time.
  final price = RegExp(
    '(?<![\\d.,])\\d[\\d.,]*[.,]\\d{$digits}'
    r'(?![\d.,]*\d|\s*%|\s*[ap]\.?m)',
    caseSensitive: false,
  );
  var highest = 0;
  for (final line in lines) {
    if (_notTheBill.any(line.toLowerCase().contains)) continue;
    for (final match in price.allMatches(line)) {
      final amount = localAmount(match.group(0)!, currency);
      if (amount != null &&
          amount > highest &&
          amount <= maxTabMinor(currency)) {
        highest = amount;
      }
    }
  }
  return highest;
}

/// The last number on [line], read in the receipt's own style.
int? _trailingAmount(String line, String currency) {
  final matches = _number.allMatches(line).toList();
  if (matches.isEmpty) return null;
  final last = matches.last;
  // A number followed by '%' or ':' is a rate or a time, not money.
  final after = line.substring(last.end).trimLeft();
  if (after.startsWith('%') || after.startsWith(':')) return null;
  return localAmount(last.group(0)!, currency);
}

/// "1,234.56", "1.234,56", "13,40", "1,050" or "588" in minor units of
/// [currency]. The last separator is the decimal point when it is followed
/// by the currency's number of decimals (or 1–2 digits), and when both '.'
/// and ',' appear; otherwise separators group thousands.
int? localAmount(String token, String currency) {
  final digits = minorUnitDigits(currency);
  final lastDot = token.lastIndexOf('.');
  final lastComma = token.lastIndexOf(',');
  final lastSep = lastDot > lastComma ? lastDot : lastComma;
  var whole = token;
  var fraction = '';
  if (lastSep >= 0) {
    final tail = token.substring(lastSep + 1);
    final sep = token[lastSep];
    final mixed = lastDot >= 0 && lastComma >= 0;
    final once = sep.allMatches(token).length == 1;
    final looksDecimal =
        mixed ||
        (once &&
            digits > 0 &&
            (tail.length == digits || (tail.length <= 2 && digits >= 2)));
    if (looksDecimal) {
      whole = token.substring(0, lastSep);
      fraction = tail;
    }
  }
  whole = whole.replaceAll(RegExp('[.,]'), '');
  if (whole.isEmpty || fraction.length > digits) return null;
  return int.tryParse(whole + fraction.padRight(digits, '0'));
}

// ---------- date ----------

const _months = {
  'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6, //
  'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
};

final _numericDate = RegExp(r'(\d{1,4})[/.\-](\d{1,2})[/.\-](\d{2,4})');
final _dayMonthName = RegExp(
  r'(\d{1,2})[\s\-]([A-Za-z]{3,9})\.?[\s\-,]+(\d{2,4})',
);
final _monthNameDay = RegExp(r'([A-Za-z]{3,9})\.?\s+(\d{1,2}),?\s+(\d{4})');

DateTime? _date(
  List<String> lines,
  DateTime today, {
  required bool monthFirst,
}) {
  for (final line in lines) {
    final d = _findDate(line, monthFirst: monthFirst);
    if (d != null) {
      final day = DateTime(today.year, today.month, today.day);
      return d.isAfter(day) ? null : d;
    }
  }
  return null;
}

DateTime? _findDate(String line, {required bool monthFirst}) {
  for (final m in _numericDate.allMatches(line)) {
    final a = int.parse(m.group(1)!);
    final b = int.parse(m.group(2)!);
    final c = int.parse(m.group(3)!);
    if (m.group(1)!.length == 4) return _make(a, b, c); // 2026-10-29
    // Day first, unless that can't be (or it's a US receipt and could be).
    final dayFirst = a > 12 || (b <= 12 && !monthFirst);
    final d = dayFirst ? _make(c, b, a) : _make(c, a, b);
    if (d != null) return d;
  }
  for (final m in _dayMonthName.allMatches(line)) {
    final month = _months[m.group(2)!.toLowerCase().substring(0, 3)];
    if (month != null) {
      return _make(int.parse(m.group(3)!), month, int.parse(m.group(1)!));
    }
  }
  for (final m in _monthNameDay.allMatches(line)) {
    final month = _months[m.group(1)!.toLowerCase().substring(0, 3)];
    if (month != null) {
      return _make(int.parse(m.group(3)!), month, int.parse(m.group(2)!));
    }
  }
  return null;
}

/// A real calendar date, reading two-digit years as 20xx and Thai
/// Buddhist-era years (2569 = 2026) as Gregorian.
DateTime? _make(int year, int month, int day) {
  final y = year < 100
      ? 2000 + year
      : year > 2400
      ? year - 543
      : year;
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  final d = DateTime(y, month, day);
  return d.month == month && d.day == day ? d : null;
}

// ---------- merchant ----------

final _latin = RegExp('[A-Za-zÀ-ÿ]');
const _notMerchant = [
  'tax invoice', 'invoice', 'receipt', 'cash memo', 'bill no', 'gstin', //
  'date', 'time', 'tel', 'phone', 'thank', 'order', 'table',
];

String? _merchant(List<String> lines) {
  for (final line in lines.take(5)) {
    final lower = line.toLowerCase();
    final letters = _latin.allMatches(line).length;
    if (line.length < 3 || line.length > 40 || letters < 3) continue;
    if (_notMerchant.any(lower.startsWith)) continue;
    if (_findDate(line, monthFirst: false) != null) continue;
    return _tidy(line);
  }
  return null;
}

/// "SPICE ROUTE" → "Spice Route", "7-ELEVEN" → "7-Eleven"; mixed case is
/// left as printed.
String _tidy(String line) {
  if (line != line.toUpperCase()) return line;
  final out = StringBuffer();
  var startOfWord = true;
  for (final ch in line.toLowerCase().split('')) {
    final isLetter = _latin.hasMatch(ch);
    out.write(isLetter && startOfWord ? ch.toUpperCase() : ch);
    startOfWord = !isLetter && ch != "'";
  }
  return out.toString();
}

// ---------- layout ----------

/// One line of text OCR found, and where it sits on the photo.
class TextPiece {
  const new(
    this.text, {
    required this.left,
    required this.top,
    required this.bottom,
    this.slope = 0,
  });

  final String text;
  final double left;
  final double top;
  final double bottom;

  /// How far the line drops per pixel to the right; above 0 on a photo
  /// turned clockwise.
  final double slope;

  double get middle => (top + bottom) / 2;
}

/// OCR reads a bill in columns (all the names, then all the prices), so
/// this puts pieces whose middles sit at the same height back on one row,
/// left to right, rows top to bottom. Heights are levelled first using the
/// typical slope, so a tilted photo's rows still line up.
String rowsFromPieces(List<TextPiece> pieces) {
  final slopes = [for (final p in pieces) p.slope]..sort();
  final tilt = slopes.isEmpty ? 0.0 : slopes[slopes.length ~/ 2];
  double level(TextPiece p) => p.middle - p.left * tilt;
  final sorted = [...pieces]..sort((a, b) => level(a).compareTo(level(b)));
  final rows = <List<TextPiece>>[];
  for (final p in sorted) {
    final row = rows.isEmpty ? null : rows.last;
    final first = row?.first;
    final sameRow =
        first != null &&
        (level(p) - level(first)).abs() < (first.bottom - first.top) / 2;
    if (sameRow) {
      row!.add(p);
    } else {
      rows.add([p]);
    }
  }
  return [
    for (final row in rows)
      ([...row]..sort((a, b) => a.left.compareTo(b.left)))
          .map((p) => p.text)
          .join('  '),
  ].join('\n');
}
