import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:roamio/features/profile/data/privacy_service.dart';

class FirebasePrivacyService implements PrivacyService {
  new(this._functions);

  final FirebaseFunctions _functions;

  @override
  Future<List<ExportFile>> downloadData({String? childUid}) async {
    final first = await _call('exportMyData', {'childUid': ?childUid});
    final files = [
      ExportFile(
        kind: 'data',
        mimeType: 'application/json',
        bytes: Uint8List.fromList(
          utf8.encode(
            const JsonEncoder.withIndent('  ').convert(first['data']),
          ),
        ),
      ),
    ];
    final parts = (first['photoParts'] as num?)?.toInt() ?? 0;
    for (var part = 0; part < parts; part++) {
      final result = await _call('exportMyData', {
        'childUid': ?childUid,
        'photosPart': part,
      });
      files.add(
        ExportFile(
          kind: 'photos',
          mimeType: 'application/zip',
          bytes: base64Decode(result['zip']! as String),
        ),
      );
    }
    return files;
  }

  @override
  Future<void> deleteAccount({required bool confirmLinkedChildren}) async {
    await _call('deleteMyAccount', {
      'confirmLinkedChildren': confirmLinkedChildren,
    });
  }

  Future<Map<Object?, Object?>> _call(
    String name,
    Map<String, Object?> data,
  ) async {
    try {
      final result = await _functions
          .httpsCallable(
            name,
            options: HttpsCallableOptions(timeout: const Duration(minutes: 2)),
          )
          .call<Object?>(data);
      return (result.data as Map<Object?, Object?>?) ?? const {};
    } on FirebaseFunctionsException catch (e) {
      const ours = {'failed-precondition', 'permission-denied'};
      throw PrivacyException(
        ours.contains(e.code) && e.message != null
            ? e.message!
            : e.code == 'unavailable'
            ? 'No connection. Check your internet and try again.'
            : 'Something went wrong. Please try again.',
      );
    }
  }
}
