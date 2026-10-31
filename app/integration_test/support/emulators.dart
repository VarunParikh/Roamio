import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/features/auth/data/auth_service.dart';

/// Talks to the local Firebase emulators over REST, the way the other people
/// in a journey would: the joiner, the parent, the second squad member.
///
/// The app identifies itself by the project in the dev `google-services.json`,
/// so the emulators run under that ID (`firebase emulators:start -P dev`).
/// The Android emulator reaches the Mac's localhost at 10.0.2.2.
const project = 'roamio-dev-varun';
const _host = '10.0.2.2';
const _authBase = 'http://$_host:9099';
const _docsBase =
    'http://$_host:8080/v1/projects/$project/databases/(default)/documents';
const _functionsBase = 'http://$_host:5001/$project/asia-south1';

/// Emulator-only token that skips security rules (like the Admin SDK).
const _owner = 'owner';

final _http = HttpClient()..connectionTimeout = const Duration(seconds: 10);

/// Long enough for a function's cold start. A silent emulator otherwise hangs
/// the journey with no error at all.
const _answerWithin = Duration(seconds: 60);
var _n = 0;

/// A unique, readable email for this run.
String uniqueEmail(String name) =>
    '${name.toLowerCase()}.${DateTime.now().millisecondsSinceEpoch}'
    '.${_n++}@example.com';

const password = 'secret-pass-123';

/// Someone simulated outside the app, signed in over REST.
class Person {
  new(this.uid, this.email, this.name, this.idToken);

  final String uid;
  final String email;
  final String name;
  String idToken;

  /// Signs in again so the ID token carries fresh claims (email_verified).
  Future<void> refresh() async {
    idToken = (await signIn(email))['idToken'] as String;
  }
}

Future<Map<String, dynamic>> _send(
  String method,
  String url, {
  Object? body,
  String? token,
  bool allowError = false,
}) async {
  final request = await _http.openUrl(method, Uri.parse(url));
  // The emulators close idle connections; reusing one fails at random.
  request.persistentConnection = false;
  request.headers.contentType = ContentType.json;
  if (token != null) request.headers.set('Authorization', 'Bearer $token');
  if (body != null) request.write(jsonEncode(body));
  Never noAnswer() =>
      throw HttpException('$method $url → no answer in $_answerWithin');
  final response = await request.close().timeout(
    _answerWithin,
    onTimeout: noAnswer,
  );
  final text = await response
      .transform(utf8.decoder)
      .join()
      .timeout(_answerWithin, onTimeout: noAnswer);
  final json = text.isEmpty
      ? <String, dynamic>{}
      : jsonDecode(text) is Map<String, dynamic>
      ? jsonDecode(text) as Map<String, dynamic>
      : <String, dynamic>{'list': jsonDecode(text)};
  if (response.statusCode >= 300 && !allowError) {
    throw HttpException('$method $url → ${response.statusCode}: $text');
  }
  return {...json, '_status': response.statusCode};
}

/// Clears every account and document, so a run starts from nothing. The
/// Firestore emulator now and then answers a clear with a 500, so it retries.
Future<void> resetEmulators() async {
  for (var attempt = 1; ; attempt++) {
    try {
      await _send(
        'DELETE',
        'http://$_host:8080/emulator/v1/projects/$project/databases/(default)/documents',
      );
      break;
    } on HttpException {
      if (attempt == 3) rethrow;
      await Future<void>.delayed(const Duration(seconds: 2));
    }
  }
  await _send('DELETE', '$_authBase/emulator/v1/projects/$project/accounts');
}

/// Fails fast with a clear message when the emulators aren't running.
Future<void> expectEmulatorsUp() async {
  try {
    await _send('GET', '$_functionsBase/health');
  } on Object catch (e) {
    fail(
      'Firebase emulators not reachable from the device ($e). Start them '
      'with tool/e2e.sh or `firebase emulators:start -P dev` (docs/SETUP.md).',
    );
  }
}

Future<Map<String, dynamic>> signIn(String email) => _send(
  'POST',
  '$_authBase/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=fake',
  body: {'email': email, 'password': password, 'returnSecureToken': true},
);

/// Marks an email as verified, as clicking the emailed link would.
Future<void> verifyEmail(String uid) => _send(
  'POST',
  '$_authBase/identitytoolkit.googleapis.com/v1/projects/$project/accounts:update',
  token: _owner,
  body: {'localId': uid, 'emailVerified': true},
);

/// The auth account with [email], or null once it has been deleted.
Future<String?> uidForEmail(String email) async {
  final res = await _send(
    'POST',
    '$_authBase/identitytoolkit.googleapis.com/v1/projects/$project/accounts:lookup',
    token: _owner,
    body: {
      'email': [email],
    },
  );
  final users = res['users'] as List<dynamic>?;
  return users == null || users.isEmpty
      ? null
      : (users.first as Map<String, dynamic>)['localId'] as String;
}

