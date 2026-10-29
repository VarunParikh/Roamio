// Converts the owner's source tables in /data into the app's bundled JSON.
// Run from app/:  fvm dart run tool/import_data.dart
import 'dart:convert';
import 'dart:io';

/// Active ISO 4217 currency codes (as of 2026).
const isoCurrencies = {
  'AED', 'AFN', 'ALL', 'AMD', 'AOA', 'ARS', 'AUD', 'AWG', 'AZN', 'BAM', //
  'BBD', 'BDT', 'BGN', 'BHD', 'BIF', 'BMD', 'BND', 'BOB', 'BRL', 'BSD', //
  'BTN', 'BWP', 'BYN', 'BZD', 'CAD', 'CDF', 'CHF', 'CLP', 'CNY', 'COP', //
  'CRC', 'CUP', 'CVE', 'CZK', 'DJF', 'DKK', 'DOP', 'DZD', 'EGP', 'ERN', //
  'ETB', 'EUR', 'FJD', 'FKP', 'GBP', 'GEL', 'GHS', 'GIP', 'GMD', 'GNF', //
  'GTQ', 'GYD', 'HKD', 'HNL', 'HTG', 'HUF', 'IDR', 'ILS', 'INR', 'IQD', //
  'IRR', 'ISK', 'JMD', 'JOD', 'JPY', 'KES', 'KGS', 'KHR', 'KMF', 'KPW', //
  'KRW', 'KWD', 'KYD', 'KZT', 'LAK', 'LBP', 'LKR', 'LRD', 'LSL', 'LYD', //
  'MAD', 'MDL', 'MGA', 'MKD', 'MMK', 'MNT', 'MOP', 'MRU', 'MUR', 'MVR', //
  'MWK', 'MXN', 'MYR', 'MZN', 'NAD', 'NGN', 'NIO', 'NOK', 'NPR', 'NZD', //
  'OMR', 'PAB', 'PEN', 'PGK', 'PHP', 'PKR', 'PLN', 'PYG', 'QAR', 'RON', //
  'RSD', 'RUB', 'RWF', 'SAR', 'SBD', 'SCR', 'SDG', 'SEK', 'SGD', 'SHP', //
  'SLE', 'SOS', 'SRD', 'SSP', 'STN', 'SVC', 'SYP', 'SZL', 'THB', 'TJS', //
  'TMT', 'TND', 'TOP', 'TRY', 'TTD', 'TWD', 'TZS', 'UAH', 'UGX', 'USD', //
  'UYU', 'UZS', 'VED', 'VES', 'VND', 'VUV', 'WST', 'XAF', 'XCD', 'XCG', //
  'XOF', 'XPF', 'YER', 'ZAR', 'ZMW', 'ZWG',
};

/// Corrections to the source table, by country name. The source file stays
/// as the owner wrote it.
const _overrides = <String, ({String currencies, String symbol})>{
  // Bulgaria adopted the euro on 1 January 2026.
  'Bulgaria': (currencies: 'EUR', symbol: '€'),
};

class Country {
  const new({
    required this.code,
    required this.name,
    required this.flag,
    required this.currencies,
    required this.symbol,
    required this.landmark,
    required this.landmarkType,
  });

  /// ISO 3166-1 alpha-2, read from the flag emoji.
  final String code;
  final String name;
  final String flag;

  /// Valid ISO 4217 codes, default first.
  final List<String> currencies;
  final String symbol;
  final String landmark;
  final String landmarkType;

  String get currency => currencies.first;

  Map<String, Object> toJson() => {
    'code': code,
    'name': name,
    'flag': flag,
    'currency': currency,
    'currencies': currencies,
    'symbol': symbol,
    'landmark': landmark,
    'landmarkType': landmarkType,
  };
}

class Category {
  const new({
    required this.id,
    required this.name,
    required this.emoji,
    required this.examples,
    required this.timing,
  });

  final String id;
  final String name;
  final String emoji;
  final String examples;
  final String timing;

  Map<String, Object> toJson() => {
    'id': id,
    'name': name,
    'emoji': emoji,
    'examples': examples,
    'timing': timing,
  };
}

const _categoryEmoji = {
  'pre_trip_preparation': '🧳',
  'primary_transportation': '✈️',
  'accommodation': '🏨',
  'local_transportation': '🛺',
  'food_dining': '🍜',
  'activities_sightseeing': '🎟️',
  'shopping_souvenirs': '🛍️',
  'connectivity_technology': '📶',
  'incidentals': '💸',
  'miscellaneous': '🧩',
};

/// The data rows of a markdown table (skips the header and `:---` rows).
List<List<String>> _rows(String markdown) => [
  for (final line in const LineSplitter().convert(markdown))
    if (line.startsWith('|') && !line.contains('---'))
      line.split('|').map((c) => c.trim()).toList()..removeAt(0),
]..removeAt(0);

String _codeFromFlag(String flag) => String.fromCharCodes(
  flag.runes.map((r) => r - 0x1F1E6 + 'A'.codeUnitAt(0)),
);

List<Country> parseCountries(String markdown) => [
  for (final cells in _rows(markdown))
    () {
      final name = cells[0];
      final override = _overrides[name];
      final listed = (override?.currencies ?? cells[3])
          .split('/')
          .map((c) => c.trim())
          .where(isoCurrencies.contains)
          .toList();
      if (listed.isEmpty) throw FormatException('No ISO currency for $name');
      return Country(
        code: _codeFromFlag(cells[1]),
        name: name,
        flag: cells[1],
        currencies: listed,
        symbol: override?.symbol ?? cells[4].split('/').first.trim(),
        landmark: cells[5],
        landmarkType: cells[6],
      );
    }(),
];

String _slug(String name) => name
    .toLowerCase()
    .replaceAll('&', ' ')
    .replaceAll(RegExp('[^a-z]+'), '_')
    .replaceAll(RegExp(r'^_|_$'), '');

List<Category> parseCategories(String markdown) => [
  for (final cells in _rows(markdown))
    () {
      final name = cells[0].replaceAll('**', '');
      final id = _slug(name);
      return Category(
        id: id,
        name: name,
        emoji: _categoryEmoji[id] ?? (throw FormatException('No icon for $id')),
        examples: cells[1].toLowerCase(),
        timing: cells[2],
      );
    }(),
];

const _encoder = JsonEncoder.withIndent('  ');

String countriesJson(List<Country> countries) =>
    '${_encoder.convert([for (final c in countries) c.toJson()])}\n';

String categoriesJson(List<Category> categories) =>
    '${_encoder.convert([for (final c in categories) c.toJson()])}\n';

void main() {
  final countries = parseCountries(
    File('../data/world_countries_dataset.md').readAsStringSync(),
  );
  final categories = parseCategories(
    File('../data/travel_expense_categories_table.md').readAsStringSync(),
  );
  File('assets/data/countries.json')
      .writeAsStringSync(countriesJson(countries));
  File('assets/data/categories.json')
      .writeAsStringSync(categoriesJson(categories));
  stdout.writeln(
    'Wrote ${countries.length} countries and ${categories.length} categories.',
  );
}
