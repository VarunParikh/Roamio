import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/core/ui/primary_button.dart';
import 'package:roamio/features/adventures/domain/adventure.dart';
import 'package:roamio/features/auth/domain/session.dart';
import 'package:roamio/features/splits/domain/money.dart';
import 'package:roamio/features/splits/domain/tab_models.dart';
import 'package:roamio/features/squad/data/squad_service.dart';
import 'package:roamio/features/tabs/data/tab_service.dart';
import 'package:roamio/features/tabs/domain/payment_method.dart';
import 'package:roamio/features/tabs/domain/tab_status.dart';

import '../../support/fake_adventure_service.dart';
import '../../support/fake_auth_service.dart';
import '../../support/fake_payment_memory.dart';
import '../../support/fake_photo_pipeline.dart';
import '../../support/fake_receipt_scanner.dart';
import '../../support/fake_squad_service.dart';
import '../../support/fake_tab_service.dart';

/// Today is 29 Oct 2026. Ari leads, Bob is a member, Kiko is a pal.
final _bangkok = Adventure(
  id: 'bkk',
  name: 'Bangkok trip',
  countryCode: 'TH',
  startDate: DateTime(2026, 10, 10),
  endDate: DateTime(2026, 11, 2),
  baseCurrency: 'THB',
  leaderUid: 'ari',
  coLeadUids: const ['bob'],
  memberUids: const ['ari', 'bob'],
);

TabEntry _tab({
  String id = 't1',
  String description = '',
  int amount = 90000,
  List<Payment>? payers,
  List<String> sharing = const ['ari', 'bob'],
  String createdBy = 'ari',
  TabStatus status = TabStatus.approved,
}) => TabEntry(
  id: id,
  description: description,
  category: 'food_dining',
  date: DateTime(2026, 10, 29),
  createdBy: createdBy,
  status: status,
  split: TabSplit(
    amount: Money(amount, 'THB'),
    payers: payers ?? [Payment('ari', amount, method: PaymentMethod.card)],
    participants: sharing,
    fxDate: '2026-10-29',
  ),
);

Future<void> _open(
  WidgetTester tester, {
  List<TabEntry> tabs = const [],
  FakeTabService? service,
  FakePaymentMemory? memory,
  FakePhotoPipeline? photos,
  FakeReceiptScanner? scanner,
  String as = 'ari',
}) async {
  await pumpRoamio(
    tester,
    FakeAuthService(
      initial: SessionFacts(uid: as, hasAccount: true, ageStatus: 'adult'),
    ),
    adventures: FakeAdventureService([_bangkok]),
    squad: FakeSquadService()
      ..names.addAll({'ari': 'Ari Chen', 'bob': 'Bob Lee'})
      ..palsByAdventure['bkk'] = [const Pal(id: 'kiko', nickname: 'Kiko')],
    tabs: service ?? FakeTabService(tabs),
    paymentMemory: memory,
    photos: photos,
    scanner: scanner,
  );
  await tester.tap(find.text('Bangkok trip').first);
  await tester.pumpAndSettle();
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _openAddTab(WidgetTester tester) async {
  await tester.scrollUntilVisible(find.text('Add tab'), 200);
  await _tapVisible(tester, find.text('Add tab'));
}

Future<void> _fillIn(WidgetTester tester) async {
  await tester.enterText(find.widgetWithText(TextField, 'Amount'), '900');
  await tester.pumpAndSettle();
  await _tapVisible(tester, find.textContaining('Food & Dining'));
}

Finder _dropdown(String id) => find.byKey(ValueKey('method-$id'));

Future<void> _pick(WidgetTester tester, String id, String item) async {
  await _tapVisible(tester, _dropdown(id));
  await tester.tap(find.text(item).last);
  await tester.pumpAndSettle();
}

Future<void> _save(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(PrimaryButton, 'Save tab'));
  await tester.pumpAndSettle();
}

