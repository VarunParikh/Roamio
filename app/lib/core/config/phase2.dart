import 'package:flutter_riverpod/flutter_riverpod.dart';

// Phase 2 features, switched off for the Android pilot (owner, 2026-10-30).
// They come back with the web app; their code, rules and tests stay, so
// turning one on is a one-line change here. See docs/ROADMAP.md.

/// Under-18 accounts: sign-up asks a date of birth, ages 13–17 need a
/// parent's consent, and parents see Linked children (spec §7). Off (the
/// pilot): no date of birth is asked and nobody is refused; the sign-up tick
/// records "I'm 18 or older" instead (owner, 2026-10-30, option B).
final minorsEnabledProvider = Provider<bool>((ref) => false);

/// Nominate a person in the Privacy centre (spec UC-29, DPDP §14).
final nomineeEnabledProvider = Provider<bool>((ref) => false);
