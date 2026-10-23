# Split Sheet

Sign, timestamp and verify who owns what share of a song, before anyone leaves the studio.
Built in Flutter for Android, iOS and the web, on Firebase's free Spark plan, for the BLI Legal Tech Hackathon 2.

- **Web:** landing page at `/`, the app at `/#/app`, and a public verify page at `/#/verify/<sheetId>`.
- **Mobile:** opens straight into the app.

## What works

| Area | What you can do |
| --- | --- |
| Accounts (Firebase Auth) | Sign up with email and password, email confirmation link, sign in, forgot password, change password by email, sign out, delete account (asks for your password again when Firebase needs it). |
| Profile | Legal name, stage name, collecting society ID and a 4-digit signing PIN. A signing key is created for you; no seed phrase. |
| Create a sheet | Song details, 2 to 10 contributors with roles, separate composition and master splits (each must total exactly 100%), audio fingerprinted on the device (SHA-256), review, sign with your PIN. |
| Collect signatures, across phones | Collaborators scan the QR code or type the invite code on their own phone, pick their name, review their share and sign. The creator's tracker updates live, with a message when someone signs. "Pass the phone" still works for people without the app. |
| Change requests | Request a change with a reason, note and suggested share, or decline. The creator is told live and can issue an updated version; the old version is cancelled and kept in the history. |
| Sheet page | Status, both splits, recording fingerprint, proof (sheet ID, document hash, ledger record), full history, amendments, cancel, signed PDF with a verify QR code. |
| Verify (public, no account) | Status, shares, signature times and proof from the public ledger. Pick an audio file to check it is the recording that was signed. Names show only to people on the sheet. |
| Payouts (testnet demo) | Pay royalties into a fully signed sheet; the amount splits by the signed shares and every member sees their balance. |
| Demo data | Home or Profile → **Load demo sheets** adds a locked-in sheet with a payout, a sheet collecting signatures, and one waiting on your signature. |

## Firebase setup (free Spark plan, about 10 minutes)

