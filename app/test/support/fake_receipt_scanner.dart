import 'package:roamio/features/tabs/data/receipt_scanner.dart';

/// Returns [text] for any photo, or throws when [fails].
class FakeReceiptScanner implements ReceiptScanner {
  new([this.text = '']);

  String text;
  bool fails = false;
  final List<String> read = [];

  @override
  Future<String> readText(String imagePath) async {
    read.add(imagePath);
    if (fails) throw Exception('ML Kit unavailable');
    return text;
  }
}