/// A verified email account with a profile, set up as the app would. The
/// server's `setAgeStatus` trigger then sets the age status from [dob].
Future<Person> createPerson(
  String name, {
  String dob = '1995-06-15',
  String profileCurrency = 'INR',
  String expectStatus = 'adult',
}) async {
  final email = uniqueEmail(name.split(' ').first);
  final created = await _send(
    'POST',
    '$_authBase/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake',
    body: {
      'email': email,
      'password': password,
      'displayName': name,
      'returnSecureToken': true,
    },
  );
  final uid = created['localId'] as String;
  await verifyEmail(uid);
  await setDoc('users/$uid', {'name': name, 'photoUrl': null, 'bio': ''});
  await setDoc('users/$uid/private/account', {
    'dob': dob,
    'profileCurrency': profileCurrency,
    'consents': <String, Object?>{},
    'noticeVersion': privacyNoticeVersion,
    'createdAt': DateTime.now().toUtc(),
  });
  await eventually(
    'age status of $name is $expectStatus',
    () async =>
        (await getDoc('users/$uid/private/account'))?['ageStatus'] ==
        expectStatus,
  );
  final person = Person(uid, email, name, '');
  await person.refresh();
  return person;
}

// ---------------------------------------------------------------- Firestore

Object? _encode(Object? v) => switch (v) {
  null => {'nullValue': null},
  final bool b => {'booleanValue': b},
  final int i => {'integerValue': '$i'},
  final double d => {'doubleValue': d},
  final String s => {'stringValue': s},
  final DateTime t => {'timestampValue': t.toUtc().toIso8601String()},
  final List<Object?> l => {
    'arrayValue': {'values': l.map(_encode).toList()},
  },
  final Map<String, Object?> m => {
    'mapValue': {'fields': m.map((k, v) => MapEntry(k, _encode(v)))},
  },
  _ => throw ArgumentError('Can’t encode $v'),
};

Object? _decode(Map<String, dynamic> v) {
  final MapEntry(:key, :value) = v.entries.first;
  return switch (key) {
    'nullValue' => null,
    'booleanValue' => value as bool,
    'integerValue' => int.parse(value as String),
    'doubleValue' => (value as num).toDouble(),
    'stringValue' || 'timestampValue' || 'referenceValue' => value as String,
    'arrayValue' => [
      for (final e
          in ((value as Map<String, dynamic>)['values'] as List<dynamic>? ??
              const []))
        _decode(e as Map<String, dynamic>),
    ],
    'mapValue' => _fields(value as Map<String, dynamic>),
    _ => value,
  };
}

Map<String, Object?> _fields(Map<String, dynamic> doc) => {
  for (final MapEntry(:key, :value)
      in ((doc['fields'] as Map<String, dynamic>?) ?? const {}).entries)
    key: _decode(value as Map<String, dynamic>),
};

/// Writes a whole document, skipping security rules (like the Admin SDK).
Future<void> setDoc(String path, Map<String, Object?> data) => _send(
  'PATCH',
  '$_docsBase/$path',
  token: _owner,
  body: {'fields': data.map((k, v) => MapEntry(k, _encode(v)))},
);

/// Creates a document as [as], through the security rules. Returns the HTTP
/// status, so a test can check the rules refuse it.
Future<int> createDocAs(
  Person as,
  String collectionPath,
  Map<String, Object?> data,
) async {
  final res = await _send(
    'POST',
    '$_docsBase/$collectionPath',
    token: as.idToken,
    allowError: true,
    body: {'fields': data.map((k, v) => MapEntry(k, _encode(v)))},
  );
  return res['_status'] as int;
}

/// Reads a document, skipping rules, or as [as] through the rules. Null when
/// it doesn't exist (or [as] may not read it: see [readStatus]).
Future<Map<String, Object?>?> getDoc(String path, {Person? as}) async {
  final res = await _send(
    'GET',
    '$_docsBase/$path',
    token: as?.idToken ?? _owner,
    allowError: true,
  );
  return res['_status'] == 200 ? _fields(res) : null;
}

/// The HTTP status for [as] reading [path]: 200, 403 (rules) or 404.
Future<int> readStatus(String path, Person as) async {
  final res = await _send(
    'GET',
    '$_docsBase/$path',
    token: as.idToken,
    allowError: true,
  );
  return res['_status'] as int;
}

/// Every document in a collection, as [as] through the rules or skipping
/// them. Each map has its document id under `id`.
Future<List<Map<String, Object?>>> listDocs(
  String collectionPath, {
  Person? as,
}) async {
  final res = await _send(
    'GET',
    '$_docsBase/$collectionPath?pageSize=300',
    token: as?.idToken ?? _owner,
  );
  return [
    for (final d in (res['documents'] as List<dynamic>? ?? const []))
      {
        'id': ((d as Map<String, dynamic>)['name'] as String).split('/').last,
        ..._fields(d),
      },
  ];
}

