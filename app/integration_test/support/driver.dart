import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/core/connectivity/connectivity_monitor.dart';
import 'package:roamio/features/tabs/domain/payment_method.dart';
import 'package:roamio/main.dart' as app;
import 'package:share_plus/share_plus.dart';

import 'emulators.dart' as emulators;

/// A connection the test switches on and off. The app reacts exactly as it
/// does to the real one: the sync controller turns Firestore's network off
/// (`disableNetwork`) and offers Sync when it comes back.
class ScriptedConnection implements ConnectivityMonitor {
  final _changes = StreamController<bool>.broadcast();
  bool online = true;

  void set({required bool online}) {
    this.online = online;
    _changes.add(online);
  }

  @override
  Stream<bool> get changes => _changes.stream;

  @override
  Future<bool> check() async => online;
}

/// What the app handed to the share sheet.
class Shared {
  final texts = <String>[];
  final files = <List<XFile>>[];
  final names = <List<String>>[];
}

/// Starts the real app (Firebase emulators, `--dart-define=USE_EMULATORS=true`)
/// signed out, with a scripted connection and share sheet.
Future<Shared> launch(
  WidgetTester tester, {
  ScriptedConnection? connection,
  bool phase2 = false,
}) async {
  final shared = Shared();
  await app.runRoamio(
    phase2: phase2,
    connectivity: connection ?? ScriptedConnection(),
    shareText: (text) async => shared.texts.add(text),
    shareFiles: (files, names) async {
      shared.files.add(files);
      shared.names.add(names);
    },
  );
  // A previous run may have left someone signed in on the device.
  if (FirebaseAuth.instance.currentUser != null) {
    await FirebaseAuth.instance.signOut();
  }
  await tester.pump();
  return shared;
}

/// Signs the app out between journeys.
Future<void> signOut(WidgetTester tester) async {
  await FirebaseAuth.instance.signOut();
  await settle(tester, const Duration(seconds: 1));
}

