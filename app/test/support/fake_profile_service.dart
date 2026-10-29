import 'dart:async';

import 'package:roamio/features/profile/data/profile_service.dart';

/// In-memory [ProfileService] that records what the You page saves.
class FakeProfileService implements ProfileService {
  new({
    this.currency = 'INR',
    this.profile = const Profile(name: 'Ari Chen', bio: 'Always lost'),
    this.location = false,
    this.camera = true,
  });

  String currency;
  Profile profile;
  bool location;
  bool camera;

  /// Each save as "name | bio".
  final List<String> saved = [];
  final List<String> currencySaved = [];
  final List<bool> locationSaved = [];
  final List<bool> cameraSaved = [];
  final _changes = StreamController<void>.broadcast();

  Stream<T> _live<T>(T Function() read) async* {
    yield read();
    yield* _changes.stream.map((_) => read());
  }

  @override
  Stream<String> profileCurrency() => _live(() => currency);

  @override
  Stream<Profile> profileStream() => _live(() => profile);

  @override
  Future<void> saveProfile({required String name, required String bio}) async {
    saved.add('$name | $bio');
    profile = Profile(name: name, bio: bio, photoUrl: profile.photoUrl);
    _changes.add(null);
  }

  @override
  Future<void> setProfileCurrency(String code) async {
    currencySaved.add(code);
    currency = code;
    _changes.add(null);
  }

  @override
  Stream<bool> locationAllowed() => _live(() => location);

  @override
  Future<void> setLocationAllowed({required bool allowed}) async {
    locationSaved.add(allowed);
    location = allowed;
    _changes.add(null);
  }

  @override
  Stream<bool> cameraAllowed() => _live(() => camera);

  @override
  Future<void> setCameraAllowed({required bool allowed}) async {
    cameraSaved.add(allowed);
    camera = allowed;
    _changes.add(null);
  }
}
