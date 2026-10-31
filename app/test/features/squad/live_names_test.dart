import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/features/squad/data/squad_service.dart';

import '../../support/fake_squad_service.dart';

void main() {
  test('a name change shows without a restart (item 4)', () async {
    final squad = FakeSquadService()..names['ari'] = 'Ari';
    final container = ProviderContainer(
      overrides: [squadServiceProvider.overrideWithValue(squad)],
    );
    addTearDown(container.dispose);
    container.listen(squadNamesProvider('ari'), (_, _) {});

    await container.read(squadPeopleProvider('ari').future);
    expect(container.read(squadNamesProvider('ari')).value, {'ari': 'Ari'});

    squad.rename('ari', 'Ari Lee');
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(container.read(squadNamesProvider('ari')).value, {'ari': 'Ari Lee'});
  });
}
