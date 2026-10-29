import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/features/tabs/data/receipt_parser.dart';

/// Ten receipt texts as on-device OCR returns them (spec Task 26):
/// rupees, euros, dollars and baht, in their local number and date styles.
void main() {
  final today = DateTime(2026, 10, 29);

  ReceiptGuess read(String text, String currency) =>
      parseReceipt(text, currency: currency, today: today);

  group('parseReceipt (spec UC-21: Scan bill prefills, you confirm)', () {
    test('1. Indian restaurant: Grand Total after GST', () {
      final g = read('''
SPICE ROUTE RESTAURANT
12 MG Road, Bengaluru 560001
GSTIN 29ABCDE1234F1Z5
Date: 27/10/2026  Time: 21:14
Paneer Tikka     1   320.00
Butter Naan      4   240.00
Sub Total            560.00
CGST 2.5%             14.00
SGST 2.5%             14.00
Grand Total      ₹ 588.00
Thank you! Visit again
''', 'INR');
      expect(g.amountMinor, 58800);
      expect(g.date, DateTime(2026, 10, 27));
      expect(g.merchant, 'Spice Route Restaurant');
    });

    test('2. Indian shop: Net Amount, rupee grouping, two-digit year', () {
      final g = read('''
TAX INVOICE
Chai Point
Bill No: 4521   Dt: 28-10-26
Masala Chai x2      120
Samosa x3           1,050
Net Amount Rs. 1,170
''', 'INR');
      expect(g.amountMinor, 117000);
      expect(g.date, DateTime(2026, 10, 28));
      expect(g.merchant, 'Chai Point');
    });

    test('3. German café: SUMME with a decimal comma', () {
      final g = read('''
Café Einstein
Unter den Linden 42, Berlin
26.10.2026 14:03
2x Cappuccino      7,80
1x Apfelstrudel    5,60
SUMME EUR         13,40
Gegeben Bar       20,00
Rückgeld           6,60
''', 'EUR');
      expect(g.amountMinor, 1340);
      expect(g.date, DateTime(2026, 10, 26));
      expect(g.merchant, 'Café Einstein');
    });

    test('4. French brasserie: TOTAL TTC, euro sign after', () {
      final g = read('''
BRASSERIE LIPP
151 Bd Saint-Germain
Le 25/10/2026
Steak frites      24,50
Vin rouge         21,40
TOTAL HT          38,25
TVA 20%            7,65
TOTAL TTC         45,90 €
''', 'EUR');
      expect(g.amountMinor, 4590);
      expect(g.date, DateTime(2026, 10, 25));
    });

    test('5. Euro with thousands dots: 1.234,56', () {
      final g = read('''
Hotel Bellavista
Data 20/10/2026
Camera 3 notti   1.050,00
Tassa soggiorno     184,56
TOTALE EURO      1.234,56
''', 'EUR');
      expect(g.amountMinor, 123456);
      expect(g.merchant, 'Hotel Bellavista');
    });

    test('6. US diner: month first, Amount Due after tax', () {
      final g = read(r'''
Joe's Diner
(212) 555-0143
10/24/2026 08:12 AM
Pancakes           $9.50
Coffee             $3.25
Subtotal          $12.75
Tax                $1.13
Tip                $2.00
Amount Due        $15.88
''', 'USD');
      expect(g.amountMinor, 1588);
      expect(g.date, DateTime(2026, 10, 24));
      expect(g.merchant, "Joe's Diner");
    });

    test('7. US store: TOTAL beats a larger cash line', () {
      final g = read('''
CORNER MART
Oct 22, 2026
Water 1L           1.99
Chips              3.49
TOTAL              5.48
CASH              20.00
CHANGE            14.52
Total items: 2
''', 'USD');
      expect(g.amountMinor, 548);
      expect(g.date, DateTime(2026, 10, 22));
    });

    test('8. Thai 7-Eleven: baht and a Buddhist-era year', () {
      final g = read('''
7-ELEVEN
สาขา สุขุมวิท 11
29/10/2569 19:45
น้ำดื่ม           10.00
ข้าวกล่อง         45.00
รวม  ฿55.00
เงินสด           100.00
ทอน              45.00
''', 'THB');
      expect(g.amountMinor, 5500);
      expect(g.date, DateTime(2026, 10, 29));
      expect(g.merchant, '7-Eleven');
    });

    test('9. Thai restaurant in English: TOTAL THB with a comma', () {
      final g = read('''
Baan Khanitha
Receipt #00871
23 Oct 2026
Tom Yum Goong      450.00
Green Curry        380.00
Service 10%        120.00
TOTAL THB        1,250.00
''', 'THB');
      expect(g.amountMinor, 125000);
      expect(g.date, DateTime(2026, 10, 23));
      expect(g.merchant, 'Baan Khanitha');
    });

    test('10. No total line: the largest amount; future dates ignored', () {
      final g = read('''
Night Market Stall
12/12/2026
Pad Thai   80
Mango sticky rice   120
''', 'THB');
      expect(g.amountMinor, 12000);
      expect(g.date, isNull); // later than today, so not trusted
      expect(g.merchant, 'Night Market Stall');
    });
  });

  group('edge cases', () {
    test('nothing readable gives an empty guess', () {
      final g = read('   \n ### \n', 'INR');
      expect(g.amountMinor, isNull);
      expect(g.date, isNull);
      expect(g.merchant, isNull);
      expect(g.isEmpty, isTrue);
    });

    test('yen has no decimals', () {
      expect(read('Ramen Ichiran\nTOTAL ¥1,980', 'JPY').amountMinor, 1980);
    });
  });
}
