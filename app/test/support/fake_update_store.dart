import 'package:roamio/features/updates/update_checker.dart';

/// Keeps the update checker's notes in memory.
class FakeUpdateStore implements UpdateStore {
  Map<String, Object?> saved = {};

  @override
  Future<Map<String, Object?>> read() async => {...saved};

  @override
  Future<void> write(Map<String, Object?> data) async => saved = {...data};
}
