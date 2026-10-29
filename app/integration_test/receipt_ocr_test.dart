import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:roamio/features/tabs/data/receipt_parser.dart';
import 'package:roamio/features/tabs/data/receipt_scanner.dart';

/// Runs ML Kit's real on-device text recognition (Task 26) on a receipt
/// drawn as an image, then the parser:
/// `fvm flutter test integration_test/receipt_ocr_test.dart --flavor dev -d <device>`.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<String> drawReceipt(List<String> lines) async {
    final recorder = ui.PictureRecorder();
    const width = 900.0;
    final height = 120.0 + lines.length * 70;
    final canvas = Canvas(recorder)
      ..drawRect(
        Offset.zero & Size(width, height),
        Paint()..color = Colors.white,
      );
    for (final (i, line) in lines.indexed) {
      TextPainter(
          text: TextSpan(
            text: line,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 44,
              fontFamily: 'monospace',
            ),
          ),
          textDirection: TextDirection.ltr,
        )
        ..layout(maxWidth: width - 80)
        ..paint(canvas, Offset(40, 60.0 + i * 70));
    }
    final image = await recorder.endRecording().toImage(
      width.toInt(),
      height.toInt(),
    );
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('${(await Directory.systemTemp.createTemp()).path}/r.png')
      ..writeAsBytesSync(png!.buffer.asUint8List());
    return file.path;
  }

  testWidgets('reads a printed receipt into amount, date and merchant', (
    tester,
  ) async {
    final path = await drawReceipt([
      'CORNER MART',
      'Oct 22, 2026',
      'Water 1L        1.99',
      'Chips           3.49',
      'TOTAL           5.48',
      'CASH           20.00',
    ]);
    final text = await MlKitReceiptScanner().readText(path);
    debugPrint('OCR text:\n$text');
    final guess = parseReceipt(
      text,
      currency: 'USD',
      today: DateTime(2026, 10, 29),
    );
    expect(guess.amountMinor, 548);
    expect(guess.date, DateTime(2026, 10, 22));
    expect(guess.merchant, 'Corner Mart');
  });
}
