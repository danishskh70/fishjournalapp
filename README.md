# Fish Journal v1.1.0 (build 2)

Replaces `lib/` and `pubspec.yaml` of the current app. No backend change.

## Install over the current app (PowerShell, run in the folder that CONTAINS fish_journal)

```powershell
Expand-Archive -Path .\fish_journal_v1.1.zip -DestinationPath . -Force
cd fish_journal
Remove-Item lib\screens\day.dart, lib\screens\journal.dart, lib\screens\more.dart, lib\screens\auth_home.dart -ErrorAction SilentlyContinue
flutter pub get
flutter run
```

Build the APK for the client:

```powershell
flutter build apk --release
```

File: `build\app\outputs\flutter-apk\app-release.apk`

Keep the same signing key for every release, and raise the number after `+` in `pubspec.yaml` each time. Back up the keystore in two places.

## Android setup (once)
- `android/app/src/main/AndroidManifest.xml` must have `<uses-permission android:name="android.permission.INTERNET"/>` (already there if the old app ran).
- Nothing else is needed. The update link opens in the browser.

## What changed
- Home: one hero button by state (Start, Confirm morning stock, Continue, View sheet). "Yesterday isn't closed" blocks a new day.
- Hotels owe / You owe suppliers cards. Pay Supplier and Hotel Paid buttons.
- Work screen: Purchase and Hotel sale. Pick party, tick fish, fill kg and rate on one screen, review, save.
- Saving runs in a background queue (kept on the phone, resent if the net drops, popup when done).
- End of Day on one screen. Blank is never zero.
- Day sheet with tables for any day (History, yesterday, today after closing). Open again to correct is in the menu.
- Accounts: dated history per hotel and supplier. Payment saved screen.
- Edit and delete purchases, sales, payments while the day is open.
- Update notice and What's new.

## Update notice setup (optional)
1. Put a public GitHub repo name in `lib/core/config.dart` (`githubRepo`).
2. For each release: create a GitHub Release, tag `v1.2.0`, attach the APK, write notes.
3. Add a line `min: 1.2.0` in the notes to force older apps to update.

## Not in this version
Hindi, dark theme, rate history, full offline mode, saved drafts of half-filled forms.
