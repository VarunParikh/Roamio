import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/features/auth/data/auth_service.dart';
import 'package:roamio/features/auth/domain/session.dart';
import 'package:roamio/features/consent/data/consent_service.dart';
import 'package:roamio/main.dart';

import 'fake_consent_service.dart';

/// In-memory [AuthService]: tests push [SessionFacts] and inspect [calls].
class FakeAuthService implements AuthService {
  new({SessionFacts initial = const SessionFacts.signedOut()})
    : _facts = initial;

  SessionFacts _facts;
  final _changes = StreamController<SessionFacts>.broadcast();
  final List<String> calls = [];

  /// When set, the next action throws this failure.
  AuthFailure? failNext;
  bool verified = false;

  void emit(SessionFacts facts) {
    _facts = facts;
    _changes.add(facts);
  }

  Future<void> _act(String call) async {
    calls.add(call);
    final failure = failNext;
    failNext = null;
    if (failure != null) throw AuthException(failure);
  }

  @override
  Stream<SessionFacts> session() async* {
    yield _facts;
    yield* _changes.stream;
  }

  @override
  String? get email => 'ari@example.com';

  @override
  String? get displayName => 'Ari Chen';

  @override
  Future<void> signInWithGoogle() => _act('google');

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) => _act('email:$email');

  @override
  Future<void> sendPasswordReset(String email) => _act('reset:$email');

  @override
  Future<void> createAccount({
    required String name,
    required String email,
    required String password,
    required DateTime dob,
  }) => _act('create:$name:$email:${dob.year}-${dob.month}-${dob.day}');

  @override
  Future<void> completeProfile({required DateTime dob}) =>
      _act('complete:${dob.year}-${dob.month}-${dob.day}');

  @override
  Future<void> sendVerificationEmail() => _act('resend');

  @override
  Future<bool> refreshUser() async {
    await _act('refresh');
    return verified;
  }

  @override
  Future<void> signOut() => _act('signOut');

  @override
  Future<void> deleteCurrentUser() => _act('delete');
}

const readyFacts = SessionFacts(
  uid: 'ari',
  hasAccount: true,
  ageStatus: 'adult',
);

/// Pumps the whole app with [auth] and a fixed "today" of 29 Oct 2026.
/// Pass `settle: false` on the splash screen, whose spinner never settles.
Future<void> pumpRoamio(
  WidgetTester tester,
  FakeAuthService auth, {
  bool settle = true,
  FakeConsentService? consent,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authServiceProvider.overrideWithValue(auth),
        consentServiceProvider.overrideWithValue(
          consent ?? FakeConsentService(),
        ),
        todayProvider.overrideWithValue(DateTime(2026, 10, 29)),
      ],
      child: const RoamioApp(),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }
}
