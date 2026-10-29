import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:roamio/features/tabs/data/receipt_parser.dart';

/// Reads the text on a photo of a bill, on the phone (spec UC-21: Scan
/// bill). Nothing is sent anywhere to do this.
abstract interface class ReceiptScanner {
  Future<String> readText(String imagePath);
}

/// Remote Config `ocr_enabled` (spec §11); on by default until Task 37
/// wires Remote Config, so the app works without it.
final ocrEnabledProvider = Provider<bool>((ref) => true);

final receiptScannerProvider = Provider<ReceiptScanner>(
  (ref) => MlKitReceiptScanner(),
);

/// ML Kit's on-device Latin text model, which covers the digits, currency
/// signs and English or European words on most bills.
class MlKitReceiptScanner implements ReceiptScanner {
  @override
  Future<String> readText(String imagePath) async {
    final recognizer = TextRecognizer();
    try {
      final result = await recognizer.processImage(
        InputImage.fromFilePath(imagePath),
      );
      return rowsFromPieces([
        for (final block in result.blocks)
          for (final line in block.lines)
            TextPiece(
              line.text,
              left: line.boundingBox.left,
              top: line.boundingBox.top,
              bottom: line.boundingBox.bottom,
            ),
      ]);
    } finally {
      await recognizer.close();
    }
  }
}
