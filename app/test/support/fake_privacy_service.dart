import 'dart:typed_data';

import 'package:roamio/features/profile/data/privacy_service.dart';

class FakePrivacyService implements PrivacyService {
  new({this.photoParts = 0});

  /// How many photo zips a download has.
  final int photoParts;

  /// `download:<childUid or me>` and `delete:children=<bool>`.
  final List<String> calls = [];

  /// When set, the next action throws this message.
  String? failNext;

  void _act(String call) {
    final failure = failNext;
    failNext = null;
    if (failure != null) throw PrivacyException(failure);
    calls.add(call);
  }

  @override
  Future<List<ExportFile>> downloadData({String? childUid}) async {
    _act('download:${childUid ?? 'me'}');
    return [
      ExportFile(
        kind: 'data',
        mimeType: 'application/json',
        bytes: Uint8List.fromList('{}'.codeUnits),
      ),
      for (var i = 0; i < photoParts; i++)
        ExportFile(
          kind: 'photos',
          mimeType: 'application/zip',
          bytes: Uint8List.fromList([80, 75, 5, 6, i]),
        ),
    ];
  }

  @override
  Future<void> deleteAccount({required bool confirmLinkedChildren}) async {
    _act('delete:children=$confirmLinkedChildren');
  }
}