/// Pumps frames for [time] while real async work (network, Firestore)
/// carries on. `pumpAndSettle` can't be used: Firestore streams keep it busy.
Future<void> settle(
  WidgetTester tester, [
  Duration time = const Duration(milliseconds: 400),
]) async {
  final end = DateTime.now().add(time);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Pumps until [finder] matches something, or fails listing what's on screen.
Future<void> waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final end = DateTime.now().add(timeout);
  while (finder.evaluate().isEmpty) {
    if (DateTime.now().isAfter(end)) {
      fail('Never saw $finder. On screen: ${visibleTexts().join(' | ')}');
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Pumps until [finder] matches nothing.
Future<void> waitForGone(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final end = DateTime.now().add(timeout);
  while (finder.evaluate().isNotEmpty) {
    if (DateTime.now().isAfter(end)) {
      fail('Still showing $finder. On screen: ${visibleTexts().join(' | ')}');
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Every text on screen, for failure messages.
List<String> visibleTexts() => [
  for (final e in find.byType(Text).evaluate())
    if ((e.widget as Text).data case final String s) s,
];

/// Waits for [finder], scrolls it into view and taps the first match.
/// A button that is briefly busy (its label swapped for a spinner) is
/// waited for again rather than missed. So is a target the layout moved out
/// from under the tap: a keyboard that is still opening shrinks the list
/// after it scrolled, and can leave the target behind a pinned button.
Future<void> tapOn(WidgetTester tester, Finder finder) async {
  for (var attempt = 1; ; attempt++) {
    await waitFor(tester, finder);
    await tester.ensureVisible(finder.first);
    await settle(tester, const Duration(milliseconds: 300));
    if (finder.first.hitTestable().evaluate().isNotEmpty || attempt == 10) {
      break;
    }
  }
  await tester.tap(finder.first);
  await settle(tester);
}

Future<void> tapText(WidgetTester tester, String text) =>
    tapOn(tester, find.text(text));

/// Scrolls the screen's main list until [finder] is built.
Future<void> scrollTo(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 30 && finder.evaluate().isEmpty; i++) {
    await tester.drag(
      find.byType(Scrollable).last,
      const Offset(0, -250),
      warnIfMissed: false,
    );
    await settle(tester, const Duration(milliseconds: 200));
  }
  await waitFor(tester, finder);
  await tester.ensureVisible(finder.first);
  await settle(tester, const Duration(milliseconds: 200));
}

/// Types into a text field found by its label.
Future<void> typeInto(WidgetTester tester, String label, String text) async {
  final field = find.widgetWithText(TextField, label);
  await waitFor(tester, field);
  await tester.ensureVisible(field.first);
  await tester.enterText(field.first, text);
  await settle(tester, const Duration(milliseconds: 200));
}

/// Types into the field with [key] (payer and percentage fields).
Future<void> typeIntoKey(WidgetTester tester, String key, String text) async {
  final field = find.byKey(ValueKey(key));
  await waitFor(tester, field);
  await tester.ensureVisible(field);
  await tester.enterText(field, text);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await settle(tester, const Duration(milliseconds: 200));
}

/// Fills Material's date picker in typing mode (en_US: MM/DD/YYYY).
String usDate(DateTime d) =>
    '${d.month.toString().padLeft(2, '0')}/'
    '${d.day.toString().padLeft(2, '0')}/${d.year}';

/// Signs in through "Sign in with email".
Future<void> signInWithEmail(
  WidgetTester tester,
  String email,
  String password,
) async {
  await tapText(tester, 'Sign in with email');
  await typeInto(tester, 'Email', email);
  await typeInto(tester, 'Password', password);
  await tapOn(tester, find.text('Sign in').last);
}

/// Creates an email account through "New here? Create an account", then
/// verifies the email (the emulator sends nothing) and returns the uid.
/// Without [dob] it signs up the pilot way: no date of birth, just the
/// "I'm 18 or older" tick. Phase 2 journeys (launched with `phase2: true`)
/// pass a [dob].
Future<String> signUpWithEmail(
  WidgetTester tester, {
  required String name,
  required String email,
  DateTime? dob,
}) async {
  await tapText(tester, 'New here? Create an account');
  await typeInto(tester, 'Your name', name);
  await typeInto(tester, 'Email', email);
  await typeInto(tester, 'Password', emulators.password);
  if (dob != null) {
    await tapText(tester, 'Choose a date');
    await tester.enterText(find.byType(TextField).last, usDate(dob));
    await tapText(tester, 'OK');
  } else {
    await waitFor(tester, find.text('I’m 18 or older and I’ve read the '));
  }
  await tapOn(tester, find.byType(Checkbox));
  expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
  await tapText(tester, 'Create account');

  await waitFor(tester, find.text('I’ve verified my email'));
  final uid = (await emulators.uidForEmail(email))!;
  await emulators.verifyEmail(uid);
  // The app may notice on its own (a token refresh); otherwise tap.
  final verified = find.text('I’ve verified my email');
  await settle(tester);
  if (verified.evaluate().isNotEmpty) {
    await tester.tap(verified.first, warnIfMissed: false);
  }
  await waitForGone(tester, verified);
  return uid;
}

/// Opens the adventure called [name] from Home.
Future<void> openAdventure(WidgetTester tester, String name) async {
  await waitFor(tester, find.text(name));
  await tester.ensureVisible(find.text(name).first);
  await settle(tester, const Duration(milliseconds: 300));
  // The hero card's text sits under its tappable overlay.
  await tester.tap(find.text(name).first, warnIfMissed: false);
  await waitFor(tester, find.textContaining('Squad ('));
}

/// Adds a tab from an open adventure page: [amount] in [currency] (null =
/// the trip's), Food & Dining, paid by you, split equally between everyone.
Future<void> addSimpleTab(
  WidgetTester tester, {
  required String amount,
  required String description,
  String? currency,
}) async {
  await scrollTo(tester, find.text('Add tab'));
  await tapText(tester, 'Add tab');
  await typeInto(tester, 'Amount', amount);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  if (currency != null) await pickCurrency(tester, currency);
  await tapOn(tester, find.textContaining('Food & Dining'));
  await typeInto(tester, 'Description (optional)', description);
  await pickPaidWith(
    tester,
    find.byType(DropdownButtonFormField<PaymentMethod>),
  );
  await saveTab(tester);
}

/// Chooses [item] in a Paid with menu. A fresh install has no method yet, so
/// Save stays disabled until this is done.
Future<void> pickPaidWith(
  WidgetTester tester,
  Finder dropdown, {
  String item = '💵 Cash',
}) async {
  await tapOn(tester, dropdown);
  await tapOn(tester, find.text(item).last);
}

/// Picks [currency] in the tab's currency menu, which opens at the
/// selected one and builds lazily, so it scrolls up, then down, to find it.
Future<void> pickCurrency(WidgetTester tester, String currency) async {
  await tapOn(tester, find.byType(DropdownButtonFormField<String>));
  final item = find.text(currency);
  for (final dy in [300.0, -300.0]) {
    for (var i = 0; i < 40 && item.evaluate().isEmpty; i++) {
      await tester.drag(
        find.byType(Scrollable).last,
        Offset(0, dy),
        warnIfMissed: false,
      );
      await settle(tester, const Duration(milliseconds: 150));
    }
  }
  await tapOn(tester, item.last);
}

Future<void> saveTab(WidgetTester tester) async {
  await tapText(tester, 'Save tab');
  await waitForGone(tester, find.text('Save tab'));
}
