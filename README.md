# Aura - modern music player (Flutter)

Local music player with glass UI, colors taken from each cover, animated track changes,
3D album carousel and a home-screen widget.

## Build the APK with GitHub Actions
1. Upload everything in this folder to a GitHub repo (keep `.github/workflows/build.yml`,
   `android_overlay/`, `lib/` and `pubspec.yaml`).
2. Push to `main` (or Actions > Build APK > Run workflow).
3. When it finishes, open the repo's **Releases** page and download `app-release.apk`.

The workflow generates the Android scaffold, copies `android_overlay/` on top
(manifest, background-playback service, widget) and builds the release APK.

## Widget
Install the APK, open Aura once, then long-press the home screen > Widgets > Aura.
