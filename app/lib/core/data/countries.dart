import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A country from `assets/data/countries.json` (built by tool/import_data.dart).
class Country {
  const new({
    required this.code,
    required this.name,
    required this.flag,
    required this.currency,
    required this.symbol,
    required this.landmark,
  });

  factory fromJson(Map<String, dynamic> json) => Country(
    code: json['code'] as String,
    name: json['name'] as String,
    flag: json['flag'] as String,
    currency: json['currency'] as String,
    symbol: json['symbol'] as String,
    landmark: json['landmark'] as String,
  );

  final String code;
  final String name;
  final String flag;

  /// Default ISO 4217 currency.
  final String currency;
  final String symbol;
  final String landmark;
}

class Countries {
  new(this.all) : _byCode = {for (final c in all) c.code: c};

  final List<Country> all;
  final Map<String, Country> _byCode;

  Country? byCode(String code) => _byCode[code];

  /// Every currency in use, alphabetically, for the currency picker.
  List<String> get currencies =>
      ({for (final c in all) c.currency}.toList()..sort());

  /// The symbol for [currency], like ฿ or €, if any country uses it.
  String? symbolFor(String currency) =>
      all.where((c) => c.currency == currency).firstOrNull?.symbol;

  /// Countries whose name starts with, then contains, [text].
  List<Country> search(String text) {
    final q = text.trim().toLowerCase();
    if (q.isEmpty) return all;
    final starts = all.where((c) => c.name.toLowerCase().startsWith(q));
    final contains = all.where(
      (c) =>
          !c.name.toLowerCase().startsWith(q) &&
          c.name.toLowerCase().contains(q),
    );
    return [...starts, ...contains];
  }
}

final countriesProvider = FutureProvider<Countries>((ref) async {
  final raw = await rootBundle.loadString('assets/data/countries.json');
  final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
  return Countries(list.map(Country.fromJson).toList());
});
