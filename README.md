# voicecal
An iOS Calculator that supports voice input. Pretty basic, nothing superficial.

Voice and keypad write to the same equation at the same cursor: dictate part of it, tap keys to fix something in the middle, and keep dictating, without switching modes or restarting the mic.

## Using it

- Tap the mic to start listening and tap it again to stop. It also turns itself off after 10 seconds without activity (configurable) and always after 3 minutes.
- Say things like "twelve plus fifteen times three point five", "minus five", "fifty percent".
- Spoken commands: "equals", "clear", "scratch that".
- Tap a number or operator to replace it by typing or speaking. Tap between two of them to move the cursor. Long-press one to delete it.
- Equals solves the equation and reads the answer aloud. The gear button has the voice, speed, pitch and timeout settings.

## Setup

The Xcode project is generated from `project.yml` and is not checked in. After cloning, or whenever `project.yml` changes:

```bash
brew install xcodegen
xcodegen generate
open Voicecal.xcodeproj
```

The mic orb uses a Metal shader. If the build says the Metal Toolchain is missing, run `xcodebuild -downloadComponent MetalToolchain` once.

Requires Xcode 16 or later. The app targets iOS 17+. Use a real device for anything involving the microphone; the simulator's audio input is unreliable.

## Checks

```bash
swiftformat Voicecal VoicecalTests VoicecalUITests --lint
swiftlint lint Voicecal VoicecalTests VoicecalUITests
xcodebuild test -project Voicecal.xcodeproj -scheme Voicecal -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

UI tests run without a microphone by launching the app with a scripted recognizer. `testRealMicSmoke` exercises the real one and is skipped unless `TEST_RUNNER_REAL_MIC=1` is set.

## Docs

- `VOICE_CALCULATOR_SPEC.md`: the behaviour spec and build plan.
- `ARCHITECTURE.md`: how dictation is committed and why manual edits never interrupt it.
- `docs/screenshots`: one or more screenshots per build step.
