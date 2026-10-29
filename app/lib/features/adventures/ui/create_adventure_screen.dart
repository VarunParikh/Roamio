import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:roamio/core/data/countries.dart';
import 'package:roamio/core/theme/roamio_colors.dart';
import 'package:roamio/core/ui/primary_button.dart';
import 'package:roamio/features/adventures/data/adventure_service.dart';
import 'package:roamio/features/adventures/domain/adventure.dart';
import 'package:roamio/features/adventures/ui/adventure_format.dart';
import 'package:roamio/features/auth/data/auth_service.dart';
import 'package:roamio/features/auth/ui/auth_scaffold.dart';

/// Start an adventure in three steps: where, what, when (UC-8). The
/// creator becomes Squad Leader.
class CreateAdventureScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<CreateAdventureScreen> createState() =>
      _CreateAdventureScreenState();
}

class _CreateAdventureScreenState extends ConsumerState<CreateAdventureScreen> {
  int _step = 0;
  Country? _country;
  String? _currency;
  final _city = TextEditingController();
  final _name = TextEditingController();
  final _description = TextEditingController();
  DateTime? _start;
  DateTime? _end;
  bool _tried = false;
  bool _busy = false;

  @override
  void dispose() {
    _city.dispose();
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Set<DraftProblem> get _problems => draftProblems(
    countryCode: _country?.code,
    name: _name.text,
    start: _start,
    end: _end,
  );

  /// The problems that belong to the current step.
  Set<DraftProblem> get _stepProblems => _problems.intersection(switch (_step) {
    0 => {DraftProblem.noCountry},
    1 => {DraftProblem.noName, DraftProblem.nameTooLong},
    _ => {DraftProblem.noDates, DraftProblem.endBeforeStart},
  });

  Future<void> _next() async {
    setState(() => _tried = true);
    if (_stepProblems.isNotEmpty) return;
    if (_step < 2) {
      setState(() {
        _step++;
        _tried = false;
      });
      return;
    }
    setState(() => _busy = true);
    try {
      final id = await ref
          .read(adventureServiceProvider)
          .create(
            AdventureDraft(
              name: _name.text,
              countryCode: _country!.code,
              city: _city.text,
              description: _description.text,
              startDate: _start!,
              endDate: _end!,
              baseCurrency: _currency ?? _country!.currency,
            ),
          );
      if (mounted) context.pushReplacement('/adventures/$id');
    } on Exception {
      if (mounted) {
        showAuthMessage(context, 'Couldn’t create it. Check your connection.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _back() {
    if (_step == 0) {
      context.pop();
    } else {
      setState(() {
        _step--;
        _tried = false;
      });
    }
  }

  Future<void> _pickCountry() async {
    final countries = await ref.read(countriesProvider.future);
    if (!mounted) return;
    final picked = await showModalBottomSheet<Country>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _CountrySheet(countries: countries),
    );
    if (picked != null) {
      setState(() {
        _country = picked;
        _currency = picked.currency;
      });
    }
  }

  Future<void> _pickDates() async {
    final today = ref.read(todayProvider);
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(today.year - 2),
      lastDate: DateTime(today.year + 3),
      initialDateRange: _start == null
          ? null
          : DateTimeRange(start: _start!, end: _end!),
      helpText: 'Trip dates',
    );
    if (range != null) {
      setState(() {
        _start = range.start;
        _end = range.end;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final problems = _tried ? _stepProblems : const <DraftProblem>{};
    final (title, subtitle, body) = switch (_step) {
      0 => (
        'Where to? 🌍',
        'Pick the country. We’ll grab a banner and the local currency.',
        _whereStep(problems),
      ),
      1 => (
        'Name your adventure',
        'Something the squad will recognise.',
        _nameStep(problems),
      ),
      _ => (
        'When’s it happening?',
        'You can change the dates later.',
        _whenStep(problems),
      ),
    };
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: AuthScaffold(
        showBack: true,
        title: title,
        subtitle: subtitle,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Step ${_step + 1} of 3',
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: RoamioColors.slate),
            ),
            const SizedBox(height: 12),
            body,
          ],
        ),
        primary: PrimaryButton(
          label: _step < 2 ? 'Next' : 'Create adventure',
          busy: _busy,
          onPressed: _next,
        ),
      ),
    );
  }

  Widget _whereStep(Set<DraftProblem> problems) => Column(
    children: [
      InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _pickCountry,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: 'Country',
            errorText: problems.contains(DraftProblem.noCountry)
                ? 'Choose a country.'
                : null,
            suffixIcon: const Icon(Icons.search),
          ),
          child: Text(
            _country == null
                ? 'Choose a country'
                : '${_country!.flag}  ${_country!.name}',
          ),
        ),
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _city,
        decoration: const InputDecoration(
          labelText: 'City or region (optional)',
        ),
        textCapitalization: TextCapitalization.words,
      ),
    ],
  );

  Widget _nameStep(Set<DraftProblem> problems) => Column(
    children: [
      TextField(
        controller: _name,
        decoration: InputDecoration(
          labelText: 'Adventure name',
          hintText: 'College group’s Bangkok adventure',
          errorText: problems.contains(DraftProblem.noName)
              ? 'Give it a name.'
              : problems.contains(DraftProblem.nameTooLong)
              ? 'Keep it under $maxAdventureName characters.'
              : null,
        ),
        textCapitalization: TextCapitalization.sentences,
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _description,
        decoration: const InputDecoration(labelText: 'Description (optional)'),
        maxLines: 3,
        maxLength: 500,
      ),
    ],
  );

  Widget _whenStep(Set<DraftProblem> problems) {
    final currencies =
        ref.watch(countriesProvider).value?.currencies ?? const <String>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _pickDates,
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: 'Dates',
              errorText: problems.contains(DraftProblem.noDates)
                  ? 'Choose the dates.'
                  : problems.contains(DraftProblem.endBeforeStart)
                  ? 'The end can’t be before the start.'
                  : null,
              suffixIcon: const Icon(Icons.date_range),
            ),
            child: Text(
              _start == null ? 'Choose dates' : formatDateRange(_start!, _end!),
            ),
          ),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _currency,
          decoration: const InputDecoration(
            labelText: 'Trip currency',
            helperText:
                'Set from the country. Tabs can still be in any currency.',
            helperMaxLines: 2,
          ),
          items: [
            for (final c in currencies)
              DropdownMenuItem(value: c, child: Text(c)),
          ],
          onChanged: (c) => setState(() => _currency = c),
        ),
      ],
    );
  }
}

class _CountrySheet extends StatefulWidget {
  const new({required this.countries});

  final Countries countries;

  @override
  State<_CountrySheet> createState() => _CountrySheetState();
}

class _CountrySheetState extends State<_CountrySheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final results = widget.countries.search(_query);
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.8,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Search countries',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: results.isEmpty
                ? const Center(child: Text('No country matches that.'))
                : ListView.builder(
                    itemCount: results.length,
                    itemBuilder: (_, i) {
                      final c = results[i];
                      return ListTile(
                        leading: Text(
                          c.flag,
                          style: const TextStyle(fontSize: 24),
                        ),
                        title: Text(c.name),
                        trailing: Text(c.currency),
                        onTap: () => Navigator.pop(context, c),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
