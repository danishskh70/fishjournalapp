# Fish Journal (Flutter, Android)
1. Install Flutter 3.22+.  2. In this folder run: `flutter create . --platforms=android --org com.fishjournal`
3. `flutter pub get`  4. Android: set `minSdkVersion 23` (android/app/build.gradle) and make sure
   `<uses-permission android:name="android.permission.INTERNET"/>` is in AndroidManifest.xml (flutter create adds it for debug only).
5. `flutter run` / `flutter build apk --release`
Backend: https://fish-journal.onrender.com (change in lib/core/api.dart). Free Render hosting may take ~30s to wake.
NOTE: JSON field names for responses were not verifiable offline; helpers `pick()` accept several likely names.
Check /docs and adjust the key lists if any value shows blank.
