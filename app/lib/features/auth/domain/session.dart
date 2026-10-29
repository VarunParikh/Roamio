/// Where a person is in getting into Roamio (spec UC-1–4, §7).
enum SessionStage {
  loading,
  signedOut,
  verifyEmail,
  needsProfile,
  settingUp,
  awaitingConsent,

  /// A parent withdrew consent; the account is deleted after 48 hours.
  paused,

  /// Turned 18; must accept the adult privacy notice (spec §7.4).
  confirmAdult,
  ready,
}

/// What the app currently knows about the signed-in person.
class SessionFacts {
  const new({
    required this.uid,
    this.usesPassword = false,
    this.emailVerified = true,
    this.accountLoaded = true,
    this.hasAccount = false,
    this.ageStatus,
    this.authLoaded = true,
  });

  const new loading()
    : this(uid: null, accountLoaded: false, authLoaded: false);

  const new signedOut() : this(uid: null);

  final bool authLoaded;
  final String? uid;
  final bool usesPassword;
  final bool emailVerified;
  final bool accountLoaded;

  /// Whether `users/{uid}/private/account` exists.
  final bool hasAccount;

  /// Server-set: `adult`, `minor_pending` or `minor_active`.
  final String? ageStatus;
}

SessionStage stageFor(SessionFacts f) {
  if (!f.authLoaded) return SessionStage.loading;
  if (f.uid == null) return SessionStage.signedOut;
  if (f.usesPassword && !f.emailVerified) return SessionStage.verifyEmail;
  if (!f.accountLoaded) return SessionStage.loading;
  if (!f.hasAccount) return SessionStage.needsProfile;
  return switch (f.ageStatus) {
    'adult' || 'minor_active' => SessionStage.ready,
    'minor_pending' => SessionStage.awaitingConsent,
    'minor_frozen' => SessionStage.paused,
    'adult_unconfirmed' => SessionStage.confirmAdult,
    _ => SessionStage.settingUp,
  };
}

abstract final class AuthRoutes {
  static const splash = '/splash';
  static const login = '/login';
  static const loginEmail = '/login/email';
  static const signup = '/signup';
  static const verifyEmail = '/verify-email';
  static const completeProfile = '/complete-profile';
  static const consentPending = '/consent-pending';
  static const accountPaused = '/account-paused';
  static const confirmAdult = '/welcome-adult';

  /// A parent's consent link: `/consent?c=<childUid>&t=<token>` (spec §7.1).
  static const consent = '/consent';
  static const home = '/home';
}

const Set<String> _signedOutRoutes = {
  AuthRoutes.login,
  AuthRoutes.loginEmail,
  AuthRoutes.signup,
};

const Set<String> _onboardingRoutes = {
  AuthRoutes.splash,
  ..._signedOutRoutes,
  AuthRoutes.verifyEmail,
  AuthRoutes.completeProfile,
  AuthRoutes.consentPending,
  AuthRoutes.accountPaused,
  AuthRoutes.confirmAdult,
};

/// The route to send someone at [stage] to, or null to stay on [location].
String? redirectFor(SessionStage stage, String location) {
  String? only(String route) => location == route ? null : route;
  return switch (stage) {
    SessionStage.loading || SessionStage.settingUp => only(AuthRoutes.splash),
    SessionStage.signedOut =>
      _signedOutRoutes.contains(location) ? null : AuthRoutes.login,
    SessionStage.verifyEmail => only(AuthRoutes.verifyEmail),
    SessionStage.needsProfile => only(AuthRoutes.completeProfile),
    SessionStage.awaitingConsent => only(AuthRoutes.consentPending),
    SessionStage.paused => only(AuthRoutes.accountPaused),
    SessionStage.confirmAdult => only(AuthRoutes.confirmAdult),
    SessionStage.ready =>
      _onboardingRoutes.contains(location) ? AuthRoutes.home : null,
  };
}

/// Links that should still open after the person signs in: parental
/// consent and squad invites (`/i/<code>`).
bool _isDeepLink(String path) =>
    path == AuthRoutes.consent || path.startsWith('/i/');

/// Like [redirectFor], but remembers a deep link ([pending]) while someone
/// signs in, and opens it once they're ready.
({String? redirect, String? pending}) resolveRoute(
  SessionStage stage,
  Uri uri, {
  required String? pending,
}) {
  final redirect = redirectFor(stage, uri.path);
  if (stage == SessionStage.ready) {
    final open = pending != null && pending != uri.toString();
    return (redirect: open ? pending : redirect, pending: null);
  }
  final remember = _isDeepLink(uri.path) && redirect != null;
  return (redirect: redirect, pending: remember ? uri.toString() : pending);
}
