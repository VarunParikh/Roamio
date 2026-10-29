import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/core/data/countries.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads the bundled countries and finds them by code and name', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final countries = await container.read(countriesProvider.future);

    expect(countries.all, hasLength(195));
    expect(countries.byCode('TH')?.currency, 'THB');
    expect(countries.search('ind').first.name, 'India');
    expect(countries.search('land').map((c) => c.name), contains('Thailand'));
    expect(countries.search(''), hasLength(195));
    expect(countries.currencies, contains('EUR'));
    expect(
      countries.currencies.toSet(),
      hasLength(countries.currencies.length),
    );
  });
}
