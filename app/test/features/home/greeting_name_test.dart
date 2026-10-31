import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/features/home/ui/home_screen.dart';
import 'package:roamio/features/profile/data/profile_service.dart';

void main() {
  test(
    'the greeting follows a name change without a restart (item 13)',
    () async {
      final names = StreamController<Profile>();
      addTearDown(names.close);
      final container = ProviderContainer(
        overrides: [profileStreamProvider.overrideWith((ref) => names.stream)],
      );
      addTearDown(container.dispose);
      container.listen(greetingNameProvider, (_, _) {});

      names.add(const Profile(name: 'Ari Lee'));
      await Future<void>.delayed(Duration.zero);
      expect(container.read(greetingNameProvider), 'Ari');

      names.add(const Profile(name: 'Bea Cruz'));
      await Future<void>.delayed(Duration.zero);
      expect(container.read(greetingNameProvider), 'Bea');
    },
  );
}
