import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:roamio/core/config/phase2.dart';
import 'package:roamio/core/data/categories.dart';
import 'package:roamio/core/data/countries.dart';
import 'package:roamio/core/images/photo_pipeline.dart';
import 'package:roamio/core/images/upload_queue.dart';
import 'package:roamio/core/location/location_service.dart';
import 'package:roamio/core/theme/roamio_colors.dart';
import 'package:roamio/core/ui/primary_button.dart';
import 'package:roamio/features/adventures/data/adventure_service.dart';
import 'package:roamio/features/adventures/domain/adventure.dart';
import 'package:roamio/features/adventures/ui/adventure_format.dart';
import 'package:roamio/features/adventures/ui/adventure_page.dart';
import 'package:roamio/features/auth/data/auth_service.dart';
import 'package:roamio/features/auth/domain/age.dart';
import 'package:roamio/features/auth/ui/auth_scaffold.dart';
import 'package:roamio/features/splits/data/fx_repository.dart';
import 'package:roamio/features/splits/domain/money.dart';
import 'package:roamio/features/splits/domain/tab_models.dart';
import 'package:roamio/features/squad/data/squad_service.dart';
import 'package:roamio/features/squad/ui/pals.dart';
import 'package:roamio/features/squad/ui/person.dart';
import 'package:roamio/features/tabs/data/payment_memory.dart';
import 'package:roamio/features/tabs/data/receipt_parser.dart';
import 'package:roamio/features/tabs/data/receipt_scanner.dart';
import 'package:roamio/features/tabs/data/tab_service.dart';
import 'package:roamio/features/tabs/domain/new_tab.dart';
import 'package:roamio/features/tabs/domain/payment_method.dart';
import 'package:roamio/features/tabs/domain/tab_approval.dart';
import 'package:roamio/features/tabs/domain/tab_list.dart';
import 'package:roamio/features/tabs/ui/location_picker.dart';
import 'package:roamio/features/tabs/ui/memories.dart';
import 'package:roamio/features/tabs/ui/payers_editor.dart';
import 'package:roamio/features/tabs/ui/percent_editor.dart';
import 'package:roamio/features/tabs/ui/tabs_section.dart';

/// Add a tab (spec UC-21): who paid (you, or split between members), how
/// it's shared (equal or custom %), up to 4 photos and, for adults, where
/// it happened. Leads can add a pal on the spot.
class AddTabScreen extends ConsumerWidget {
  const new({required this.adventureId, this.tabId, super.key});

  final String adventureId;

  /// Set when the creator edits an existing tab (spec UC-22).
  final String? tabId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adventure = ref
        .watch(myAdventuresProvider)
        .value
        ?.where((a) => a.id == adventureId)
        .firstOrNull;
    final existing = tabId == null
        ? null
        : ref.watch(tabProvider((adventureId, tabId!)));
    if (adventure == null) {
      return AdventureUnavailable(
        loading: ref.watch(myAdventuresProvider).isLoading,
      );
    }
    if (existing?.isLoading ?? false) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (existing != null && (existing.value?.deleted ?? true)) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('This tab isn’t available.')),
      );
    }
    return _AddTabForm(adventure: adventure, existing: existing?.value);
  }
}

class _AddTabForm extends ConsumerStatefulWidget {
  const new({required this.adventure, this.existing});

  final Adventure adventure;
  final TabEntry? existing;

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
  bool _busy = false;

  /// Photos picked so far, uploaded once the tab is saved.
  final List<String> _memories = [];
  MapPoint? _location;

  /// Amount per member once "Split payment" is on; null when you paid it all.
  Map<String, TextEditingController>? _payerFields;

  /// Percentage per participant in Custom % mode; null for Equal.
  Map<String, TextEditingController>? _percentFields;

  /// How each payer paid, once chosen or from the tab being edited. Anyone
  /// else starts on [_lastUsed].
  final Map<String, PaymentMethod> _methods = {};

  /// The method last used on this phone; null the first time.
  PaymentMethod? _lastUsed;
  bool _recalled = false;

  PaymentMethod? _methodOf(String id) => _methods[id] ?? _lastUsed;