/// The tabs [as] may list, through the rules: the rules refuse a list that
/// could include someone's personal or rejected tab (spec UC-21a).
Future<List<Map<String, Object?>>> sharedTabs(
  String adventureId, {
  required Person as,
}) async {
  final res = await _send(
    'POST',
    '$_docsBase/adventures/$adventureId:runQuery',
    token: as.idToken,
    body: {
      'structuredQuery': {
        'from': [
          {'collectionId': 'tabs'},
        ],
        'where': {
          'fieldFilter': {
            'field': {'fieldPath': 'status'},
            'op': 'IN',
            'value': {
              'arrayValue': {
                'values': [
                  {'stringValue': 'waiting'},
                  {'stringValue': 'approved'},
                ],
              },
            },
          },
        },
      },
    },
  );
  return [
    for (final row in (res['list'] as List<dynamic>? ?? const []))
      if ((row as Map<String, dynamic>)['document']
          case final Map<String, dynamic> d)
        {'id': (d['name'] as String).split('/').last, ..._fields(d)},
  ];
}

// ---------------------------------------------------------------- Functions

/// Calls a callable Cloud Function as [as]; throws on an error result.
Future<Map<String, Object?>> call(
  String name,
  Map<String, Object?> data, {
  required Person as,
}) async {
  final res = await _send(
    'POST',
    '$_functionsBase/$name',
    token: as.idToken,
    body: {'data': data},
    allowError: true,
  );
  if (res['error'] != null) {
    throw HttpException('$name failed: ${res['error']}');
  }
  return (res['result'] as Map<String, dynamic>?) ?? const {};
}

// ------------------------------------------------------------------- Seeds

String isoDay(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// An adventure led by [leader] that is happening now, as the app creates
/// it; [members] join through a real invite. Returns its id.
Future<String> seedAdventure(
  Person leader, {
  required String name,
  String countryCode = 'IN',
  String currency = 'INR',
  List<Person> members = const [],
}) async {
  final today = DateTime.now();
  final id = 'e2e${DateTime.now().microsecondsSinceEpoch}';
  await setDoc('adventures/$id', {
    'name': name,
    'description': '',
    'countryCode': countryCode,
    'city': '',
    'startDate': isoDay(today.subtract(const Duration(days: 1))),
    'endDate': isoDay(today.add(const Duration(days: 6))),
    'baseCurrency': currency,
    'bannerUrl': null,
    'createdBy': leader.uid,
    'createdAt': DateTime.now().toUtc(),
    'leaderUid': leader.uid,
    'coLeadUids': <String>[],
    'memberUids': [leader.uid],
  });
  if (members.isNotEmpty) {
    final invite = await call('createInvite', {'adventureId': id}, as: leader);
    for (final m in members) {
      await call('joinAdventure', {'code': invite['code']}, as: m);
    }
  }
  return id;
}

/// Exchange rates for [day] in the shape `dailyFxRates` stores (units per
/// USD as exact decimal text).
Future<void> seedFxRates(DateTime day, Map<String, String> rates) =>
    setDoc('fx_rates/${isoDay(day)}', {
      'date': isoDay(day),
      'rates': rates,
      'source': 'e2e',
      'fetchedAt': DateTime.now().toUtc(),
    });

/// Polls [check] until it holds, for server triggers and syncs to land.
Future<void> eventually(
  String what,
  Future<bool> Function() check, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final end = DateTime.now().add(timeout);
  while (true) {
    if (await check()) return;
    if (DateTime.now().isAfter(end)) fail('Timed out waiting for: $what');
    await Future<void>.delayed(const Duration(milliseconds: 400));
  }
}

/// A tab as the app writes it: [amountMinor] paid by [payer], split
/// equally between [participants], dated today.
Map<String, Object?> tabDoc({
  required String createdBy,
  required int amountMinor,
  required List<String> participants,
  String? payer,
  String currency = 'INR',
  String description = '',
  Map<String, Object?>? location,
  String status = 'waiting',
}) {
  final today = isoDay(DateTime.now());
  final now = DateTime.now().toUtc();
  return {
    'description': description,
    'category': 'food_dining',
    'amountMinor': amountMinor,
    'currency': currency,
    'date': today,
    'fxDate': today,
    'payers': [
      {'id': payer ?? createdBy, 'amountMinor': amountMinor},
    ],
    'participants': participants,
    'percentBp': null,
    'location': ?location,
    'memories': <String>[],
    'createdBy': createdBy,
    'createdAt': now,
    'updatedAt': now,
    'deleted': false,
    'status': status,
  };
}
