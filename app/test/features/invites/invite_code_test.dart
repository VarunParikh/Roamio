import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/features/invites/domain/invite_code.dart';

void main() {
  test('accepts codes however they were typed or pasted', () {
    expect(normaliseCode(' 7kq2-m9xa '), '7KQ2M9XA');
    expect(normaliseCode('7KQ2 M9XA'), '7KQ2M9XA');
    expect(
      normaliseCode('Join me! https://roamio-dev-varun.web.app/i/7KQ2M9XA'),
      '7KQ2M9XA',
    );
    expect(normaliseCode('hello'), isNull);
    expect(normaliseCode('7KQ2M9X0'), isNull);
    expect(normaliseCode(''), isNull);
  });

  test('finds a code inside a longer pasted message', () {
    expect(
      normaliseCode('Join my Roamio adventure! Code: 7KQ2-M9XA'),
      '7KQ2M9XA',
    );
  });

  test('shows codes in two groups of four', () {
    expect(formatCode('7KQ2M9XA'), '7KQ2-M9XA');
  });

  test('builds the shareable link and message', () {
    expect(
      inviteLink('https://roamio-dev-varun.web.app', '7KQ2M9XA'),
      'https://roamio-dev-varun.web.app/i/7KQ2M9XA',
    );
    expect(
      inviteMessage(
        adventureName: 'Bangkok trip',
        link: 'https://x.web.app/i/7KQ2M9XA',
        code: '7KQ2M9XA',
      ),
      'Join my Roamio adventure “Bangkok trip”! 🎒\n'
      'https://x.web.app/i/7KQ2M9XA\n'
      'Or enter code 7KQ2-M9XA in the app.',
    );
  });
}
