import 'package:roamio/features/tabs/data/payment_memory.dart';
import 'package:roamio/features/tabs/domain/payment_method.dart';

/// Keeps the last payment method in memory; empty is a phone's first time.
class FakePaymentMemory implements PaymentMemory {
  new([this.saved]);

  PaymentMethod? saved;

  @override
  Future<PaymentMethod?> read() async => saved;

  @override
  Future<void> write(PaymentMethod method) async => saved = method;
}
