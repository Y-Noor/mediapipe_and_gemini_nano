# SignSpeak — Setup Guide

## Day 1: Get it running on your Pixel 8

### 1. Create the Flutter project

```bash
flutter create signspeak --org com.example --platforms android
cd signspeak
```

Then replace ALL the generated files with the ones provided:
- Replace `pubspec.yaml`
- Replace `lib/main.dart`
- Add all files under `lib/services/`, `lib/models/`, `lib/widgets/`, `lib/screens/`
- Replace `android/app/src/main/AndroidManifest.xml`
- Replace `android/app/build.gradle`

### 2. Download the MediaPipe gesture model

The gesture_recognizer.task file includes hand detection + a built-in
ASL classifier. Download it:

```bash
mkdir -p assets/models
curl -o assets/models/gesture_recognizer.task \
  https://storage.googleapis.com/mediapipe-models/gesture_recognizer/gesture_recognizer/float16/1/gesture_recognizer.task
```

Verify the file exists:
```bash
ls -lh assets/models/gesture_recognizer.task
# Should be ~20MB
```

### 3. Install dependencies

```bash
flutter pub get
```

### 4. Enable Gemini Nano on your Pixel 8

Your Pixel 8 supports Gemini Nano via AICore. Enable it:

1. Open **Settings → Developer Options** (enable developer options first if needed:
   Settings → About Phone → tap "Build number" 7 times)
2. Scroll to **"Gemini Nano"** or search for "AICore"
3. Toggle **"Enable Gemini Nano"** ON
4. Wait ~5 minutes for the model to download in the background

Verify it's ready:
```bash
adb shell cmd aicore status
# Should show: AICore is running, model: gemini_nano downloaded
```

### 5. Connect your Pixel 8

```bash
# Enable USB debugging on phone: Settings → Developer Options → USB Debugging
adb devices
# Should show your Pixel 8
```

### 6. Run the app

```bash
flutter run --release
# Use --release for better performance (GPU acceleration works better)
```

---

## If Gemini Nano AICore isn't available

The app automatically falls back to a rule-based sentence assembler.
You'll see "Fallback" instead of "On-device" in the header badge.

To use Gemini Flash as a network fallback instead (better quality):
1. Get a free API key from https://aistudio.google.com
2. In `lib/services/gemini_service.dart`, change the initialize() method:

```dart
// Replace the 'gemini-nano' model with:
_model = GenerativeModel(
  model: 'gemini-1.5-flash',
  apiKey: 'YOUR_API_KEY_HERE',
  systemInstruction: Content.system(_systemPrompt),
  generationConfig: GenerationConfig(maxOutputTokens: 50, temperature: 0.3),
);
```

---

## File structure

```
lib/
  main.dart                    ← App entry, init, nav shell
  models/
    app_state.dart             ← State, providers (Riverpod)
  services/
    gesture_service.dart       ← MediaPipe wrapper
    gemini_service.dart        ← Gemini Nano / fallback
    tts_service.dart           ← flutter_tts wrapper
  widgets/
    camera_view.dart           ← Camera + frame streaming
    hand_overlay_painter.dart  ← 21-point skeleton drawing
  screens/
    translate_screen.dart      ← Main UI
    history_screen.dart        ← Past sentences
assets/
  models/
    gesture_recognizer.task    ← MediaPipe model (~20MB)
```

---

## Signs supported (built-in MediaPipe model)

The built-in gesture_recognizer supports:
- Thumbs up / Thumbs down
- Open palm / Closed fist
- Pointing up / Victory (peace)
- ILoveYou (ASL)
- Ok sign
- None (no gesture)

For full ASL alphabet, you'll need to train a custom model (Day 2+).
The app architecture supports swapping in your own .task file.

---

## Troubleshooting

**Camera permission denied:**
```bash
adb shell pm grant com.example.signspeak android.permission.CAMERA
```

**MediaPipe model not found:**
Make sure `gesture_recognizer.task` is in `assets/models/` AND listed in `pubspec.yaml` under `flutter.assets`.

**Gemini Nano not available:**
The app will show "Fallback" and use rule-based assembly. This is expected on
devices that don't have AICore or where the model hasn't downloaded yet.

**Build fails with minSdk error:**
The `build.gradle` sets `minSdkVersion 26`. If you see issues, check that the
`android/local.properties` has `flutter.minSdkVersion=26`.
