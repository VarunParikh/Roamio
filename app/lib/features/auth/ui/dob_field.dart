import 'package:flutter/material.dart';
import 'package:roamio/features/auth/domain/age.dart';

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String formatDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

/// Validation message for a date of birth, or null when it can be used.
String? dobMessage(DateTime? dob, DateTime today) {
  final problem = dobProblem(dob, today);
  if (problem != null) {
    return switch (problem) {
      DobProblem.missing => 'Add your date of birth.',
      DobProblem.inFuture => 'That date is in the future.',
      DobProblem.tooOld => 'Check the year: that’s over 120 years ago.',
    };
  }
  return bracketFor(dob!, today) == AgeBracket.underThirteen
      ? 'Roamio is for people aged 13 and over.'
      : null;
}

/// A tappable date-of-birth field backed by the Material date picker.
class DobField extends StatelessWidget {
  const new({
    required this.value,
    required this.onChanged,
    required this.today,
    this.errorText,
    super.key,
  });

  final DateTime? value;
  final ValueChanged<DateTime> onChanged;
  final DateTime today;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate:
              value ?? DateTime(today.year - 18, today.month, today.day),
          firstDate: DateTime(today.year - 120, today.month, today.day),
          lastDate: today,
          initialEntryMode: DatePickerEntryMode.input,
          helpText: 'Your date of birth',
        );
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Date of birth',
          errorText: errorText,
          helperText:
              'We use this to keep under-18s safe. It’s never shown to anyone.',
          helperMaxLines: 2,
          suffixIcon: const Icon(Icons.cake_outlined),
        ),
        child: Text(value == null ? 'Choose a date' : formatDate(value!)),
      ),
    );
  }
}
