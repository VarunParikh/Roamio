import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/features/splits/data/fx_repository.dart';
import 'package:roamio/features/splits/domain/money.dart';

import '../../support/fake_fx_repository.dart';

void main() {
  test(
    'rates that arrive while the app is open show without a restart (item 14)',
    () async {
      final fx = FakeFxRepository({'THB': '35'});
      final container = ProviderContainer(
        overrides: [fxRepositoryProvider.overrideWithValue(fx)],
      );
      addTearDown(container.dispose);
      container.listen(fxRatesProvider('2026-10-30'), (_, _) {});
      await container.read(fxRatesProvider('2026-10-30').future);
      expect(container.read(fxRatesProvider('2026-10-30')).value, isNotNull);

      fx.rates = {};
      container.listen(latestRatesDayProvider, (_, _) {});
      fx.arrive('2026-10-30', {'THB': '36'});
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await container.read(fxRatesProvider('2026-10-30').future);
      final rates = container.read(fxRatesProvider('2026-10-30')).value!;
      expect(rates.convert(Money(100, 'USD'), 'THB').minor, 3600);
    },
  );
}
