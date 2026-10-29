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
  'grand total', 'amount due', 'total due', 'balance due', 'net amount', //
  'net payable', 'amount payable', 'total amount', 'total ttc', 'totale',
  'summe', 'gesamt', 'ยอดรวม', 'รวมทั้งสิ้น',
];
const _weakTotals = ['total', 'รวม', 'montant'];
const _notTotals = [
  'subtotal', 'sub total', 'sub-total', 'total ht', 'total items', //
  'total qty', 'total tax', 'items:', 'qty',
];

int? _total(List<String> lines, String currency) {
  int? onLineWith(List<String> words) {
    for (final line in lines.reversed) {
      final lower = line.toLowerCase();
      if (_notTotals.any(lower.contains)) continue;
      if (words.any(lower.contains)) {
        final amount = _trailingAmount(line, currency);
        if (amount != null) return amount;
      }
    }
    return null;
  }

  // Otherwise the biggest amount ending an item line, skipping dates.
  int? largest() {
    int? best;
    for (final line in lines) {
      if (_findDate(line, monthFirst: false) != null) continue;
      final amount = _trailingAmount(line, currency);
      if (amount != null && (best == null || amount > best)) best = amount;
    }
    return best;
  }

  return onLineWith(_strongTotals) ?? onLineWith(_weakTotals) ?? largest();
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
  return int.parse(whole + fraction.padRight(digits, '0'));
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
  });

  final String text;
  final double left;
  final double top;
  final double bottom;

  double get middle => (top + bottom) / 2;
}

/// OCR reads a bill in columns (all the names, then all the prices), so
/// this puts pieces whose middles sit at the same height back on one row,
/// left to right, rows top to bottom.
String rowsFromPieces(List<TextPiece> pieces) {
  final sorted = [...pieces]..sort((a, b) => a.middle.compareTo(b.middle));
  final rows = <List<TextPiece>>[];
  for (final p in sorted) {
    final row = rows.isEmpty ? null : rows.last;
    final first = row?.first;
    final sameRow =
        first != null &&
        (p.middle - first.middle).abs() < (first.bottom - first.top) / 2;
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
