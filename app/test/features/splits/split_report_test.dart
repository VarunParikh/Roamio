import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/features/splits/domain/fx_converter.dart';
import 'package:roamio/features/splits/domain/money.dart';
import 'package:roamio/features/splits/domain/split_report.dart';
import 'package:roamio/features/splits/domain/tab_models.dart';

/// Spec §6 worked example: ₹3,000 paid by Ari ₹2,000 + Ben ₹1,000; shares
/// Ari 50%, Ben 25%, pal Kiko 25%.
final _dinner = ReportTab(
  category: 'food_dining',
  date: DateTime(2026, 10, 27),
  split: TabSplit(
    amount: Money(300000, 'INR'),
    payers: const [Payment('ari', 200000), Payment('ben', 100000)],
    participants: const ['ari', 'ben', 'kiko'],
    percentBp: const {'ari': 5000, 'ben': 2500, 'kiko': 2500},
    fxDate: '2026-10-27',
  ),
);

/// ฿1,200 taxi on 28 Oct, Ben paid, shared by Ari and Ben.
final _taxi = ReportTab(
  category: 'local_transportation',
  date: DateTime(2026, 10, 28),
  split: TabSplit(
    amount: Money(120000, 'THB'),
    payers: const [Payment('ben', 120000)],
    participants: const ['ari', 'ben'],
    fxDate: '2026-10-28',
  ),
);

/// 84 INR and 35 THB per USD on both days.
FxRates _rates(String date) =>
    FxRates(date: date, usdRates: const {'INR': '84', 'THB': '35'});

