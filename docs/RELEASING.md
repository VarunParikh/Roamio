# Releasing Roamio (Android)

A release is a signed APK on GitHub Releases. Pushing a tag such as `v0.1.0`
makes GitHub build it and publish it ([`.github/workflows/release.yml`](../.github/workflows/release.yml)).
The app's update popup then offers it to everyone on an older version.

Part 1 is done **once**. Part 2 is done for **every** release.

---

## Part 1 — One-time setup (on the Mac)

### 1. Create the upload key

The upload key proves that an update really comes from you. Run this in
Terminal and answer the questions (your name is enough; the rest can be blank):

```bash
/opt/homebrew/opt/openjdk@17/bin/keytool -genkeypair -v -keystore ~/roamio-upload.jks -storetype PKCS12 -alias upload -keyalg RSA -keysize 4096 -validity 10000
```

- It asks for a **password** twice. Use a long one and save it in your password
  manager as "Roamio upload key".
- The file `roamio-upload.jks` is now in your home folder.
- Never put it inside the Roamio project folder or send it to anyone.

### 2. Back it up — in two places

Phones only accept an update that is signed with the **same key** as the app
they already have. If the key is lost, nobody can update: every person would
have to uninstall Roamio and install it again, and Google Play would never
accept it later as the same app. There is no way to recover a lost key.

Keep **two** copies, in two different places, each with the password:

1. Your password manager: add `roamio-upload.jks` as an attachment to the
   "Roamio upload key" entry.
2. A second place you control, for example a USB stick kept at home, or a
   private folder in Google Drive / iCloud.

Check both copies open before you go on.

### 3. Add the GitHub secrets

GitHub needs the key, its password and the prod Firebase file to build a release.
They are stored as encrypted secrets; nobody can read them back, including you.

| Secret name | What to paste |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | the key file as text (command below) |
| `ANDROID_KEYSTORE_PASSWORD` | the password from step 1 |
| `GOOGLE_SERVICES_JSON_PROD` | the whole contents of `app/android/app/src/prod/google-services.json` |

Quickest way: run these in Terminal from the Roamio folder. The second one
asks you to paste the password.

```bash
base64 -i ~/roamio-upload.jks | gh secret set ANDROID_KEYSTORE_BASE64 --repo VarunParikh/Roamio
```

```bash
gh secret set ANDROID_KEYSTORE_PASSWORD --repo VarunParikh/Roamio
```

```bash
gh secret set GOOGLE_SERVICES_JSON_PROD --repo VarunParikh/Roamio < app/android/app/src/prod/google-services.json
```

Or on the website: **github.com/VarunParikh/Roamio → Settings → Secrets and
variables → Actions → New repository secret**, once per row of the table.
For the first one, run `base64 -i ~/roamio-upload.jks | pbcopy` and paste.

### 4. Let Google sign-in trust the key

Google sign-in in the prod app only works for APKs signed with a key Firebase
knows. Show the key's fingerprints:

```bash
/opt/homebrew/opt/openjdk@17/bin/keytool -list -v -keystore ~/roamio-upload.jks -alias upload
```

Add the `SHA1` and the `SHA256` lines to the prod Android app (free, no cost):

```bash
firebase apps:android:sha:create 1:852804538232:android:43ab98815b8f08b15dc28d <SHA1> -P prod
```

```bash
firebase apps:android:sha:create 1:852804538232:android:43ab98815b8f08b15dc28d <SHA256> -P prod
```

(Or Firebase console → roamio-prod-varun → Project settings → Roamio Android app → Add fingerprint.)

### Optional — build a signed APK on the Mac

Not needed for releases (GitHub does it). To build one locally, create
`app/android/key.properties` (git ignores it, never commit it):

```properties
storeFile=/Users/varunparikh/roamio-upload.jks
storePassword=the-password
```

Then `cd app && JAVA_HOME=/opt/homebrew/opt/openjdk@17 fvm flutter build apk --flavor prod --release`.
Without this file, release builds on the Mac are signed with the debug key, which is fine for testing.

---

## Part 2 — Every release

### 1. Pick the version

`MAJOR.MINOR.PATCH`, e.g. `0.1.0` → `0.1.1` for fixes, `0.2.0` for new features.

### 2. Bump it in both places

- `app/pubspec.yaml`: `version: 0.1.1+2` — the part before `+` is the
  version; the number after `+` must go **up by one every release** (phones
  refuse an "update" whose number is not higher).
- `app/lib/features/updates/update_checker.dart`: `const appVersion = '0.1.1';`

A test fails if the two disagree, and the release stops if the tag disagrees
with `pubspec.yaml`.

### 3. Write the release notes

Add a section to the top of [`CHANGELOG.md`](../CHANGELOG.md):

```markdown
## 0.1.1

- Fixed: totals in the split report now round correctly.
```

People see these notes in the update popup, so write them for travellers, not
developers. If there is no section for the version, GitHub writes notes from
the pull request titles instead.

Merge these changes into `main` (one pull request), and wait for CI to be green.

### 4. Tag and push

From an up-to-date `main`:

```bash
git checkout main && git pull
```

```bash
git tag v0.1.1 && git push origin v0.1.1
```

To try a release first without offering it to anyone, use a test tag such as
`v0.1.1-rc1`. It becomes a **pre-release**, which the update popup ignores.

### 5. Check the release

1. **github.com/VarunParikh/Roamio/actions** → "Release" → the run for your tag
   should be green (about 10–15 minutes). If it is red, open it: the failing
   step says what is wrong (for example a missing secret or a version mismatch).
2. **github.com/VarunParikh/Roamio/releases** → the new release has
   `Roamio-v0.1.1.apk` and your notes.
3. Download the APK on an Android phone and install it over the old version.
   It should update without asking you to uninstall first.
4. On a phone with the older version, open Roamio: the update popup appears
   (it checks at most once a day, so it may take until the next day).

### If a release went wrong

- Wrong notes: edit the release on GitHub; the popup shows the new text.
- Broken APK: fix it, bump the version (e.g. `0.1.2+3`) and release again.
  Don't reuse a tag; delete a broken release on GitHub only if nobody has
  installed it.
