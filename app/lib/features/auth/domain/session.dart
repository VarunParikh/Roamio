/// Where a person is in getting into Roamio (spec UC-1–4, §7).
enum SessionStage {
  loading,
  signedOut,
  verifyEmail,
  needsProfile,
  settingUp,
  awaitingConsent,
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
    SessionStage.ready =>
      _onboardingRoutes.contains(location) ? AuthRoutes.home : null,
  };
}