bool _canSave(WidgetTester tester) =>
    tester
        .widget<PrimaryButton>(find.widgetWithText(PrimaryButton, 'Save tab'))
        .onPressed !=
    null;

const _why = 'Choose how this was paid to save the tab.';
const _whyEach = 'Choose how each person paid to save the tab.';

void main() {
  group('Paid with on Add tab (UC-21)', () {
    testWidgets('the first time, Save is disabled and says why', (
      tester,
    ) async {
      final tabs = FakeTabService();
      final memory = FakePaymentMemory();
      await _open(tester, service: tabs, memory: memory);
      await _openAddTab(tester);
      await _fillIn(tester);

      expect(find.text('Paid with'), findsOneWidget);
      expect(_canSave(tester), isFalse);
      expect(find.text(_why), findsOneWidget);

      await _pick(tester, 'ari', '📱 UPI');
      expect(_canSave(tester), isTrue);
      expect(find.text(_why), findsNothing);

      await _save(tester);
      expect(tabs.added.single.$2.payers.single.method, PaymentMethod.upi);
      expect(memory.saved, PaymentMethod.upi);
    });

    testWidgets('all six options are offered, with no free text', (
      tester,
    ) async {
      await _open(tester, memory: FakePaymentMemory());
      await _openAddTab(tester);
      await _tapVisible(tester, _dropdown('ari'));
      for (final option in [
        '💵 Cash',
        '💳 Card',
        '📱 UPI',
        '📝 Cheque',
        '🏦 Bank transfer',
        '🔖 Other',
      ]) {
        expect(find.text(option), findsWidgets, reason: option);
      }
    });

    testWidgets('it starts on the method last used on this phone', (
      tester,
    ) async {
      final tabs = FakeTabService();
      await _open(
        tester,
        service: tabs,
        memory: FakePaymentMemory(PaymentMethod.cheque),
      );
      await _openAddTab(tester);
      await _fillIn(tester);

      expect(find.text('📝 Cheque'), findsOneWidget);
      expect(_canSave(tester), isTrue);
      await _save(tester);
      expect(tabs.added.single.$2.payers.single.method, PaymentMethod.cheque);
    });

    testWidgets('Split payment has one dropdown per person who paid', (
      tester,
    ) async {
      final tabs = FakeTabService();
      final memory = FakePaymentMemory();
      await _open(tester, service: tabs, memory: memory);
      await _openAddTab(tester);
      await _fillIn(tester);
      await _tapVisible(tester, find.text('Split payment'));

      // You typed the whole amount in; Bob hasn't paid anything yet.
      expect(_dropdown('ari'), findsOneWidget);
      expect(_dropdown('bob'), findsNothing);

      await tester.enterText(find.byKey(const ValueKey('pay-ari')), '600');
      await tester.enterText(find.byKey(const ValueKey('pay-bob')), '300');
      await tester.pumpAndSettle();
      expect(_dropdown('bob'), findsOneWidget);
      expect(find.text(_whyEach), findsOneWidget);

      await _pick(tester, 'ari', '💳 Card');
      expect(_canSave(tester), isFalse, reason: 'Bob still has no method');
      await _pick(tester, 'bob', '💵 Cash');
      expect(_canSave(tester), isTrue);

      await _save(tester);
      expect(
        [for (final p in tabs.added.single.$2.payers) (p.payer, p.method)],
        [('ari', PaymentMethod.card), ('bob', PaymentMethod.cash)],
      );
      // The next tab starts on what you used, not what Bob used.
      expect(memory.saved, PaymentMethod.card);
    });

    testWidgets('leaving Split payment keeps your own choice', (tester) async {
      final tabs = FakeTabService();
      await _open(tester, service: tabs, memory: FakePaymentMemory());
      await _openAddTab(tester);
      await _fillIn(tester);
      await _pick(tester, 'ari', '📱 UPI');
      await _tapVisible(tester, find.text('Split payment'));
      await _tapVisible(tester, find.text('Just me'));
      await _save(tester);
      expect(tabs.added.single.$2.payers.single.method, PaymentMethod.upi);
    });

    testWidgets('Scan bill doesn’t guess it', (tester) async {
      await _open(
        tester,
        memory: FakePaymentMemory(),
        photos: FakePhotoPipeline(),
        scanner: FakeReceiptScanner('Paid by card\nGrand Total  ₹ 450.00'),
      );
      await _openAddTab(tester);
      await _tapVisible(tester, find.text('Scan bill'));
      expect(
        find.text('Check the amount, date and name we read.'),
        findsOneWidget,
      );
      expect(find.text('💳 Card'), findsNothing);
      expect(_canSave(tester), isFalse);
      expect(find.text(_why), findsOneWidget);
    });

    testWidgets('editing shows how each payer paid and can change it', (
      tester,
    ) async {
      final memory = FakePaymentMemory(PaymentMethod.cash);
      final tabs = FakeTabService([_tab(description: 'Dinner')]);
      await _open(tester, service: tabs, memory: memory);
      await _tapVisible(tester, find.text('Dinner'));
      await tester.tap(find.byTooltip('Edit tab'));
      await tester.pumpAndSettle();

      // The tab's own method, not the phone's last one.
      expect(find.text('💳 Card'), findsOneWidget);
      await _pick(tester, 'ari', '🏦 Bank transfer');
      await tester.tap(find.widgetWithText(PrimaryButton, 'Save changes'));
      await tester.pumpAndSettle();

      expect(
        tabs.updates.single.$3.payers.single.method,
        PaymentMethod.bankTransfer,
      );
      // Fixing an old tab isn't a new habit.
      expect(memory.saved, PaymentMethod.cash);
    });

    testWidgets('editing an older tab with no method shows Other', (
      tester,
    ) async {
      final tabs = FakeTabService([
        _tab(description: 'Old dinner', payers: const [Payment('ari', 90000)]),
      ]);
      await _open(tester, service: tabs);
      await _tapVisible(tester, find.text('Old dinner'));
      await tester.tap(find.byTooltip('Edit tab'));
      await tester.pumpAndSettle();
      expect(find.text('🔖 Other'), findsOneWidget);
    });
  });

  group('the tab row (UC-23)', () {
    testWidgets('category and amount, description and share, then emoji', (
      tester,
    ) async {
      await _open(tester, tabs: [_tab(description: 'Dinner at Jay Fai')]);

      expect(find.text('Food & Dining'), findsOneWidget);
      expect(find.text('฿900.00'), findsOneWidget);
      expect(find.text('Dinner at Jay Fai'), findsOneWidget);
      expect(find.text('Your share ฿450.00'), findsOneWidget);
      expect(find.text('💳'), findsOneWidget);

      double top(String s) => tester.getTopLeft(find.text(s)).dy;
      expect(top('Food & Dining'), lessThan(top('Dinner at Jay Fai')));
      expect(top('Dinner at Jay Fai'), lessThan(top('💳')));
      // The description is the smaller line.
      double size(String s) => tester.getSize(find.text(s)).height;
      expect(size('Dinner at Jay Fai'), lessThan(size('Food & Dining')));
      // The old second line is gone.
      expect(find.textContaining('· Total'), findsNothing);
    });

    testWidgets('with no description the category is still the title', (
      tester,
    ) async {
      await _open(tester, tabs: [_tab()]);
      expect(find.text('Food & Dining'), findsOneWidget);
      expect(find.text('Your share ฿450.00'), findsOneWidget);
    });

    testWidgets('someone not sharing sees that instead of a share', (
      tester,
    ) async {
      await _open(
        tester,
        tabs: [
          _tab(sharing: const ['bob']),
        ],
      );
      expect(find.text('Not in it'), findsOneWidget);
    });

    testWidgets('payers who paid differently show each emoji once', (
      tester,
    ) async {
      await _open(
        tester,
        tabs: [
          _tab(
            payers: const [
              Payment('ari', 40000, method: PaymentMethod.upi),
              Payment('bob', 30000, method: PaymentMethod.cash),
              Payment('zed', 20000, method: PaymentMethod.upi),
            ],
          ),
        ],
      );
      expect(find.text('📱💵'), findsOneWidget);
    });

    testWidgets('a missing method shows as Other', (tester) async {
      await _open(
        tester,
        tabs: [
          _tab(payers: const [Payment('ari', 90000)]),
        ],
      );
      expect(find.text('🔖'), findsOneWidget);
    });

    testWidgets('TalkBack reads the method’s name, not the emoji', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _open(
        tester,
        tabs: [
          _tab(
            payers: const [
              Payment('ari', 40000, method: PaymentMethod.bankTransfer),
              Payment('bob', 50000, method: PaymentMethod.cash),
            ],
          ),
        ],
      );
      // The row reads as one button, so this is part of its label.
      final label = tester.getSemantics(find.text('🏦💵')).label;
      expect(label, contains('Paid with Bank transfer and Cash'));
      expect(label, isNot(contains('🏦')));
      semantics.dispose();
    });

    testWidgets('the waiting label and buttons stay below the three lines', (
      tester,
    ) async {
      await _open(
        tester,
        tabs: [
          _tab(
            description: 'Dinner',
            status: TabStatus.waiting,
            createdBy: 'bob',
            payers: const [Payment('bob', 90000, method: PaymentMethod.card)],
          ),
        ],
      );
      final emoji = tester.getBottomLeft(find.text('💳')).dy;
      expect(
        tester.getTopLeft(find.text('Waiting for approval')).dy,
        greaterThanOrEqualTo(emoji),
      );
      expect(tester.getTopLeft(find.text('Approve')).dy, greaterThan(emoji));
    });

    testWidgets('fits a small phone with long words and big amounts', (
      tester,
    ) async {
      await _open(
        tester,
        as: 'bob',
        tabs: [
          _tab(
            description:
                'A very long description of a very long dinner that keeps '
                'going until it has to be cut off somewhere on the line',
            amount: 999999999,
            status: TabStatus.waiting,
            payers: const [
              Payment('ari', 333333333, method: PaymentMethod.bankTransfer),
              Payment('bob', 333333333, method: PaymentMethod.cash),
              Payment('zed', 333333333, method: PaymentMethod.cheque),
            ],
          ),
          _tab(id: 't2', sharing: const ['ari']),
        ],
      );
      tester.view.physicalSize = const Size(320, 568) * 2.625;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      for (final scale in [1.0, 1.3]) {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        await tester.pumpAndSettle();
        // A RenderFlex overflow fails the test by itself.
        expect(tester.takeException(), isNull, reason: 'scale $scale');
      }
      expect(find.text('🏦💵📝'), findsOneWidget);
      expect(find.text('฿9,999,999.99'), findsOneWidget);
      expect(find.text('Your share ฿4,999,999.99'), findsOneWidget);
    });
  });

  group('tab details (UC-23)', () {
    testWidgets('list each payer with how they paid', (tester) async {
      final semantics = tester.ensureSemantics();
      await _open(
        tester,
        tabs: [
          _tab(
            description: 'Dinner',
            payers: const [
              Payment('ari', 60000, method: PaymentMethod.bankTransfer),
              Payment('bob', 30000),
            ],
          ),
        ],
      );
      await _tapVisible(tester, find.text('Dinner'));

      expect(find.text('Paid by'), findsOneWidget);
      expect(find.text('🏦 Bank transfer'), findsOneWidget);
      expect(find.text('🔖 Other'), findsOneWidget);
      final label = tester.getSemantics(find.text('🏦 Bank transfer')).label;
      expect(label, contains('Paid with Bank transfer'));
      expect(label, isNot(contains('🏦')));
      semantics.dispose();
    });
  });
}
