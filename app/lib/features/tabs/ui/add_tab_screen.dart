import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:roamio/core/data/categories.dart';
import 'package:roamio/core/data/countries.dart';
import 'package:roamio/core/theme/roamio_colors.dart';
import 'package:roamio/core/ui/primary_button.dart';
import 'package:roamio/features/adventures/data/adventure_service.dart';
import 'package:roamio/features/adventures/domain/adventure.dart';
import 'package:roamio/features/adventures/ui/adventure_format.dart';
import 'package:roamio/features/auth/data/auth_service.dart';
import 'package:roamio/features/auth/ui/auth_scaffold.dart';
import 'package:roamio/features/splits/domain/money.dart';
import 'package:roamio/features/squad/data/squad_service.dart';
import 'package:roamio/features/tabs/data/tab_service.dart';
import 'package:roamio/features/tabs/domain/new_tab.dart';

/// Add a tab (spec UC-21, basic): one payer (you) and an equal split.
/// Multiple payers and custom percentages arrive in Task 24.
class AddTabScreen extends ConsumerWidget {
  const new({required this.adventureId, super.key});

  final String adventureId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adventure = ref
        .watch(myAdventuresProvider)
        .value
        ?.where((a) => a.id == adventureId)
        .firstOrNull;
    if (adventure == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return _AddTabForm(adventure: adventure);
  }
}

class _AddTabForm extends ConsumerStatefulWidget {
  const new({required this.adventure});

  final Adventure adventure;

  @override
  ConsumerState<_AddTabForm> createState() => _AddTabFormState();
}

class _AddTabFormState extends ConsumerState<_AddTabForm> {
  late final Adventure _a = widget.adventure;
  final _amount = TextEditingController();
  final _description = TextEditingController();
  late String _currency = _a.baseCurrency;
  late DateTime _date = ref.read(todayProvider);
  String? _category;