1. **Create a project** at [console.firebase.google.com](https://console.firebase.google.com). Stay on the Spark plan; no card is needed.
2. **Turn on email sign-in:** Build → Authentication → Get started → Sign-in method → Email/Password → Enable.
3. **Create the database:** Build → Firestore Database → Create database → Production mode → pick a region close to your users.
4. **Install the tools** (once):
   ```bash
   npm install -g firebase-tools
   dart pub global activate flutterfire_cli
   firebase login
   ```
5. **Connect the app:**
   ```bash
   cd split_sheet
   flutter create --platforms=android,ios,web .   # platform folders; keeps lib/, web/index.html and tests
   flutterfire configure                           # pick your project; writes lib/firebase_options.dart
   firebase use --add                              # pick the same project
   firebase deploy --only firestore                # deploys firestore.rules and indexes
   ```
6. **Platform minimums** for the current Firebase packages:
   - Android: in `android/app/build.gradle(.kts)` set `minSdk = 24`.
   - iOS: in `ios/Podfile` set `platform :ios, '15.0'`, and add the camera permission to `ios/Runner/Info.plist`:
     ```xml
     <key>NSCameraUsageDescription</key>
     <string>Scan a Split Sheet invite QR code</string>
     ```
7. **Run it:**
   ```bash
   flutter pub get
   flutter run -d chrome     # web
   flutter run               # phone or emulator
   flutter test
   ```

Until step 5 is done the app opens a "Connect Firebase to start" screen instead of crashing.

**Host the web app on Firebase Hosting (free):**

```bash
flutter build web --release
firebase deploy --only hosting
```

Your site is at `https://<project-id>.web.app`. Put that address in `AppConfig.publicBaseUrl` (`lib/config.dart`), so QR codes and PDFs made on the phone point to your verify page. Optional: change the sender name and wording of the emails under Authentication → Templates.

**APK for judges:** `flutter build apk --release` → `build/app/outputs/flutter-apk/app-release.apk`.

## Two-phone demo

1. Phone A: create an account, create a sheet with yourself and two collaborators, and sign.
2. Phone B: create a second account, tap **Join**, scan Phone A's QR code, pick a name, check the share, sign with a PIN.
3. Phone A shows "… signed Lagos Summer" and the tracker ticks over. Hand Phone A to the third person to sign, and the sheet locks in on both phones.
4. Open the verify link from the PDF in any browser, even signed out.

## Data and security

| Collection | What it holds | Who can read | Who can write |
| --- | --- | --- | --- |
| `users/{uid}` | Name, stage name, society ID, signing address | Owner | Owner |
| `users/{uid}/private/keys` | Signing secret, PIN hash | Owner | Owner |
| `invites/{code}` | Invite code → sheet ID | Anyone signed in, one code at a time (no listing) | Creator |
| `sheets/{id}` | Signed terms, signatures, claims, change requests | Members; anyone signed in with the ID while the sheet is open | Members. Non-members can only add themselves to an open sheet |
| `ledger/{id}` | Hashes, shares, signature times, events | Everyone (powers the public verify page) | Signed-in users; append-only, hashes and shares locked |
| `payouts/{id}` | Royalty payments and per-person shares | Members of the sheet | Members, and only into executed sheets |

What `firestore.rules` enforces on the free plan (no Cloud Functions):

- The signed terms, document hash, creator and invite code of a sheet can never change after creation.
- Signatures can only be added, never removed, and status can only take known values.
- Someone joining can touch only the membership, claim and wallet fields, and only add themselves.
- The ledger's hashes and shares are frozen; it only grows. Nothing can be deleted.

**Signed terms.** Every party signs the same document hash: SHA-256 over canonical JSON (keys sorted) of the song, the audio fingerprint, and each person's name, roles and shares. Firestore stores exactly those terms in `sheets/{id}.terms`, so the verify page can recompute the hash. Change any share or the recording and it no longer matches.

## Free-plan choices

| Paid feature we avoided | What the app does instead |
| --- | --- |
| Phone (SMS) sign-in | Email and password, with an email confirmation link |
| Cloud Functions | Security rules guard every write; the ledger is written in Firestore transactions with the same checks as the contract |
| Cloud Storage | Audio never leaves the phone. Only its fingerprint is stored |
| Push notifications (needs Functions to send) | Live Firestore listeners update every open screen and show a message when someone signs |

Spark's daily free quota (50,000 reads and 20,000 writes) is far more than a hackathon demo needs.

## How it fits together

```
lib/
  main.dart, app.dart, router.dart   Firebase start-up, theme, routes and auth redirects
  firebase_options.dart               placeholder until `flutterfire configure` replaces it
  theme.dart, config.dart             design tokens; public URL for QR codes and PDFs
  models/models.dart                  sheet, contributor, signature, payout, profile + Firestore layout
  state/app_state.dart                auth, live listeners, create, join, sign, amend, cancel, deposit, demo data
  services/
    firestore_chain.dart              ledger in Firestore (transactions), the testnet stand-in
    chain_service.dart                ChainService interface, shared rules, local MockChainService
    hashing.dart, signer.dart         canonical JSON + hashes, invite codes; MockSigner
    pdf_service.dart                  signed PDF with verify QR
  screens/                            landing, verify, sign-up, sign-in, setup, home, create wizard, invite,
                                      sign, request change, sheet detail, payouts, deposit, profile, join, scan
  widgets/                            shared UI
contracts/SplitRegistry.sol           the on-chain registry the ledger imitates
firestore.rules, firebase.json        security rules, hosting config
test/                                 hashing, Firestore round trip, splits, payout rounding, formatting
```

## Going beyond the free plan later

| Now | Upgrade |
| --- | --- |
| `FirestoreChainService` | An EVM `ChainService` calling `contracts/SplitRegistry.sol` through a relayer (Cloud Functions, Blaze plan) |
| `MockSigner` with a secret in an owner-only document | An embedded wallet SDK signing EIP-712 `SignSheet(bytes32 sheetId, bytes32 docHash)` |
| Live in-app messages | Push notifications through Cloud Messaging triggered by a Function |

## Checks so far

- `dart analyze` (with `flutter_lints`) reports no issues across `lib/`, against Flutter 3.47.7 and the package sources (firebase_core 5.0, firebase_auth 7.0, cloud_firestore 7.0, go_router 14.8 and the rest).
- Core logic checks pass on the Dart VM, including that a sheet survives the Firestore layout with the same hash.
- `contracts/SplitRegistry.sol` compiles with solc 0.8.24.
- **Not yet run against a live Firebase project, on a device or in a browser, and the security rules have not been run in the emulator.** Do one full two-phone run before the demo, and check the rules with `firebase emulators:start --only firestore` if you change them.

A split sheet records what the parties agreed. It is not legal advice and does not replace a publishing, label or distribution contract.
