import 'package:flutter_riverpod/flutter_riverpod.dart';

// Phase 2 features, switched off for the Android pilot (owner, 2026-10-30).
// They come back with the web app; their code, rules and tests stay, so
// turning one on is a one-line change here. See docs/core/roadmap.md.

/// Under-18 accounts: sign-up asks a date of birth, ages 13–17 need a
/// parent's consent, and parents see Linked children (spec §7). Off (the
/// pilot): no date of birth is asked and nobody is refused; the sign-up tick
/// records "I'm 18 or older" instead (owner, 2026-10-30, option B).
final minorsEnabledProvider = Provider<bool>((ref) => false);

/// Nominate a person in the Privacy centre (spec UC-29, DPDP §14).
final nomineeEnabledProvider = Provider<bool>((ref) => false);

/// Raise a concern in the Privacy centre, with the grievance officer's email
/// (spec UC-29). Off for the pilot (owner, 2026-10-31), until the real address
/// is set; see docs/core/roadmap.md.
final grievanceEnabledProvider = Provider<bool>((ref) => false);

/// Uploading pictures: your display picture, an adventure's banner and photos
/// on tabs, with Scan bill attaching the bill to its tab. Off (the pilot):
/// people choose a character, adventures keep their country photo and Scan bill
/// keeps nothing (owner, 2026-10-30, 2026-10-31). Turning it on also needs
/// `uploadsOpen` in `firebase/storage.rules`; see docs/core/roadmap.md.
final photoUploadsEnabledProvider = Provider<bool>((ref) => false);