  /// Everyone starts ticked, including pals that load later.
  final Set<String> _unticked = {};
  bool _tried = false;

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    super.dispose();
  }

  List<String> _everyone(List<Pal> pals) => [
    ..._a.memberUids,
    for (final p in pals) p.id,
  ];

  List<String> _ticked(List<Pal> pals) => [
    for (final id in _everyone(pals))
      if (!_unticked.contains(id)) id,
  ];

  Set<TabProblem> _problems(List<Pal> pals) => tabProblems(
    adventure: _a,
    amountText: _amount.text,
    currency: _currency,
    date: _date,
    today: ref.read(todayProvider),
    category: _category,
    participants: _ticked(pals),
  );

  /// Moving on from the amount closes the keyboard, so the form stops
  /// scrolling back to the amount field on every change.
  void _doneTyping() => FocusScope.of(context).unfocus();

  Future<void> _pickDate() async {
    final today = ref.read(todayProvider);
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(today.year - 2),
      lastDate: today,
      helpText: 'Date of the tab',
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save(List<Pal> pals, String myUid) async {
    setState(() => _tried = true);
    final problems = _problems(pals);
    if (problems.contains(TabProblem.closed)) {
      showAuthMessage(context, _closedMessage);
      return;
    }
    if (problems.isNotEmpty) return;
    await ref
        .read(tabServiceProvider)
        .addTab(
          _a.id,
          NewTab(
            description: _description.text,
            category: _category!,
            amountMinor: parseAmount(_amount.text, _currency)!,
            currency: _currency,
            date: _date,
            payer: myUid,
            participants: _ticked(pals),
          ),
        );
    if (mounted) context.pop();
  }

  /// "฿300.00 each", or a range when the spare minor unit makes shares differ.
  String? _eachLabel(List<Pal> pals, String? symbol) {
    final minor = parseAmount(_amount.text, _currency);
    final ticked = _ticked(pals);
    if (minor == null || minor <= 0 || ticked.isEmpty) return null;
    final tab = NewTab(
      description: '',
      category: '',
      amountMinor: minor,
      currency: _currency,
      date: _date,
      payer: ticked.first,
      participants: ticked,
    );
    final shares = ticked.map(tab.shareOf).toList()..sort();
    String fmt(int m) => formatMoney(Money(m, _currency), symbol: symbol);
    return shares.first == shares.last
        ? '${fmt(shares.first)} each'
        : '${fmt(shares.first)}–${fmt(shares.last)} each';
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final myUid = ref.watch(sessionFactsProvider).value?.uid ?? '';
    final pals = ref.watch(palsProvider(_a.id)).value ?? const <Pal>[];
    final names =
        ref.watch(squadNamesProvider(_a.memberUids.join(','))).value ?? {};
    final countries = ref.watch(countriesProvider).value;
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final problems = _tried ? _problems(pals) : const <TabProblem>{};
    final each = _eachLabel(pals, countries?.symbolFor(_currency));

    String label(String id) {
      if (id == myUid) return '${names[id] ?? 'You'} (you)';
      return names[id] ??
          pals.where((p) => p.id == id).firstOrNull?.nickname ??
          '…';
    }

    return AuthScaffold(
      showBack: true,
      title: 'Add a tab',
      subtitle: _a.name,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _amount,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                    LengthLimitingTextInputFormatter(16),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    errorText: problems.contains(TabProblem.noAmount)
                        ? 'Enter an amount above zero.'
                        : problems.contains(TabProblem.tooBig)
                        ? 'That’s more than 10,000,000.'
                        : null,
                    errorMaxLines: 2,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  initialValue: _currency,
                  decoration: const InputDecoration(labelText: 'Currency'),
                  items: [
                    for (final c in {
                      _a.baseCurrency,
                      ...?countries?.currencies,
                    })
                      DropdownMenuItem(value: c, child: Text(c)),
                  ],
                  onChanged: (c) => setState(() => _currency = c ?? _currency),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _pickDate,
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Date',
                errorText: problems.contains(TabProblem.futureDate)
                    ? 'The date can’t be in the future.'
                    : null,
                suffixIcon: const Icon(Icons.event),
              ),
              child: Text(formatDay(_date)),
            ),
          ),
          const SizedBox(height: 16),
          Text('Category', style: text.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in categories)
                ChoiceChip(
                  label: Text('${c.emoji} ${c.name}'),
                  selected: _category == c.id,
                  onSelected: (_) {
                    _doneTyping();
                    setState(() => _category = c.id);
                  },
                ),
            ],
          ),
          if (problems.contains(TabProblem.noCategory))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Pick a category.',
                style: text.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          const SizedBox(height: 16),
          TextField(
            controller: _description,
            decoration: const InputDecoration(
              labelText: 'Description (optional)',
            ),
            textCapitalization: TextCapitalization.sentences,
            maxLength: 200,
          ),
          const SizedBox(height: 8),
          Text('Paid by', style: text.titleMedium),
          const SizedBox(height: 4),
          Text(
            'You paid it all',
            style: text.bodyLarge?.copyWith(color: RoamioColors.slate),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text('Split equally between', style: text.titleMedium),
              ),
              if (each != null)
                Text(
                  each,
                  style: text.bodyMedium?.copyWith(color: RoamioColors.slate),
                ),
            ],
          ),
          for (final id in _everyone(pals))
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: !_unticked.contains(id),
              title: Text(label(id)),
              subtitle: _a.memberUids.contains(id) ? null : const Text('Pal'),
              onChanged: (on) {
                _doneTyping();
                setState(
                  () => on ?? false ? _unticked.remove(id) : _unticked.add(id),
                );
              },
            ),
          if (problems.contains(TabProblem.nobodySharing))
            Text(
              'Tick at least one person.',
              style: text.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
        ],
      ),
      primary: PrimaryButton(
        label: 'Save tab',
        onPressed: () => _save(pals, myUid),
      ),
    );
  }
}

const _closedMessage =
    'Tabs closed 7 days after the trip ended, so this can’t be added.';
