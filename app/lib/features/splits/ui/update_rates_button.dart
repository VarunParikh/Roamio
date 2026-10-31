import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:roamio/features/auth/domain/age.dart';
import 'package:roamio/features/auth/ui/auth_scaffold.dart';
import 'package:roamio/features/auth/ui/dob_field.dart';
import 'package:roamio/features/splits/data/fx_repository.dart';
import 'package:roamio/features/sync/sync_controller.dart';

/// A small button that fetches the latest exchange rates (spec §9.1). Tabs
/// keep their own rate day, so this fills in what's missing rather than
/// changing a total that's already converted. It needs a connection.
class UpdateRatesButton extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<UpdateRatesButton> createState() => _UpdateRatesButtonState();
}

class _UpdateRatesButtonState extends ConsumerState<UpdateRatesButton> {
  bool _busy = false;

  Future<void> _update() async {
    setState(() => _busy = true);
    String message;
    try {
      final day = await ref.read(fxRepositoryProvider).refreshLatest();
      ref.invalidate(fxRatesProvider);
      message = day == null
          ? 'No exchange rates available yet. Try again later.'
          : 'Rates updated: ${formatDate(parseIsoDate(day))}.';
    } on Exception {
      message = 'Couldn’t get the latest rates. Try again.';
    }
    if (!mounted) return;
    setState(() => _busy = false);
    showAuthMessage(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final offline = ref.watch(isOfflineProvider);
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          visualDensity: VisualDensity.compact,
        ),
        onPressed: _busy || offline ? null : _update,
        icon: _busy
            ? const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.currency_exchange, size: 16),
        label: const Text('Update rates'),
      ),
    );
  }
}
