# voicecal
An iOS Calculator that supports voice input. Pretty basic, nothing superficial.

## Setup

The Xcode project is generated from `project.yml` and is not checked in. After cloning, or whenever `project.yml` changes:

```bash
brew install xcodegen
xcodegen generate
open Voicecal.xcodeproj
```

Requires Xcode 16 or later. The app targets iOS 17+.

## Checks

```bash
swiftformat Voicecal VoicecalTests --lint
swiftlint lint Voicecal VoicecalTests
```

The build plan and behaviour spec live in `VOICE_CALCULATOR_SPEC.md`.
