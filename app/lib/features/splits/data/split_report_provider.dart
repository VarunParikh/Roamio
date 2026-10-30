import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:roamio/features/adventures/data/adventure_service.dart';
import 'package:roamio/features/auth/data/auth_service.dart';
import 'package:roamio/features/profile/data/profile_service.dart';
import 'package:roamio/features/splits/data/fx_repository.dart';
import 'package:roamio/features/splits/data/settlement_service.dart';
import 'package:roamio/features/splits/domain/fx_converter.dart';
import 'package:roamio/features/splits/domain/split_report.dart';
import 'package:roamio/features/tabs/data/tab_service.dart';

/// One adventure's split for the signed-in person, in their profile
/// currency, each tab converted at its own day's rates (spec UC-25, UC-26).
final ProviderFamily<AsyncValue<SplitReport>, String> splitReportProvider =
    Provider.family<AsyncValue<SplitReport>, String>((ref, adventureId) {
      final currency = ref.watch(profileCurrencyProvider);
      if (!currency.hasValue) return const AsyncLoading();
      return ref.watch(reportInProvider((adventureId, currency.value!)));
    });

/// The same split in any currency, e.g. a budget's (spec UC-20).
final ProviderFamily<AsyncValue<SplitReport>, (String, String)>
reportInProvider = Provider.family<AsyncValue<SplitReport>, (String, String)>((
  ref,
  key,
) {
  final (adventureId, viewerCurrency) = key;
  final adventure = ref
      .watch(myAdventuresProvider)
      .value
      ?.where((a) => a.id == adventureId)
      .firstOrNull;
  final tabs = ref.watch(tabsProvider(adventureId));
  final viewer = ref.watch(sessionFactsProvider).value?.uid;
  final settled = ref.watch(settlementsProvider(adventureId));
  // A failed load is an error, not endless loading (spec §12: no dead ends).
  if (tabs case AsyncError(:final error, :final stackTrace)) {
    return AsyncError(error, stackTrace);
  }
  if (settled case AsyncError(:final error, :final stackTrace)) {
    return AsyncError(error, stackTrace);
  }
  if (adventure == null ||
      viewer == null ||
      !tabs.hasValue ||
      !settled.hasValue) {
    return const AsyncLoading();
  }
  final rates = <String, FxRates?>{};
  for (final date in {
    for (final t in tabs.value!) t.split.fxDate,
    for (final s in settled.value!) s.date,
  }) {
    final day = ref.watch(fxRatesProvider(date));
    if (day.isLoading) return const AsyncLoading();
    rates[date] = day.value;
  }
  return AsyncData(
    buildReport(
      tabs: [
        for (final t in tabs.value!)
          ReportTab(
            category: t.category,
            date: t.date,
            split: t.split,
            status: t.status,
          ),
      ],
      baseCurrency: adventure.baseCurrency,
      viewerCurrency: viewerCurrency,
      viewer: viewer,
      ratesFor: (date) =>
          rates[date] ?? FxRates(date: date, usdRates: const {}),
      settlements: [
        for (final s in settled.value!)
          ReportSettlement(
            from: s.from,
            to: s.to,
            amountMinor: s.amountMinor,
            date: s.date,
          ),
      ],
    ),
  );
});
