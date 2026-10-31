import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/features/adventures/domain/adventure.dart';
import 'package:roamio/features/splits/domain/tab_models.dart';
import 'package:roamio/features/tabs/data/firebase_tab_service.dart';
import 'package:roamio/features/tabs/data/payment_memory.dart';
import 'package:roamio/features/tabs/domain/new_tab.dart';
import 'package:roamio/features/tabs/domain/payment_method.dart';

final _goa = Adventure(
  id: 'goa',
  name: 'Goa trip',
  countryCode: 'IN',
  startDate: DateTime(2026, 10, 20),
  endDate: DateTime(2026, 11, 2),
  baseCurrency: 'INR',
  leaderUid: 'ari',
  memberUids: const ['ari', 'ben'],
);

Set<TabProblem> _problems(List<PaymentMethod?>? methods) => tabProblems(
  adventure: _goa,
  myUid: 'ari',
  amountText: '100',
  currency: 'INR',
  date: DateTime(2026, 10, 29),
  today: DateTime(2026, 10, 29),
  category: 'food_dining',
  participants: const ['ari'],
  paymentMethods: methods,
);

void main() {
  group('PaymentMethod (spec UC-21)', () {
    test('the six options, in order, with their stored ids', () {
      expect(
        [for (final m in PaymentMethod.values) (m.id, m.emoji, m.label)],
        [
          ('cash', '💵', 'Cash'),
          ('card', '💳', 'Card'),
          ('upi', '📱', 'UPI'),
          ('cheque', '📝', 'Cheque'),
          ('bank_transfer', '🏦', 'Bank transfer'),
          ('other', '🔖', 'Other'),
        ],
      );
    });

    test('a stored id reads back as its method', () {
      for (final m in PaymentMethod.values) {
        expect(PaymentMethod.fromStored(m.id), m);
      }
    });

    test('a missing, unknown or malformed value shows as Other', () {
      for (final stored in <Object?>[null, '', 'crypto', 'CASH', 7, const {}]) {
        expect(
          PaymentMethod.fromStored(stored),
          PaymentMethod.other,
          reason: '$stored',
        );
      }
    });

    test('TalkBack hears the names, each once', () {
      expect(paidWithLabel(const [PaymentMethod.cash]), 'Paid with Cash');
      expect(
        paidWithLabel(const [
          PaymentMethod.cash,
          PaymentMethod.upi,
          PaymentMethod.cash,
        ]),
        'Paid with Cash and UPI',
      );
      expect(
        paidWithLabel(const [
          PaymentMethod.bankTransfer,
          PaymentMethod.card,
          PaymentMethod.upi,
        ]),
        'Paid with Bank transfer, Card and UPI',
      );
    });
  });

  group('a payer on a stored tab (DATA_MODEL: payers[].method)', () {
    test('is written with its method id', () {
      expect(
        payerFields(
          const Payment('ari', 500, method: PaymentMethod.bankTransfer),
        ),
        {'id': 'ari', 'amountMinor': 500, 'method': 'bank_transfer'},
      );
    });

    test('reads its method back', () {
      final p = paymentFromStored(const {
        'id': 'ari',
        'amountMinor': 500,
        'method': 'upi',
      });
      expect(
        (p.payer, p.amountMinor, p.method),
        ('ari', 500, PaymentMethod.upi),
      );
    });

    test('with an older or odd method still reads, as Other', () {
      for (final extra in <Map<String, Object?>>[
        {},
        {'method': 'crypto'},
        {'method': 42},
      ]) {
        final p = paymentFromStored({'id': 'ari', 'amountMinor': 1, ...extra});
        expect(p.method, PaymentMethod.other, reason: '$extra');
      }
    });
  });

  group('tabProblems: Paid with is required (spec UC-21)', () {
    test('fine when every payer has a method', () {
      expect(_problems(const [PaymentMethod.cash]), isEmpty);
      expect(_problems(const [PaymentMethod.cash, PaymentMethod.upi]), isEmpty);
    });

    test('a payer with no method stops the save', () {
      expect(_problems(const [null]), {TabProblem.noPaymentMethod});
      expect(_problems(const [PaymentMethod.cash, null]), {
        TabProblem.noPaymentMethod,
      });
    });

    test('other callers that pass no methods are unaffected', () {
      expect(_problems(null), isEmpty);
    });
  });

  group('payersFrom', () {
    test('gives each person who paid their method', () {
      final payers = payersFrom(
        const {'ari': '60', 'ben': '40', 'cara': ''},
        'INR',
        methodOf: (id) => id == 'ari' ? PaymentMethod.upi : PaymentMethod.cash,
      );
      expect(
        [for (final p in payers) (p.payer, p.method)],
        [('ari', PaymentMethod.upi), ('ben', PaymentMethod.cash)],
      );
    });
  });

  group('rememberedMethod: what the next tab starts on', () {
    const ben = Payment('ben', 1, method: PaymentMethod.cash);
    const ari = Payment('ari', 1, method: PaymentMethod.upi);

    test('your own method when you paid', () {
      expect(rememberedMethod(const [ben, ari], 'ari'), PaymentMethod.upi);
    });

    test('the first payer’s when you didn’t', () {
      expect(rememberedMethod(const [ben, ari], 'cara'), PaymentMethod.cash);
    });
  });

  group('FilePaymentMemory (one small local file, no cloud)', () {
    late Directory folder;
    late FilePaymentMemory memory;

    setUp(() {
      folder = Directory.systemTemp.createTempSync('roamio_payment_memory');
      memory = FilePaymentMemory(folder: () async => folder);
    });
    tearDown(() => folder.deleteSync(recursive: true));

    File file() => File('${folder.path}/last_payment_method.json');

    test('knows nothing the first time', () async {
      expect(await memory.read(), isNull);
    });

    test('remembers the last method across restarts', () async {
      await memory.write(PaymentMethod.bankTransfer);
      await memory.write(PaymentMethod.upi);
      final again = FilePaymentMemory(folder: () async => folder);
      expect(await again.read(), PaymentMethod.upi);
    });

    test('a damaged file or unknown method counts as first time', () async {
      file().writeAsStringSync('not json');
      expect(await memory.read(), isNull);
      file().writeAsStringSync('{"method":"crypto"}');
      expect(await memory.read(), isNull);
    });

    test('a failed write stays quiet; the tab is already saved', () async {
      final nowhere = FilePaymentMemory(
        folder: () async => Directory('${folder.path}/missing/folder'),
      );
      await nowhere.write(PaymentMethod.cash);
      expect(await nowhere.read(), isNull);
    });
  });
}
