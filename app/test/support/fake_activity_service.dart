import 'package:roamio/features/adventures/data/activity_service.dart';

/// Recent activity per adventure, newest first.
class FakeActivityService implements ActivityService {
  new([Map<String, List<ActivityEntry>>? byAdventure])
    : byAdventure = {...?byAdventure};

  final Map<String, List<ActivityEntry>> byAdventure;

  /// How many trips were read in full, and which ones just for their latest.
  int recentReads = 0;
  final List<String> latestReads = [];

  @override
  Stream<List<ActivityEntry>> recent(String adventureId) async* {
    recentReads++;
    yield byAdventure[adventureId] ?? const [];
  }

  @override
  Stream<ActivityEntry?> latest(String adventureId) async* {
    latestReads.add(adventureId);
    yield byAdventure[adventureId]?.firstOrNull;
  }
}
