import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/import_data.dart';

void main() {
  final countriesMd = File('../data/world_countries_dataset.md')
      .readAsStringSync();
  final categoriesMd = File('../data/travel_expense_categories_table.md')
      .readAsStringSync();

  group('parseCountries', () {
    final countries = parseCountries(countriesMd);

    test('reads all 195 countries with unique ISO country codes', () {
      expect(countries, hasLength(195));
      final codes = countries.map((c) => c.code).toSet();
      expect(codes, hasLength(195));
      expect(codes.every(RegExp(r'^[A-Z]{2}$').hasMatch), isTrue);
    });

    test('derives the country code from the flag', () {
      final india = countries.singleWhere((c) => c.name == 'India');
      expect(india.code, 'IN');
      expect(india.flag, '🇮🇳');
      expect(india.currency, 'INR');
      expect(india.symbol, '₹');
      expect(india.landmark, isNotEmpty);
    });

    test('every default currency is an active ISO 4217 code', () {
      for (final c in countries) {
        expect(isoCurrencies, contains(c.currency), reason: c.name);
        expect(c.currencies.first, c.currency, reason: c.name);
      }
    });

    test('keeps both currencies where a country uses two', () {
      final panama = countries.singleWhere((c) => c.name == 'Panama');
      expect(panama.currencies, ['PAB', 'USD']);
      expect(panama.currency, 'PAB');
    });

    test('Tuvalu defaults to AUD because TVD is not an ISO code', () {
      final tuvalu = countries.singleWhere((c) => c.name == 'Tuvalu');
      expect(tuvalu.currency, 'AUD');
      expect(tuvalu.currencies, ['AUD']);
    });

    test('Bulgaria uses the euro since 1 January 2026', () {
      final bulgaria = countries.singleWhere((c) => c.name == 'Bulgaria');
      expect(bulgaria.currency, 'EUR');
      expect(bulgaria.symbol, '€');
    });
  });

  group('parseCategories', () {
    final categories = parseCategories(categoriesMd);

    test('reads the 10 expense categories with ids and icons', () {
      expect(categories, hasLength(10));
      expect(categories.map((c) => c.id).toSet(), hasLength(10));
      expect(categories.every((c) => c.emoji.isNotEmpty), isTrue);
      final food = categories.singleWhere((c) => c.id == 'food_dining');
      expect(food.name, 'Food & Dining');
      expect(food.examples, contains('street food'));
    });
  });

  test('the bundled JSON is up to date with the source tables', () {
    final countries = jsonDecode(
      File('assets/data/countries.json').readAsStringSync(),
    );
    final categories = jsonDecode(
      File('assets/data/categories.json').readAsStringSync(),
    );
    expect(countries, jsonDecode(countriesJson(parseCountries(countriesMd))));
    expect(
      categories,
      jsonDecode(categoriesJson(parseCategories(categoriesMd))),
      reason: 'Run: fvm dart run tool/import_data.dart',
    );
  });
}
