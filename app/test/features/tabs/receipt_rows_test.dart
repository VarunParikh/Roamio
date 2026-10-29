import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/features/tabs/data/receipt_parser.dart';

void main() {
  group('rowsFromPieces (OCR reads columns separately)', () {
    test('rejoins labels and amounts printed on the same line', () {
      // As ML Kit returns them: the label column, then the amount column.
      final text = rowsFromPieces(const [
        TextPiece('CORNER MART', left: 40, top: 60, bottom: 110),
        TextPiece('Water 1L', left: 40, top: 200, bottom: 250),
        TextPiece('TOTAL', left: 40, top: 270, bottom: 318),
        TextPiece('1.99', left: 600, top: 202, bottom: 252),
        TextPiece('5.48', left: 600, top: 268, bottom: 316),
      ]);
      expect(text, 'CORNER MART\nWater 1L  1.99\nTOTAL  5.48');
    });

    test('keeps pieces left to right within a row', () {
      expect(
        rowsFromPieces(const [
          TextPiece('5.48', left: 600, top: 10, bottom: 50),
          TextPiece('TOTAL', left: 40, top: 12, bottom: 52),
          TextPiece('USD', left: 300, top: 11, bottom: 49),
        ]),
        'TOTAL  USD  5.48',
      );
    });

    test('nothing in, nothing out', () {
      expect(rowsFromPieces(const []), '');
    });
  });
}