  /// Who paid, as the form stands.
  List<String> _payerIds(String myUid) => switch (_texts(_payerFields)) {
    final texts? => [for (final p in payersFrom(texts, _currency)) p.payer],
    null => [_old?.createdBy ?? myUid],
  };

  void _setMethod(String id, PaymentMethod method) {
    _doneTyping();
    setState(() => _methods[id] = method);
  }

  /// Shown after Custom % went back to Equal because the people changed.
  bool _resetToEqual = false;

  late final TabEntry? _old = widget.existing;

  /// People on the tab being edited who have since left the squad (not a
  /// member or current pal); they stay listed so saving doesn't drop them
  /// (spec UC-16).
  List<String> _former(List<Pal> pals) => [
    for (final id in {
      ...?_old?.split.participants,
      ...?_old?.split.payers.map((p) => p.payer),
    })
      if (!_a.memberUids.contains(id) && !pals.any((p) => p.id == id)) id,
  ];

  @override
  void initState() {
    super.initState();
    ref.read(paymentMemoryProvider).read().then((method) {
      if (!mounted) return;
      setState(() {
        _lastUsed = method;
        _recalled = true;
      });
    }).ignore();
    final old = _old;
    if (old == null) return;
    _methods.addAll({for (final p in old.split.payers) p.payer: p.method});
    final currency = old.amount.currency;
    _amount.text = amountText(old.amount.minor, currency);
    _description.text = old.description;
    _currency = currency;
    _date = old.date;
    _category = old.category;
    _location = old.location;
    final payers = old.split.payers;
    if (payers.length > 1 || payers.single.payer != old.createdBy) {
      final paid = {for (final p in payers) p.payer: p.amountMinor};
      _payerFields = {
        for (final id in {..._a.memberUids, ...paid.keys})
          id: TextEditingController(
            text: paid[id] == null ? '' : amountText(paid[id]!, currency),
          ),
      };
    }
    if (old.split.percentBp case final percent?) {
      _percentFields = {
        for (final id in old.split.participants)
          id: TextEditingController(
            text: formatBasisPoints(percent[id] ?? 0).replaceAll('%', ''),
          ),
      };
    }
  }

