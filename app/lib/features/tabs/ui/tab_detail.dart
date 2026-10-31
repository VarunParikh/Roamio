import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:roamio/core/data/categories.dart';
import 'package:roamio/core/theme/roamio_colors.dart';
import 'package:roamio/features/adventures/data/adventure_service.dart';
import 'package:roamio/features/adventures/domain/adventure.dart';
import 'package:roamio/features/adventures/ui/adventure_format.dart';
import 'package:roamio/features/adventures/ui/adventure_page.dart';
import 'package:roamio/features/auth/data/auth_service.dart';
import 'package:roamio/features/auth/domain/age.dart';
import 'package:roamio/features/banners/data/banner_service.dart';
import 'package:roamio/features/splits/domain/money.dart';
import 'package:roamio/features/splits/domain/split_engine.dart';
import 'package:roamio/features/squad/data/squad_service.dart';
import 'package:roamio/features/squad/ui/person.dart';
import 'package:roamio/features/tabs/data/tab_service.dart';
import 'package:roamio/features/tabs/domain/new_tab.dart';
import 'package:roamio/features/tabs/domain/payment_method.dart';
import 'package:roamio/features/tabs/domain/tab_approval.dart';
import 'package:roamio/features/tabs/ui/tabs_section.dart';

/// One tab (spec UC-23): who paid and how, everyone's share, photos and where.
/// Its creator can edit it; leads can delete it (soft, UC-22).
class TabDetailScreen extends ConsumerWidget {
  const new({required this.adventureId, required this.tabId, super.key});

  final String adventureId;
  final String tabId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adventure = ref
        .watch(myAdventuresProvider)
        .value
        ?.where((a) => a.id == adventureId)
        .firstOrNull;
    final tab = ref.watch(tabProvider((adventureId, tabId)));
    final myUid = ref.watch(sessionFactsProvider).value?.uid ?? '';
    final entry = tab.value;
    final live = entry != null && !entry.deleted && adventure != null;
    if (adventure == null) {
      return AdventureUnavailable(
        loading: ref.watch(myAdventuresProvider).isLoading,
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        actions: [
          if (live && entry.createdBy == myUid)
            IconButton(
              tooltip: 'Edit tab',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () =>
                  context.push('/adventures/$adventureId/tabs/$tabId/edit'),
            ),
          if (live && canDeleteTab(adventure, entry, myUid))
            IconButton(
              tooltip: 'Delete tab',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _delete(context, ref, entry),
            ),
        ],
      ),
      body: SafeArea(
        child: switch (tab) {
          AsyncLoading() => const Center(child: CircularProgressIndicator()),
          AsyncData(value: final TabEntry t) when !t.deleted => _Details(
            adventure: adventure,
            tab: t,
            myUid: myUid,
          ),
          _ => _Gone(deleted: entry?.deleted ?? false),
        },
      ),
    );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    TabEntry tab,
  ) async {
    final name = tab.description.isEmpty ? 'this tab' : '“${tab.description}”';
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete $name?'),
        content: const Text(
          'It leaves the list and the split. The squad’s activity shows '
          'that you deleted it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (!(sure ?? false)) return;
    await ref.read(tabServiceProvider).deleteTab(adventureId, tab.id);
    if (context.mounted) context.pop();
  }
}

class _Details extends ConsumerWidget {
  const new({required this.adventure, required this.tab, required this.myUid});

  final Adventure adventure;
  final TabEntry tab;
  final String myUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final slate = text.bodyMedium?.copyWith(color: RoamioColors.slate);
    final category = (ref.watch(categoriesProvider).value ?? const <Category>[])
        .where((c) => c.id == tab.category)
        .firstOrNull;
    final labels = squadLabels(ref, adventure);
    final people = squadPeople(ref, adventure);
    String who(String id) =>
        id == myUid ? '${labels[id] ?? 'You'} (you)' : labels[id] ?? 'Left';
    String money(int minor) =>
        formatWithSymbol(ref, Money(minor, tab.amount.currency));
    final shares = problemsWith(tab.split).isEmpty
        ? sharesFor(tab.split)
        : const <String, int>{};
    final percent = tab.split.percentBp;
    final location = tab.location;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      children: [
        Row(
          children: [
            Text(category?.emoji ?? '🧾', style: const TextStyle(fontSize: 32)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                tab.description.isEmpty
                    ? category?.name ?? 'Tab'
                    : tab.description,
                style: text.headlineSmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text([formatDay(tab.date), ?category?.name].join(' · '), style: slate),
        if (tab.split.fxDate != isoDate(tab.date))
          Text(
            'Converted at exchange rates from '
            '${formatDay(parseIsoDate(tab.split.fxDate))}',
            style: slate,
          ),
        const SizedBox(height: 16),
        Text(money(tab.amount.minor), style: text.displaySmall),
        const SizedBox(height: 24),
        Text('Paid by', style: text.titleMedium),
        for (final p in tab.split.payers)
          _Line(
            uid: p.payer,
            person: people[p.payer],
            label: who(p.payer),
            value: money(p.amountMinor),
            method: p.method,
          ),
        const SizedBox(height: 16),
        Text(
          percent == null ? 'Shares · split equally' : 'Shares · custom %',
          style: text.titleMedium,
        ),
        for (final id in tab.split.participants)
          _Line(
            uid: id,
            person: people[id],
            label: who(id),
            value: percent == null
                ? money(shares[id] ?? 0)
                : '${formatBasisPoints(percent[id] ?? 0)} · '
                      '${money(shares[id] ?? 0)}',
          ),
        if (tab.memories.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('Photos', style: text.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (i, url) in tab.memories.indexed)
                GestureDetector(
                  key: ValueKey('memory-$i'),
                  onTap: () => showDialog<void>(
                    context: context,
                    builder: (_) => Dialog(
                      child: InteractiveViewer(
                        child: CachedNetworkImage(imageUrl: url),
                      ),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: url,
                      width: 96,
                      height: 96,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => Container(
                        width: 96,
                        height: 96,
                        color: RoamioColors.hairline,
                        child: const Icon(Icons.image_outlined),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
        if (location != null) ...[
          const SizedBox(height: 24),
          Text(
            '📍 ${location.label}',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => ref.read(openLinkProvider)(
              Uri.https('www.google.com', '/maps/search/', {
                'api': '1',
                'query': '${location.lat},${location.lng}',
              }),
            ),
            icon: const Icon(Icons.place_outlined),
            label: const Text('Open in Maps'),
          ),
        ],
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const new({
    required this.uid,
    required this.person,
    required this.label,
    required this.value,
    this.method,
  });

  final String uid;
  final SquadPerson? person;
  final String label;
  final String value;

  /// How a payer paid, under their name.
  final PaymentMethod? method;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PersonAvatar(uid: uid, person: person, radius: 14),
              const SizedBox(width: 8),
              Expanded(child: Text(label, style: text.bodyLarge)),
              Text(value, style: text.bodyLarge),
            ],
          ),
          if (method case final m?)
            Text(
              '${m.emoji} ${m.label}',
              semanticsLabel: paidWithLabel([m]),
              style: text.bodyMedium?.copyWith(color: RoamioColors.slate),
            ),
        ],
      ),
    );
  }
}

class _Gone extends StatelessWidget {
  const new({required this.deleted});

  final bool deleted;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          deleted ? 'This tab was deleted.' : 'This tab isn’t available.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: () => context.pop(),
          child: const Text('Back to the adventure'),
        ),
      ],
    ),
  );
}
