import 'package:roamio/features/adventures/data/activity_service.dart';

/// Recent activity per adventure, newest first.
class FakeActivityService implements ActivityService {
  new([Map<String, List<ActivityEntry>>? byAdventure])
    : byAdventure = {...?byAdventure};

  final Map<String, List<ActivityEntry>> byAdventure;

  @override
  Stream<List<ActivityEntry>> recent(String adventureId) async* {
    yield byAdventure[adventureId] ?? const [];
  }
}