void main() {
  group('buildReport (spec §6, UC-25, UC-26)', () {
    test('skips a broken tab instead of failing (follow-up C5)', () {
      // A tab the server will reject (payments don't add up), still in the
      // phone's offline cache for a moment.
      final broken = ReportTab(
        category: 'food_dining',
        date: DateTime(2026, 10, 27),
        split: TabSplit(
          amount: Money(300000, 'INR'),
          payers: const [Payment('ari', 1)],
          participants: const ['ari', 'ben'],
          fxDate: '2026-10-27',
        ),
      );
      final r = buildReport(
        tabs: [_dinner, broken],
        baseCurrency: 'INR',
        viewerCurrency: 'INR',
        viewer: 'ari',
        ratesFor: _rates,
      );
      expect(r.balances, {'ari': 50000, 'ben': 25000, 'kiko': -75000});
      expect(r.totalSpend, 300000);
    });

    group('settled in the trip’s currency (follow-up C7)', () {
      // Settled on 29 Oct, when the baht moved: each item converts at its
      // own day's rate, so the baht amounts no longer cancel exactly.
      FxRates moved(String date) => date == '2026-10-29'
          ? FxRates(date: date, usdRates: const {'INR': '84', 'THB': '36'})
          : _rates(date);
      ReportSettlement paid(String from, String to, int minor) =>
          ReportSettlement(
            from: from,
            to: to,
            amountMinor: minor,
            date: '2026-10-29',
          );

      test('everyone square in rupees is square in every currency', () {
        final r = buildReport(
          tabs: [_dinner, _taxi],
          baseCurrency: 'INR',
          viewerCurrency: 'THB',
          viewer: 'ari',
          ratesFor: moved,
          settlements: [paid('ari', 'ben', 94000), paid('kiko', 'ben', 75000)],
        );
        expect(r.baseBalances.values.every((b) => b == 0), isTrue);
        expect(r.balances.values.every((b) => b == 0), isTrue);
        expect(r.mine, 0);
        expect(r.transfers, isEmpty);
        expect(headline(r.mine, r.currency, '฿'), 'All square 🎉');
      });

      test('someone who is square shows square; the total stays zero', () {
        final r = buildReport(
          tabs: [_dinner, _taxi],
          baseCurrency: 'INR',
          viewerCurrency: 'THB',
          viewer: 'kiko',
          ratesFor: moved,
          settlements: [paid('kiko', 'ben', 75000)],
        );
        expect(r.baseBalances['kiko'], 0);
        expect(r.balances['kiko'], 0);
        expect(r.mine, 0);
        expect(r.balances.values.fold(0, (a, b) => a + b), 0);
        expect(
          r.transfers.where((t) => t.from == 'kiko' || t.to == 'kiko'),
          isEmpty,
        );
      });
    });

    test('the worked example: balances, headline and who pays whom', () {
      final r = buildReport(
        tabs: [_dinner],
        baseCurrency: 'INR',
        viewerCurrency: 'INR',
        viewer: 'ari',
        ratesFor: _rates,
      );
      expect(r.currency, 'INR');
      expect(r.balances, {'ari': 50000, 'ben': 25000, 'kiko': -75000});
      expect(r.balances.values.fold(0, (a, b) => a + b), 0);
      expect(r.mine, 50000);
      expect(r.transfers.map((t) => (t.from, t.to, t.amount.minor)), [
        ('kiko', 'ari', 50000),
        ('kiko', 'ben', 25000),
      ]);
      expect(r.baseBalances['ari'], 50000);
    });

    test('everything in the viewer’s currency, each tab at its own date', () {
      final r = buildReport(
        tabs: [_dinner, _taxi],
        baseCurrency: 'INR',
        viewerCurrency: 'THB',
        viewer: 'ari',
        ratesFor: _rates,
      );
      expect(r.currency, 'THB');
      expect(r.balances.values.fold(0, (a, b) => a + b), 0);
      // Dinner ₹3,000 = ฿1,250.00; Ari paid 2/3 (฿833.34, the spare satang
      // goes first, spec §6) and owes half (฿625) → +฿208.34. Taxi: Ari
      // owes ฿600. Together −฿391.66.
      expect(r.mine, -39166);
      // The trip's own currency is still there, for "show in INR".
      expect(r.baseBalances['ari'], 50000 - 144000);
      expect(r.byCategory, {
        'food_dining': 125000,
        'local_transportation': 120000,
      });
      expect(r.byDay, {
        DateTime(2026, 10, 27): 125000,
        DateTime(2026, 10, 28): 120000,
      });
      expect(r.totalSpend, 245000);
      expect(r.missingRates, isFalse);
    });

    test('without rates it falls back to the trip currency, and says so', () {
      final r = buildReport(
        tabs: [_dinner, _taxi],
        baseCurrency: 'INR',
        viewerCurrency: 'THB',
        viewer: 'ari',
        ratesFor: (date) => FxRates(date: date, usdRates: const {}),
      );
      // INR ↔ THB can't be converted at all, so there is nothing to show
      // but the honest "missing" flag; same-currency tabs still add up.
      expect(r.missingRates, isTrue);
    });

    test('same-currency tabs need no rates at all', () {
      final r = buildReport(
        tabs: [_dinner],
        baseCurrency: 'INR',
        viewerCurrency: 'INR',
        viewer: 'ben',
        ratesFor: (date) => FxRates(date: date, usdRates: const {}),
      );
      expect(r.missingRates, isFalse);
      expect(r.mine, 25000);
    });

    test('my share across tabs, for the Overall view', () {
      final r = buildReport(
        tabs: [_dinner, _taxi],
        baseCurrency: 'INR',
        viewerCurrency: 'INR',
        viewer: 'ari',
        ratesFor: _rates,
      );
      // ₹1,500 of the dinner + ฿600 of the taxi (= ₹1,440).
      expect(r.myShare, 150000 + 144000);
    });

    test('no tabs: all square, nothing to pay', () {
      final r = buildReport(
        tabs: const [],
        baseCurrency: 'INR',
        viewerCurrency: 'INR',
        viewer: 'ari',
        ratesFor: _rates,
      );
      expect(r.mine, 0);
      expect(r.transfers, isEmpty);
      expect(r.totalSpend, 0);
    });
  });

  group('settlements (UC-26a)', () {
    SplitReport report({
      List<ReportSettlement> settlements = const [],
      String currency = 'INR',
      String viewer = 'ari',
    }) => buildReport(
      tabs: [_dinner],
      baseCurrency: 'INR',
      viewerCurrency: currency,
      viewer: viewer,
      ratesFor: _rates,
      settlements: settlements,
    );

    test('recording every suggested transfer makes everyone square', () {
      final before = report();
      final after = report(
        settlements: [
          for (final t in before.baseTransfers)
            ReportSettlement(
              from: t.from,
              to: t.to,
              amountMinor: t.amount.minor,
              date: '2026-10-29',
            ),
        ],
      );
      expect(after.balances.values.every((b) => b == 0), isTrue);
      expect(after.transfers, isEmpty);
      expect(after.mine, 0);
    });

    test('a partial payment lowers what is owed', () {
      final r = report(
        settlements: const [
          ReportSettlement(
            from: 'kiko',
            to: 'ari',
            amountMinor: 20000,
            date: '2026-10-29',
          ),
        ],
      );
      expect(r.balances, {'ari': 30000, 'ben': 25000, 'kiko': -55000});
    });

    test('a settlement converts at its own day, still summing to zero', () {
      final r = report(
        currency: 'THB',
        settlements: const [
          ReportSettlement(
            from: 'kiko',
            to: 'ari',
            amountMinor: 50000,
            date: '2026-10-29',
          ),
        ],
      );
      expect(r.balances.values.fold(0, (a, b) => a + b), 0);
      // ₹500 = ฿208.33 at 84 and 35 per USD; Ari was owed ฿208.34. She is
      // square in rupees, so she shows square in baht too (C7), not ฿0.01.
      expect(r.baseBalances['ari'], 0);
      expect(r.mine, 0);
    });

    test('base transfers are in the trip currency, for recording', () {
      final r = report(currency: 'THB');
      expect(r.baseTransfers.map((t) => (t.from, t.to, t.amount.minor)), [
        ('kiko', 'ari', 50000),
        ('kiko', 'ben', 25000),
      ]);
      expect(r.baseTransfers.first.amount.currency, 'INR');
    });
  });

  group('headline (UC-25)', () {
    test('owed, owe or all square', () {
      expect(headline(50000, 'INR', '₹'), 'You’re owed ₹500.00');
      expect(headline(-56000, 'INR', '₹'), 'You owe ₹560.00');
      expect(headline(0, 'INR', '₹'), 'All square 🎉');
    });
  });
}
