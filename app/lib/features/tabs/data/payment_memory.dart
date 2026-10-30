import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:roamio/features/tabs/domain/payment_method.dart';

/// The method last used on this phone, which the next tab starts on
/// (spec UC-21). It stays on the phone.
abstract interface class PaymentMemory {
  /// Null the first time.
  Future<PaymentMethod?> read();
  Future<void> write(PaymentMethod method);
}

/// [PaymentMemory] as a JSON file in the app's support folder. Failing to
/// read or write stays quiet: the worst case is choosing the method again.
class FilePaymentMemory implements PaymentMemory {
  new({this._folder = getApplicationSupportDirectory});

  final Future<Directory> Function() _folder;

  Future<File> get _file async =>
      File('${(await _folder()).path}/last_payment_method.json');

  @override
  Future<PaymentMethod?> read() async {
    try {
      final data = jsonDecode(await (await _file).readAsString()) as Map;
      return PaymentMethod.byId(data['method']);
    } on Object {
      return null;
    }
  }

  @override
  Future<void> write(PaymentMethod method) async {
    try {
      await (await _file).writeAsString(jsonEncode({'method': method.id}));
    } on Object {
      // Next time it asks again.
    }
  }
}

final paymentMemoryProvider = Provider<PaymentMemory>(
  (ref) => throw UnimplementedError('paymentMemoryProvider must be overridden'),
);
