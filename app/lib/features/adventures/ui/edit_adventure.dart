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

/// Leads edit an adventure's details (UC-10). The country is fixed, and
/// the trip currency locks once a tab exists.
class EditAdventureScreen extends ConsumerWidget {
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
    return _EditForm(adventure: adventure);
  }
}

class _EditForm extends ConsumerStatefulWidget {
  const new({required this.adventure});

  final Adventure adventure;

  @override
  ConsumerState<_EditForm> createState() => _EditFormState();
}

class _EditFormState extends ConsumerState<_EditForm> {
  late final Adventure _a = widget.adventure;
  late final _name = TextEditingController(text: _a.name);
  late final _description = TextEditingController(text: _a.description);
  late final _city = TextEditingController(text: _a.city);
  late DateTime _start = _a.startDate;
  late DateTime _end = _a.endDate;
  late String _currency = _a.baseCurrency;
  bool _tried = false;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _city.dispose();
    super.dispose();
  }

  Set<DraftProblem> get _problems => draftProblems(
    countryCode: _a.countryCode,
    name: _name.text,
    start: _start,
    end: _end,
  );

  Future<void> _pickDates() async {
    final today = ref.read(todayProvider);
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(today.year - 2),
      lastDate: DateTime(today.year + 3),
      initialDateRange: DateTimeRange(start: _start, end: _end),
      helpText: 'Trip dates',
    );
    if (range != null) {
      setState(() {
        _start = range.start;
        _end = range.end;
      });
    }
  }

  Future<void> _save() async {
    setState(() => _tried = true);
    if (_problems.isNotEmpty) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(adventureServiceProvider)
          .update(
            _a.id,
            AdventureEdit(
              name: _name.text,
              description: _description.text,
              city: _city.text,
              startDate: _start,
              endDate: _end,
              baseCurrency: _a.currencyLocked ? null : _currency,
            ),
          );
      if (mounted) context.pop();
    } on Exception {
      if (mounted) {
        showAuthMessage(context, 'Couldn’t save. Check your connection.');
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final problems = _tried ? _problems : const <DraftProblem>{};
    final countries = ref.watch(countriesProvider).value;
    final country = countries?.byCode(_a.countryCode);
    final currencies = countries?.currencies ?? [_a.baseCurrency];
    return AuthScaffold(
      showBack: true,
      title: 'Edit adventure',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Country',
              helperText: 'The country can’t be changed.',
            ),
            child: Text(
              country == null
                  ? _a.countryCode
                  : '${country.flag}  ${country.name}',
              style: const TextStyle(color: RoamioColors.slate),
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
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            decoration: InputDecoration(
              labelText: 'Adventure name',
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
            decoration: const InputDecoration(
              labelText: 'Description (optional)',
            ),
            maxLines: 3,
            maxLength: 500,
          ),
          const SizedBox(height: 8),
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _pickDates,
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Dates',
                errorText: problems.contains(DraftProblem.endBeforeStart)
                    ? 'The end can’t be before the start.'
                    : null,
                suffixIcon: const Icon(Icons.date_range),
              ),
              child: Text(formatDateRange(_start, _end)),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _currency,
            decoration: InputDecoration(
              labelText: 'Trip currency',
              helperText: _a.currencyLocked
                  ? 'Locked because the squad has added tabs.'
                  : 'Tabs can still be in any currency.',
              helperMaxLines: 2,
            ),
            items: [
              for (final c in {...currencies, _a.baseCurrency})
                DropdownMenuItem(value: c, child: Text(c)),
            ],
            onChanged: _a.currencyLocked
                ? null
                : (c) => setState(() => _currency = c ?? _currency),
          ),
        ],
      ),
      primary: PrimaryButton(
        label: 'Save changes',
        busy: _busy,
        onPressed: _save,
      ),
    );
  }
}
