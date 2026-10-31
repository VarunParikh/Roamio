import 'package:roamio/features/home/data/home_card_memory.dart';

/// Keeps "expanded" in memory; it starts collapsed unless told otherwise.
class FakeHomeCardMemory implements HomeCardMemory {
  new({this.expanded = false});

  bool expanded;

  @override
  Future<bool> readExpanded() async => expanded;

  @override
  Future<void> writeExpanded({required bool expanded}) async =>
      this.expanded = expanded;
}
