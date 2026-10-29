import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/core/config/remote_config.dart';
import 'package:roamio/core/data/categories.dart';
import 'package:roamio/features/home/data/weather_provider.dart';
import 'package:roamio/features/splits/ui/export_sheet.dart';
import 'package:roamio/features/tabs/data/receipt_scanner.dart';

class _Source implements RemoteConfigSource {
  new(this.values, {this.fails = false});

  final Map<String, String> values;
  final bool fails;

  @override
  Future<Map<String, String>> load() async {
    if (fails) throw Exception('no connection');
    return values;
  }
}

Future<ProviderContainer> _with(RemoteConfigSource source) async {
  final c = ProviderContainer(
    overrides: [remoteConfigSourceProvider.overrideWithValue(source)],
  );
  addTearDown(c.dispose);
  await c.read(remoteValuesProvider.future);
  return c;
}

void main() {
  group('Remote Config (spec §11)', () {
    test(
      'every key has an in-app default, used when the fetch fails',
      () async {
        final c = await _with(_Source(const {}, fails: true));
        final config = c.read(appConfigProvider);

        expect(config.ocrEnabled, isTrue);
        expect(config.weatherEnabled, isTrue);
        expect(config.exportEnabled, isTrue);
        expect(config.ctaPulse, isTrue);
        expect(config.minSupportedVersion, '0.0.0');
        expect(config.categoryOrder, isEmpty);
        expect(c.read(ocrEnabledProvider), isTrue);
        expect(c.read(weatherEnabledProvider), isTrue);
        expect(c.read(exportEnabledProvider), isTrue);
        expect(
          remoteConfigDefaults.keys,
          containsAll(<String>[
            'ocr_enabled',
            'weather_enabled',
            'export_enabled',
            'cta_pulse_enabled',
            'min_supported_version',
            'category_order',
          ]),
        );
      },
    );

    test('fetched values switch features off and on', () async {
      final c = await _with(
        _Source(const {
          'ocr_enabled': 'false',
          'weather_enabled': 'false',
          'export_enabled': 'false',
          'cta_pulse_enabled': 'false',
          'min_supported_version': '1.2.0',
          'category_order': 'food_dining, local_transportation',
        }),
      );

      expect(c.read(ocrEnabledProvider), isFalse);
      expect(c.read(weatherEnabledProvider), isFalse);
      expect(c.read(exportEnabledProvider), isFalse);
      expect(c.read(appConfigProvider).ctaPulse, isFalse);
      expect(c.read(appConfigProvider).minSupportedVersion, '1.2.0');
      expect(c.read(appConfigProvider).categoryOrder, [
        'food_dining',
        'local_transportation',
      ]);
    });

    test('a garbled value falls back to its default', () async {
      final c = await _with(
        _Source(const {
          'ocr_enabled': 'maybe',
          'min_supported_version': 'soon',
        }),
      );
      expect(c.read(appConfigProvider).ocrEnabled, isTrue);
      expect(c.read(appConfigProvider).minSupportedVersion, '0.0.0');
    });

    test('category_order puts named categories first, the rest after', () {
      const a = Category(id: 'a', name: 'A', emoji: 'x');
      const b = Category(id: 'b', name: 'B', emoji: 'x');
      const c = Category(id: 'c', name: 'C', emoji: 'x');
      expect(orderCategories([a, b, c], ['c', 'nope', 'a']).map((x) => x.id), [
        'c',
        'a',
        'b',
      ]);
      expect(orderCategories([a, b, c], const []).map((x) => x.id), [
        'a',
        'b',
        'c',
      ]);
    });
  });
}
