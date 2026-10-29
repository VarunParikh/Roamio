import 'package:share_plus/share_plus.dart';

/// Records files sent to the share sheet: (name, mime type, bytes).
class SharedFiles {
  final List<(String, String, List<int>)> files = [];

  Future<void> call(List<XFile> sent, List<String> names) async {
    for (final (i, f) in sent.indexed) {
      files.add((names[i], f.mimeType ?? '', await f.readAsBytes()));
    }
  }
}
