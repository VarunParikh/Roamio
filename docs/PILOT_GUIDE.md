# Roamio Pilot Guide

Thanks for trying Roamio before anyone else! Roamio splits travel costs
with friends: add what you spend, and it works out who owes whom, in any
currency. This pilot is about 10 people using it on a real (or pretend)
trip, so we can find what's broken or confusing before a wider launch.

Part 1 is for pilot testers. Part 2 is for the owner, who runs the pilot.

---

## Part 1 — For testers

### What you need
- An Android phone running **Android 8.0 or newer**. iPhones aren't
  supported yet.
- An email address or a Google account.
- You must be **18 or older**. The pilot is for adults only.

### 1. Install Roamio
Roamio isn't on the Play Store yet, so you install it from a file (an APK).

1. On your phone, open the download link the owner sent you. It points to
   the latest release at
   [github.com/VarunParikh/Roamio/releases](https://github.com/VarunParikh/Roamio/releases).
2. Under **Assets**, tap `Roamio-vX.Y.Z.apk` to download it.
3. Open the downloaded file. If Android asks, allow your browser (or Files
   app) to **install unknown apps**, then go back and tap **Install**.

**About the Play Protect warning:** Android may show "Unsafe app blocked"
or "App scanned by Play Protect" because Roamio doesn't come from the Play
Store. That's expected for a pilot app. Tap **More details → Install
anyway**. If you don't see that option, tell the owner rather than
changing any security settings.

### 2. Sign up
- Tap **Continue with Google**, or **New here? Create an account** to use an
  email and password. With email, open the verification link we send you,
  then tap **I've verified my email**.
- Tick **I'm 18 or older and I've read the privacy notice**. Roamio doesn't
  ask for your date of birth.

### 3. Join or start a trip ("adventure")
- **Got an invite link?** Open it on your phone, or copy it and tap **Have
  an invite code?** on Home, paste it, then **Join squad**.
- **Starting a trip?** Tap **New Adventure**, pick the country, name and
  dates, then **Share invite** to send the link to your squad.

### 4. Things to try
Use it the way you would on a trip. In particular:
- Add tabs (expenses) in different currencies; try **Split payment** (two
  people paid) and **Custom %**.
- Add a **pal**: a friend without the app, added by nickname.
- Open **Split** to see who pays whom, and **Mark as settled** when money
  changes hands. Roamio never moves money itself.
- Set a private **budget** (only you can see it).
- Turn on airplane mode, add a tab, turn it off again and tap **Sync**.
- Look around **You → Privacy centre**: download your data.

### 5. Report a problem or an idea
Use the **feedback form** (link from the owner) for anything: a crash,
something wrong in the maths, a confusing screen, an idea. Please include:
- what you were doing, and what you expected to happen;
- what happened instead;
- your phone model and Roamio version (Android **Settings → Apps →
  Roamio** shows it, or the release you downloaded, e.g. `v1.0.0`);
- a screenshot, if it helps.

**Don't put other people's personal details in reports** (names, emails,
amounts from a real trip) unless they're happy with that, and never send
passwords. If something looks like a privacy or security problem, say so
in the form and the owner will deal with it first.

### Updates
When there's a new version, Roamio offers it when you open the app (at most
once a day). Tap it to download and install over the old one: your data
stays. Sometimes an update is required before you can carry on.

### Leaving the pilot
**You → Privacy centre → Delete my account** removes your profile, photos
and budgets. Tabs you were on stay with the squad as "Deleted user", so
everyone's balances stay right. Download your data first if you want a copy.

Your privacy: read the privacy notice in **You → Privacy centre**. Questions
or complaints go to the grievance contact listed there.

---

## Part 2 — For the owner

### Before inviting anyone
- [ ] **Release:** the Task 42 steps in [RELEASING.md](RELEASING.md) are done,
  and `v1.0.0` (or a release candidate) is published with an APK that
  installs on a real phone.
- [ ] **Google sign-in:** the release key's SHA-1/SHA-256 is added to the prod
  Firebase app, and Google sign-in works on the installed APK.
- [ ] **Hosting:** the prod site (`roamio-prod-varun.web.app`) is deployed, so
  invite links (`/i/…`) and the privacy page open for people without the app.
- [ ] **Grievance email:** a real address replaces `grievance@roamio.example`
  in the privacy notice, on the website and in the app.
- [ ] **Feedback form:** created (for example a Google Form, so testers don't
  need a GitHub account and reports stay private), with the questions in
  "Feedback form" below. Put its link in your invite message.
- [ ] **Remote Config:** keys set in the prod console ([REMOTE_CONFIG.md](REMOTE_CONFIG.md)).
- [ ] Your own manual test session (the device checks in `tasks/HANDOVER.md`)
  has passed.

### Invite message (copy and edit)
> Hi! I'm testing Roamio, an app for splitting trip costs with friends, and
> I'd love your help. It takes 2 minutes to set up on an Android phone.
> Guide: https://github.com/VarunParikh/Roamio/blob/main/docs/PILOT_GUIDE.md
> Download: https://github.com/VarunParikh/Roamio/releases/latest
> Report problems here: <feedback form link>
> You need to be 18 or older to join this pilot.

### Feedback form
Suggested questions:
1. What were you doing? (short text)
2. What did you expect, and what happened instead? (paragraph)
3. How bad is it? (Blocks me / Annoying / Small thing / Idea)
4. Phone model and Roamio version (short text)
5. Screenshot (optional upload)
6. Is this about privacy or security? (Yes / No)
7. Email, if you're happy for us to follow up (optional)

### Triage (weekly, or daily while it's busy)
1. Read new form answers. Privacy or security reports come first: follow
   [BREACH_RESPONSE.md](BREACH_RESPONSE.md) if personal data may be exposed.
2. Copy each real problem into a **GitHub Issue** (the repo is public, so
   leave out names, emails, amounts and screenshots with personal details).
   Labels: `bug`, `ux`, `idea`, plus `blocker` for anything that stops a
   journey.
3. Fix blockers first; ship fixes as a new release ([RELEASING.md](RELEASING.md))
   so the app offers the update.

### When is the pilot done? (Task 44)
- 10 active accounts, each through a real or simulated trip.
- No data loss, and no crash that blocks a journey.
- Spec §15 success criteria 1–9 ticked in `tasks/todo.md` (Checkpoint 6).