  /// Untick everyone the edited tab didn't include, once pals are known.
  bool _untickedFromOld = false;

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    _disposeAll(_payerFields);
    _disposeAll(_percentFields);
    super.dispose();
  }

  static void _disposeAll(Map<String, TextEditingController>? fields) {
    for (final f in fields?.values ?? const <TextEditingController>[]) {
      f.dispose();
    }
  }

  static Map<String, String>? _texts(Map<String, TextEditingController>? f) =>
      f?.map((id, c) => MapEntry(id, c.text));

  void _splitPayment(String myUid) => setState(() {
    final minor = parseAmount(_amount.text, _currency);
    _payerFields = {
      for (final id in _a.memberUids)
        id: TextEditingController(
          text: id == myUid && minor != null ? _amount.text.trim() : '',
        ),
    };
  });

  void _justMe() => setState(() {
    _disposeAll(_payerFields);
    _payerFields = null;
  });

  void _setCustom(bool custom, List<Pal> pals) => setState(() {
    _resetToEqual = false;
    _disposeAll(_percentFields);
    _percentFields = custom
        ? {
            for (final MapEntry(:key, :value) in equalPercents(
              _ticked(pals),
            ).entries)
              key: TextEditingController(
                text: formatBasisPoints(value).replaceAll('%', ''),
              ),
          }
        : null;
  });

  /// The people sharing changed: custom percentages no longer fit, so go
  /// back to Equal and say so (spec UC-22).
  void _peopleChanged() {
    if (_percentFields == null) return;
    _disposeAll(_percentFields);
    _percentFields = null;
    _resetToEqual = true;
  }

  Future<void> _addPal() async {
    final added = await showPalForm(context, adventure: _a);
    if (added && mounted) setState(_peopleChanged);
  }

  List<String> _everyone(List<Pal> pals) => [
    ..._a.memberUids,
    for (final p in pals) p.id,
    ..._former(pals),
  ];

  List<String> _ticked(List<Pal> pals) => [
    for (final id in _everyone(pals))
      if (!_unticked.contains(id)) id,
  ];

  Set<TabProblem> _problems(List<Pal> pals, String myUid) => tabProblems(
    adventure: _a,
    amountText: _amount.text,
    currency: _currency,
    date: _date,
    today: ref.read(todayProvider),
    category: _category,
    participants: _ticked(pals),
    payerTexts: _texts(_payerFields),
    percentTexts: _texts(_percentFields),
    paymentMethods: _payerIds(myUid).map(_methodOf).toList(),
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

  /// The day of the latest exchange rates known for the tab's date, which
  /// the tab keeps (spec §9.1). Offline it's whatever the phone has seen;
  /// it never holds up saving for long.
  Future<String?> _ratesDay() async {
    final provider = fxRatesProvider(isoDate(_date));
    final known = ref.read(provider);
    if (known.hasValue) return known.value?.date;
    try {
      final rates = await ref
          .read(provider.future)
          .timeout(const Duration(seconds: 2), onTimeout: () => null);
      return rates?.date;
    } on Exception {
      return null;
    }
  }

  Future<void> _save(List<Pal> pals, String myUid) async {
    setState(() => _tried = true);
    final problems = _problems(pals, myUid);
    if (problems.contains(TabProblem.closed)) {
      showAuthMessage(context, _closedMessage);
      return;
    }
    if (problems.isNotEmpty) return;
    setState(() => _busy = true);
    final ratesDay = await _ratesDay();
    if (!mounted) return;
    final tabs = ref.read(tabServiceProvider);
    final memory = ref.read(paymentMemoryProvider);
    final old0 = _old;
    final payers = _payerFields == null
        ? [
            Payment(
              _old?.createdBy ?? myUid,
              parseAmount(_amount.text, _currency)!,
              method: _methodOf(_old?.createdBy ?? myUid)!,
            ),
          ]
        : payersFrom(_texts(_payerFields)!, _currency, methodOf: _methodOf);
    final sharing = _ticked(pals);
    final tab = NewTab(
      status: old0 == null
          ? statusForNewTab(_a, myUid, payers, sharing)
          : statusForEditedTab(
              _a,
              myUid,
              old0,
              amountMinor: parseAmount(_amount.text, _currency)!,
              currency: _currency,
              payers: payers,
              sharing: sharing,
              percentBp: _percentFields == null
                  ? null
                  : percentsFrom(_texts(_percentFields)!),
            ),
      description: _description.text,
      category: _category!,
      amountMinor: parseAmount(_amount.text, _currency)!,
      currency: _currency,
      date: _date,
      payers: payers,
      percentBp: _percentFields == null
          ? null
          : percentsFrom(_texts(_percentFields)!),
      participants: sharing,
      location: _location,
      basedOn: _old?.updatedAt,
      fxDate: fxDateFor(
        date: _date,
        ratesDay: ratesDay,
        previous: old0 == null
            ? null
            : (date: old0.date, fxDate: old0.split.fxDate),
      ),
    );
    final old = _old;
    final String id;
    if (old == null) {
      id = await tabs.addTab(_a.id, tab);
      // Only a new tab counts as using a method; fixing an old one doesn't.
      await memory.write(rememberedMethod(tab.payers, myUid));
    } else {
      id = old.id;
      await tabs.updateTab(_a.id, id, tab);
    }
    // Compressed now and queued, so they upload even if the phone is offline.
    final photos = ref.read(photoPipelineProvider);
    final tabPath = 'adventures/${_a.id}/tabs/$id';
    var unreadable = 0;
    for (final path in _memories) {
      try {
        await photos.queueUpload(
          path: path,
          kind: _billPaths.contains(path) ? PhotoKind.bill : PhotoKind.photo,
          storageDir: tabPath,
          docPath: tabPath,
          field: 'memories',
          mode: UploadMode.append,
        );
      } on FormatException {
        unreadable++;
      }
    }
    if (!mounted) return;
    if (unreadable > 0) {
      showAuthMessage(
        context,
        'Tab saved, but $unreadable photo(s) couldn’t be read.',
      );
    }
    context.pop();
  }

  /// Photos taken with Scan bill; kept at the larger bill size (spec §10).
  final Set<String> _billPaths = {};
  bool _scanning = false;

  /// What Scan bill managed, shown under its button (a snackbar would
  /// cover Save).
  String? _scanNote;

  /// Reads a bill photo on the phone and fills in what it finds; the
  /// person checks it before saving (spec UC-21).
  Future<void> _scanBill() async {
    _doneTyping();
    final photos = ref.read(photoPipelineProvider);
    final path = await photos.pick(camera: true);
    if (path == null || !mounted) return;
    setState(() => _scanning = true);
    ReceiptGuess guess;
    try {
      final text = await ref.read(receiptScannerProvider).readText(path);
      guess = parseReceipt(
        text,
        currency: _currency,
        today: ref.read(todayProvider),
      );
    } on Exception {
      guess = const ReceiptGuess();
    }
    final keep =
        ref.read(photoUploadsEnabledProvider) &&
        !guess.isEmpty &&
        _memories.length < maxMemories;
    if (!mounted) {
      await photos.discard(path);
      return;
    }
    setState(() {
      _scanning = false;
      _scanNote = guess.isEmpty
          ? 'Couldn’t read that bill. Please fill it in.'
          : 'Check the amount, date and name we read.';
      if (guess.amountMinor case final minor?) {
        _amount.text = amountText(minor, _currency);
      }
      if (guess.date case final date?) _date = date;
      if (guess.merchant case final name? when _description.text.isEmpty) {
        _description.text = name;
      }
      if (keep) {
        _memories.add(path);
        _billPaths.add(path);
      }
    });
    // Read on the phone, and kept only if it'll go up with the tab (spec §10).
    if (!keep) await photos.discard(path);
  }

  Future<void> _addPhoto(bool camera) async {
    final path = await ref.read(photoPipelineProvider).pick(camera: camera);
    if (path != null && mounted) setState(() => _memories.add(path));
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
      payers: [Payment(ticked.first, minor)],
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
    // Look up the rates for the tab's day early, so saving has them.
    ref.watch(fxRatesProvider(isoDate(_date)));
    final text = Theme.of(context).textTheme;
    final myUid = ref.watch(sessionFactsProvider).value?.uid ?? '';
    final palsState = ref.watch(palsProvider(_a.id));
    final pals = palsState.value ?? const <Pal>[];
    if (_old case final old? when !_untickedFromOld && palsState.hasValue) {
      _untickedFromOld = true;
      _unticked.addAll(
        _everyone(pals).where((id) => !old.split.participants.contains(id)),
      );
    }
    final names = squadLabels(ref, _a);
    final countries = ref.watch(countriesProvider).value;
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final now = _problems(pals, myUid);
    final problems = _tried ? now : const <TabProblem>{};
    // Save waits until split payments and custom percentages add up (UC-21).
    final blocked =
        (_payerFields != null && now.contains(TabProblem.paymentsDontAddUp)) ||
        (_percentFields != null &&
            now.contains(TabProblem.percentagesDontAddUp)) ||
        now.contains(TabProblem.noPaymentMethod);
    final symbol = countries?.symbolFor(_currency);
    final each = _eachLabel(pals, countries?.symbolFor(_currency));

    final people = squadPeople(ref, _a);
    String label(String id) {
      if (id == myUid) return '${names[id] ?? 'You'} (you)';
      return names[id] ?? '…';
    }

    return AuthScaffold(
      showBack: true,
      title: _old == null ? 'Add a tab' : 'Edit tab',
      subtitle: _a.name,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_old == null && ref.watch(ocrEnabledProvider)) ...[
            OutlinedButton.icon(
              onPressed: _scanning ? null : _scanBill,
              icon: _scanning
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.document_scanner_outlined),
              label: const Text('Scan bill'),
            ),
            if (_scanNote case final note?)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  note,
                  style: text.bodyMedium?.copyWith(color: RoamioColors.slate),
                ),
              ),
            const SizedBox(height: 16),
          ],
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
          if (ref.watch(photoUploadsEnabledProvider)) ...[
            Text('Photos', style: text.titleMedium),
            const SizedBox(height: 8),
            MemoriesPicker(
              paths: _memories,
              alreadySaved: _old?.memories.length ?? 0,
              onAdd: _addPhoto,
              onRemove: (i) => setState(() => _memories.removeAt(i)),
            ),
            const SizedBox(height: 16),
          ],
          LocationPicker(
            point: _location,
            onChanged: (p) => setState(() => _location = p),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: Text('Paid by', style: text.titleMedium)),
              TextButton(
                onPressed: () =>
                    _payerFields == null ? _splitPayment(myUid) : _justMe(),
                child: Text(_payerFields == null ? 'Split payment' : 'Just me'),
              ),
            ],
          ),
          if (_payerFields case final fields?)
            PayersEditor(
              fields: fields,
              labels: {for (final id in fields.keys) id: label(id)},
              people: people,
              currency: _currency,
              amountMinor: parseAmount(_amount.text, _currency) ?? 0,
              symbol: symbol,
              onChanged: () => setState(() {}),
              methodOf: _methodOf,
              onMethod: _setMethod,
            )
          else ...[
            Text(
              'You paid it all',
              style: text.bodyLarge?.copyWith(color: RoamioColors.slate),
            ),
            const SizedBox(height: 12),
            PaidWithDropdown(
              payerId: _old?.createdBy ?? myUid,
              value: _methodOf(_old?.createdBy ?? myUid),
              onChanged: (m) => _setMethod(_old?.createdBy ?? myUid, m),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: Text('Split between', style: text.titleMedium)),
              if (each != null && _percentFields == null)
                Text(
                  each,
                  style: text.bodyMedium?.copyWith(color: RoamioColors.slate),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Equal')),
              ButtonSegment(value: true, label: Text('Custom %')),
            ],
            selected: {_percentFields != null},
            onSelectionChanged: (s) {
              _doneTyping();
              _setCustom(s.single, pals);
            },
          ),
          if (_resetToEqual)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Split reset to equal because the people changed.',
                style: text.bodyMedium?.copyWith(color: RoamioColors.coralText),
              ),
            ),
          for (final id in _everyone(pals))
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: !_unticked.contains(id),
              secondary: PersonAvatar(uid: id, person: people[id]),
              title: Text(label(id)),
              subtitle: _a.memberUids.contains(id) ? null : const Text('Pal'),
              onChanged: (on) {
                _doneTyping();
                setState(() {
                  on ?? false ? _unticked.remove(id) : _unticked.add(id);
                  _peopleChanged();
                });
              },
            ),
          if (_ticked(pals).length == 1 &&
              _ticked(pals).single == myUid &&
              _payerFields == null)
            Text(
              'Personal tab: only you can see it, and it needs no approval.',
              style: text.bodySmall?.copyWith(color: RoamioColors.slate),
            ),
          if (problems.contains(TabProblem.nobodySharing))
            Text(
              'Tick at least one person.',
              style: text.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          if (_a.isLead(myUid))
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _addPal,
                icon: const Icon(Icons.person_add_alt),
                label: const Text('Add pal'),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Need someone without the app? Ask a squad lead to add them.',
                style: text.bodyMedium?.copyWith(color: RoamioColors.slate),
              ),
            ),
          if (_percentFields case final fields?) ...[
            const SizedBox(height: 8),
            PercentEditor(
              fields: fields,
              labels: {for (final id in fields.keys) id: label(id)},
              people: people,
              onChanged: () => setState(() {}),
            ),
          ],
        ],
      ),
      primary: PrimaryButton(
        label: _old == null ? 'Save tab' : 'Save changes',
        busy: _busy,
        onPressed: blocked ? null : () => _save(pals, myUid),
      ),
      // Beside Save, since the dropdown may be far up the form.
      footer: _recalled && now.contains(TabProblem.noPaymentMethod)
          ? Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _payerFields == null
                    ? 'Choose how this was paid to save the tab.'
                    : 'Choose how each person paid to save the tab.',
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(color: RoamioColors.coralText),
              ),
            )
          : null,
    );
  }
}

const _closedMessage =
    'Tabs closed 7 days after the trip ended, so this can’t be added.';
