import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One file of a data download: the JSON, or a zip of photos.
class ExportFile {
  const new({required this.kind, required this.mimeType, required this.bytes});

  /// `data` for the JSON, `photos` for a zip part.
  final String kind;
  final String mimeType;
  final Uint8List bytes;
}

/// A privacy action failed; [message] is safe to show as-is.
class PrivacyException implements Exception {
  new(this.message);

  final String message;

  @override
  String toString() => 'PrivacyException($message)';
}

/// The person's rights over their data (spec UC-29, §8).
abstract interface class PrivacyService {
  /// Their data (or, for a parent, a linked child's): the JSON first, then
  /// the photo zips in order.
  Future<List<ExportFile>> downloadData({String? childUid});

  /// Erases their account. A parent passes [confirmLinkedChildren] once they
  /// have accepted that their children keep their accounts (spec §7.5).
  Future<void> deleteAccount({required bool confirmLinkedChildren});
}

final privacyServiceProvider = Provider<PrivacyService>(
  (ref) =>
      throw UnimplementedError('privacyServiceProvider must be overridden'),
);
