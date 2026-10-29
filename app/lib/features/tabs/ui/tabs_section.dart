import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:roamio/core/data/categories.dart';
import 'package:roamio/core/data/countries.dart';
import 'package:roamio/core/theme/roamio_colors.dart';
import 'package:roamio/features/adventures/domain/adventure.dart';
import 'package:roamio/features/adventures/ui/adventure_format.dart';
import 'package:roamio/features/auth/data/auth_service.dart';
import 'package:roamio/features/splits/domain/money.dart';
import 'package:roamio/features/tabs/data/tab_service.dart';

/// A simple tab list with Add tab (Task 23). Task 27 replaces it with the
/// full adventure page (banner, sheet, tabs grouped by day).
class TabsSection extends ConsumerWidget {
  const new({required this.adventure, required this.myUid, super.key});

  final Adventure adventure;
  final String myUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final tabs = ref.watch(tabsProvider(adventure.id));
    final open = adventure.tabsOpenOn(ref.watch(todayProvider));
    final countries = ref.watch(countriesProvider).value;
    final categories = {
      for (final c in ref.watch(categoriesProvider).value ?? const <Category>[])
        c.id: c,
    };
    String money(Money m) =>
        formatMoney(m, symbol: countries?.symbolFor(m.currency));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Tabs', style: text.headlineSmall),
        const SizedBox(height: 8),
        ...tabs.when(
          loading: () => [const LinearProgressIndicator()],
          error: (_, _) => [
            Text(
              'We couldn’t load the tabs.',
              style: text.bodyLarge?.copyWith(color: RoamioColors.slate),
            ),
          ],
          data: (list) => list.isEmpty
              ? [
                  Text(
                    'No tabs yet. Add the first one.',
                    style: text.bodyLarge?.copyWith(color: RoamioColors.slate),
                  ),
                ]
              : [
                  for (final t in list)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Text(
                        categories[t.category]?.emoji ?? '🧾',
                        style: const TextStyle(fontSize: 24),
                      ),
                      title: Text(
                        t.description.isEmpty
                            ? categories[t.category]?.name ?? 'Tab'
                            : t.description,
                      ),
                      subtitle: Text(
                        [
                          formatDay(t.date),
                          'Your share ${money(t.shareOf(myUid))}',
                          if (t.memories.isNotEmpty) '📷 ${t.memories.length}',
                          if (t.location != null) '📍',
                        ].join(' · '),
                        style: const TextStyle(color: RoamioColors.slate),
                      ),
                      trailing: Text(money(t.amount), style: text.titleMedium),
                    ),
                ],
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: open
              ? () => context.push('/adventures/${adventure.id}/tabs/new')
              : null,
          icon: const Icon(Icons.add),
          label: const Text('Add tab'),
        ),
        if (!open)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Tabs closed 7 days after the trip ended.',
              textAlign: TextAlign.center,
              style: text.bodySmall?.copyWith(color: RoamioColors.slate),
            ),
          ),
      ],
    );
  }
}
