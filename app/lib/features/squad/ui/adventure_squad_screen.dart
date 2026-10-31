import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:roamio/features/adventures/data/adventure_service.dart';
import 'package:roamio/features/adventures/ui/adventure_page.dart';
import 'package:roamio/features/auth/data/auth_service.dart';
import 'package:roamio/features/squad/ui/squad_section.dart';

/// An adventure's squad on its own, opened from Home's card (spec UC-5).
class AdventureSquadScreen extends ConsumerWidget {
  const new({required this.adventureId, super.key});

  final String adventureId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adventures = ref.watch(myAdventuresProvider);
    final adventure = adventures.value
        ?.where((a) => a.id == adventureId)
        .firstOrNull;
    if (adventure == null) {
      return AdventureUnavailable(loading: adventures.isLoading);
    }
    return Scaffold(
      appBar: AppBar(title: Text(adventure.name)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          SquadSection(
            adventure: adventure,
            myUid: ref.watch(sessionFactsProvider).value?.uid ?? '',
          ),
        ],
      ),
    );
  }
}
