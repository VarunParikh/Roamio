// App copy of firebase/functions/src/invites/code.ts — keep the two in step.

/// No 0/O, 1/I/L: easy to read aloud and type from a screenshot.
const _alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
final _whole = RegExp('^[$_alphabet]{8}\$');
final _inLink = RegExp(r'/i/([^/?#\s]+)');
final _inText = RegExp('\\b([$_alphabet]{4})-?([$_alphabet]{4})\\b');

/// A Roamio invite code from whatever was typed or pasted: the bare code in
/// any case, with or without a dash, an invite link, or a shared message
/// containing either. Null when there's no code in it.
String? normaliseCode(String input) {
  final link = _inLink.firstMatch(input)?.group(1);
  if (link != null) return _clean(link);
  final typed = _clean(input);
  if (typed != null) return typed;
  final found = _inText.firstMatch(input);
  return found == null ? null : '${found[1]}${found[2]}';
}

String? _clean(String text) {
  final code = text.toUpperCase().replaceAll(RegExp(r'[\s-]'), '');
  return _whole.hasMatch(code) ? code : null;
}

/// "7KQ2M9XA" → "7KQ2-M9XA".
String formatCode(String code) =>
    '${code.substring(0, 4)}-${code.substring(4)}';

String inviteLink(String siteUrl, String code) => '$siteUrl/i/$code';

/// What the share sheet sends to the squad (spec UC-9).
String inviteMessage({
  required String adventureName,
  required String link,
  required String code,
}) =>
    'Join my Roamio adventure “$adventureName”! 🎒\n'
    '$link\n'
    'Or enter code ${formatCode(code)} in the app.';
