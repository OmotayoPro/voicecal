# Voice Calculator (iOS) — Implementation Spec

> Hand this file to Claude Code at the root of the Xcode project. Read it fully before writing code. Follow the build order in section 12 and open one small PR per step.

## 1. Product summary

A calculator where **voice and manual input are one hybrid system, not two modes**. The user can dictate part of an equation, tap keys to type or correct something in the middle, and keep dictating, all in the same equation, without ever switching modes or restarting the mic.

Core promise: **editing never interrupts dictation, and dictation never overwrites manual edits.**

## 2. Goals and non-goals

**Goals**
- Hybrid input: speech and keypad both write to one equation at one cursor.
- Tap any token to correct it while the mic is still listening.
- Tap-to-toggle mic (not hold-to-speak).
- Inactivity timer that stops listening automatically if the user forgets to turn it off.
- Spoken result with a user-selectable voice, rate and pitch.
- Deterministic, testable parsing. No LLM or network calls in the core loop.

**Non-goals (v1)**
- Open-ended natural language math ("15% tip on $60 split 3 ways").
- Scientific functions, history, unit conversion.
- iPad/macOS layouts, widgets, Apple Watch.
- Languages other than English (structure the parser so locales can be added later).

## 3. Tech stack

- Swift 5.9+, SwiftUI, **iOS 17+** (use `@Observable`)
- Speech to text: `Speech` framework (`SFSpeechRecognizer`), on-device where supported
- Audio: `AVFoundation` (`AVAudioEngine`, `AVAudioSession`)
- Text to speech: `AVSpeechSynthesizer`
- Persistence: `@AppStorage` / `UserDefaults` for settings only
- Testing: Swift Testing or XCTest
- Zero third-party dependencies for v1

## 4. Design reference

The design is already finished. Before building any view:
- Design source: https://www.figma.com/design/FAmhBZB0DXHMz7pMDZh2VV/Pro-Playground?node-id=733-56 (section `ios-calculator-ui`)
- Match the design exactly. Extract colors, spacing, radii and type styles into `DesignTokens.swift` first. Never hardcode these values inside views.
- The design shows two states: `default-state` (mic off) and `mic-active` (glowing mic key and glowing cursor).
- Not in the design, built in the same visual language and iterated later: token chips and their editing state, the voice settings sheet, the permission-denied message, the inactivity countdown ring.
- Design corrections: the keypad's second row is `7 8 9` (the frame's `7 8 0` is a typo). The top-left history icon is dropped; that slot holds the settings button instead.
- There is no live caption. Pending tokens in the equation row are the only dictation feedback.

## 5. Architecture

MVVM, protocol-based services so everything is testable without a microphone.

```
VoiceCalculator/
├── App/
│   └── VoiceCalculatorApp.swift
├── Models/
│   ├── Token.swift
│   ├── Equation.swift            // token array + cursor + editing state
│   └── VoiceSettings.swift
├── Parsing/
│   ├── SpokenNumberParser.swift  // "twenty five point five" -> 25.5
│   ├── SpokenPhraseParser.swift  // transcript -> [ParsedItem]
│   └── ParsedItem.swift
├── Evaluation/
│   └── ExpressionEvaluator.swift // [Token] -> Decimal or error
├── Speech/
│   ├── SpeechRecognizing.swift   // protocol
│   ├── SpeechRecognizerService.swift
│   ├── DictationSession.swift    // anchor + commit logic (section 7)
│   ├── InactivityTimer.swift
│   └── ResultSpeaker.swift       // AVSpeechSynthesizer wrapper
├── ViewModels/
│   └── CalculatorViewModel.swift
├── Views/
│   ├── CalculatorView.swift
│   ├── EquationRowView.swift
│   ├── TokenChipView.swift
│   ├── MicButton.swift
│   ├── KeypadView.swift
│   └── VoiceSettingsView.swift
├── DesignSystem/
│   └── DesignTokens.swift
└── Tests/
```

## 6. Data model

```swift
enum Token: Identifiable, Equatable {
    case number(id: UUID, text: String)   // String while editing so "12." and "0.0" are valid states
    case op(id: UUID, Operator)
    var id: UUID { ... }
}

enum Operator: String { case add = "+", subtract = "−", multiply = "×", divide = "÷", percent = "%" }

@Observable final class Equation {
    var tokens: [Token] = []
    var cursorIndex: Int = 0          // insertion point; tokens are inserted BEFORE this index
    var editingTokenID: UUID? = nil   // token currently being corrected
}
```

Rules:
- **Never store the equation as a single string.** Every number and operator is its own token with a stable `id` (needed for tap-to-edit, animation and diffing).
- Both keypad and voice call the same `Equation` mutation methods: `insert(_:)`, `replace(id:with:)`, `delete(id:)`, `backspace()`, `clear()`.
- Adjacent number tokens are merged by the keypad path (typing 1 then 2 gives `12`). The voice path inserts whole numbers.
- Expose a derived `liveResult: Decimal?` computed from tokens. Ignore a trailing operator when computing it.

## 7. Hybrid input behavior (the core of the app)

This section is the most important part of the spec. Implement and test it carefully.

### 7.1 Streaming transcripts vs committed tokens

`SFSpeechRecognizer` streams **partial results that get revised** ("to" may become "two" then "twelve"). Never append tokens directly from partials. Use a `DictationSession`:

- `anchorIndex`: the position in `equation.tokens` where this dictation segment begins.
- `consumedTranscriptLength`: how much of the recognizer's cumulative transcript has already been committed. Implemented as a word count (`consumedCount`), since the recognizer reformats earlier text and shifts character offsets; see `ARCHITECTURE.md`.
- `pendingTokens`: tokens produced from the *uncommitted* tail of the transcript. They are displayed live in the equation row in the `text/pending` color (committed tokens use `text/primary`), and **replaced wholesale on every new partial result**.

On each partial result:
1. Take `transcript.dropFirst(consumedTranscriptLength)`.
2. Parse it with `SpokenPhraseParser` into `[Token]`.
3. Replace the previous `pendingTokens` (starting at `anchorIndex`) with the new ones.

**Commit** (pending tokens become permanent, `consumedTranscriptLength` advances to the full transcript length, `anchorIndex` moves to the cursor) when any of these happen:
- The recognizer marks the result final.
- A short pause (~0.8s) with no transcript change.
- **The user performs any manual action**: key tap, token tap, backspace, cursor move.

### 7.2 Manual edit during dictation (must not stop the mic)

When the user taps a key or a token while listening:
1. Immediately commit the current pending tokens (7.1).
2. Apply the manual edit to the equation.
3. Set `consumedTranscriptLength` to the current full transcript length so already-heard words are never re-parsed or re-inserted.
4. Move `anchorIndex` to the new cursor position.
5. Leave the recognizer running. Do not restart audio, do not toggle UI state, do not disable the keypad.

Net effect: dictation continues from the new cursor position and nothing the user typed gets clobbered.

### 7.3 Tap a token to correct it

- Tapping a token sets `editingTokenID` and shows it in the editing state from the design. The state is neutral "focused", not an error.
- The next keypad input replaces that token's value (numbers) or swaps it (operators). The next *spoken* number also replaces it. After one replacement, `editingTokenID` clears and the cursor moves to just after that token.
- Tapping elsewhere or the same token again cancels editing.
- Long-press a token to delete it (optional polish, behind a flag).

### 7.4 Cursor

- Cursor defaults to the end of the equation.
- Tapping the space between tokens, or the leading and trailing edges, moves the cursor there. Voice and keypad both insert at the cursor.
- Render the cursor as the blinking marker from the design.

## 8. Spoken phrase parsing

Pure functions, no side effects, heavy unit tests.

**Input:** a transcript tail string, for example `"twelve plus fifteen times three point five"`.
**Output:** `[ParsedItem]` where `ParsedItem` is `.number(Decimal/String)`, `.op(Operator)`, or `.command(Command)`.

Must handle:
- Digits already emitted by the recognizer: `"12 plus 15"`, `"3.5"`
- Number words 0–999,999,999: `"twelve"`, `"twenty five"`, `"one hundred and five"`, `"two thousand three hundred"`
- Decimals: `"three point five"`, `"point five"` (gives `0.5`), `"zero point zero five"`
- Negative: `"minus five"` at the start or after an operator is a negative number; otherwise it's subtraction
- Operators: `plus`, `add`, `minus`, `subtract`, `times`, `multiplied by`, `x`, `divided by`, `over`, `percent`
- Commands: `clear` / `clear all`, `delete` / `scratch that` / `undo` (removes last token), `equals` / `calculate` / `what's the answer` (evaluates, then speaks the result)
- Common mishears: `"to"`/`"too"` → 2 and `"for"` → 4 **only when adjacent to a numeric or operator context**; `"x"`/`"ex"` → ×. Keep this table in one file, easy to extend.
- Words heard instead of a digit always count as that digit, with no context needed: `oh`/`o` → 0, `tree`/`tri`/`free` → 3, `sis`/`sex`/`sicks` → 6, `ate`/`hate`/`ait` → 8, plus `wan`, `tu`, `fife`, `nein`. `dot` means the same as `point`.
- Operators also accept `divide`/`divided` and `multiply`/`multiplied`/`multiples`/`multiple` without "by".
- `delete` removes the last entry (a whole number or operator), once per mention.
- Figures can be read out digit by digit: "one five zero zero" is 1500, however the recognizer writes it ("1 5 0 0", "15 0 0"). `double` and `triple` repeat the next digit. A plain run of digits spoken straight after a number, with no operator between, carries that number on, so pausing between digits still builds one figure.
- Unknown words are ignored (never crash, never insert garbage).

Number-word parsing is its own unit (`SpokenNumberParser`) so it can be tested in isolation.

## 9. Evaluation

- Write a small recursive-descent or shunting-yard evaluator over `[Token]`. **Do not use `NSExpression`** (it throws Objective-C exceptions on malformed input).
- Use `Decimal`, not `Double`, to avoid `0.1 + 0.2` artifacts.
- Results are rounded to at most 3 decimal places, both on screen and when spoken. Trailing zeros are dropped (`3`, not `3.000`).
- Standard precedence: `× ÷` before `+ −`. `%` applies to the preceding number (`50 %` = 0.5).
- Return `Result<Decimal, EvaluationError>` with cases: `.divideByZero`, `.malformed`, `.overflow`.
- Live result updates after every equation change. Show `—` or hide when the expression is incomplete. Never flash an error mid-entry.

## 10. Listening lifecycle and inactivity timer

### 10.1 Mic control
- **Tap-to-toggle.** Idle (outline icon) and listening (filled icon, pulsing ring) per the design. Never hold-to-speak.
- First tap requests permissions in order: microphone, then speech recognition. Handle denied/restricted with an inline message and a button that opens Settings. Never crash. Voice input is unavailable without permission; manual keypad input always works.
- Haptic on start and stop (`UIImpactFeedbackGenerator(.light)`).

### 10.2 Inactivity auto-stop
Problem: the user forgets to turn the mic off. Solution: an `InactivityTimer` owned by the view model.

- **Timeout default: 10 seconds**, user-configurable in settings (5 / 10 / 15 / 30 s / Off).
- The timer **resets on any activity**: new recognized words (transcript changed), any keypad tap, any token tap, a cursor move.
- It does **not** reset on silence or background noise alone.
- In the **last 3 seconds**, show a subtle countdown state on the mic (ring drains). Any activity cancels it.
- On expiry: commit pending tokens, stop recognition, tear down the audio engine, and return the mic to idle. No alert, no modal.
- Hard cap: also stop after **3 minutes** of continuous listening regardless of activity (safety net).
- Inject a clock (`protocol Clock`/`ContinuousClock`) so timer logic is unit-testable without waiting.

### 10.3 Other automatic stops
Stop listening cleanly when: the app enters background, an audio interruption begins (call, Siri), the audio route changes in a way that breaks input, or the view disappears.

### 10.4 Recognition task limits
`SFSpeechRecognizer` tasks are time-limited (about 1 minute). Handle the final/ended callback by **silently starting a new task** if the user still has listening on, then reset `consumedTranscriptLength = 0` for the new transcript. The user should never notice the seam.

Recognition uses the English variant chosen in settings (Automatic follows the device's languages, falling back to US English). Prefer on-device recognition when available (`supportsOnDeviceRecognition` → `requiresOnDeviceRecognition = true`). Set `shouldReportPartialResults = true`. A settings switch, off by default, lets Apple's servers do the recognition instead, which is usually more accurate but sends audio off the device. Consider `contextualStrings` with number words and operator words to improve accuracy.

## 11. Speaking the result

- `ResultSpeaker` wraps `AVSpeechSynthesizer`.
- Triggers: spoken command ("equals"), equals key tap, and an optional "auto-announce" setting.
- Equals (spoken or tapped) evaluates the equation, collapses it to the result as a single token so the user can keep calculating from it, and speaks the result.
- Convert the `Decimal` result to a natural spoken string ("forty-five point five") using `NumberFormatter` with `.spellOut`, and handle negatives, large numbers and long decimals (round spoken precision to a sensible limit, display is unaffected).
- **Avoid a feedback loop:** pause recognition while speaking, then resume if the mic was on. Resuming counts as activity for the inactivity timer.
- Audio session: use `.playAndRecord` with `.defaultToSpeaker` and `.duckOthers` while active; restore on stop.

### Voice settings (`VoiceSettingsView`, opened from the settings icon)
- Voice picker: list `AVSpeechSynthesisVoice.speechVoices()` filtered to the device language, grouped by quality; store `identifier`.
- Rate slider (maps to `utterance.rate`, clamp to a pleasant range)
- Pitch slider (0.5–2.0)
- "Preview voice" button that speaks a sample result
- Auto-announce toggle
- Inactivity timeout picker (section 10.2)
- Persist everything with `@AppStorage`; fall back to the default voice if a stored identifier is no longer installed.

## 12. Build order (one PR per step)

1. **Project scaffold + `DesignTokens`** from the design, empty `CalculatorView` matching layout.
2. **Token model + `Equation`** with insert/replace/delete/cursor, plus unit tests.
3. **Keypad input wired to tokens**; token chips render; tap-to-edit works. Fully usable manual calculator.
4. **`ExpressionEvaluator`** + live result + error handling, plus tests.
5. **`SpokenNumberParser` + `SpokenPhraseParser`** with a large table-driven test suite. No audio yet.
6. **`SpeechRecognizerService` + permissions + `MicButton`**, logging the raw transcript only.
7. **`DictationSession`**: pending/commit logic, tokens from voice, and mid-dictation manual edits (section 7). Test with a fake recognizer feeding scripted partials.
8. **`InactivityTimer`** + countdown UI + lifecycle stops (section 10).
9. **`ResultSpeaker`** + feedback-loop handling.
10. **`VoiceSettingsView`** + persistence.
11. **Accessibility, haptics, polish, edge cases**, final QA pass.

## 13. Accessibility

- VoiceOver labels on every key, token ("Token 3 of 5, number 15, double tap to edit"), mic ("Start listening" / "Stop listening, listening for 6 seconds")
- Dynamic Type support on the equation row (chips wrap or scroll horizontally, never truncate numerals)
- Respect Reduce Motion: replace pulsing ring with a static state change
- Minimum 44×44 pt touch targets for all keys and tokens
- Do not rely on color alone for pending vs committed vs editing token states

## 14. Edge cases to test explicitly

- Dictate, tap a key mid-sentence, keep dictating: the typed token survives, later words append after it.
- Partial result revises earlier words ("to" → "two" → "twelve") without duplicating tokens.
- Tap a token to edit, then speak a number: replaces that token.
- Speak while the cursor is in the middle of the equation: inserts at the cursor.
- Mic permission denied or revoked mid-session.
- Recognizer unavailable (offline and no on-device model).
- Inactivity timeout fires while the user is mid-edit on a token (commit, don't lose the edit).
- Phone call interrupts, app backgrounded, headphones unplugged.
- Very long equations, very large and very small decimals, divide by zero, trailing operator.
- Recognition task rollover at the ~1 minute limit with mic still on.

## 15. Quality bar (so PRs merge without hand-holding)

- Each PR is small, single-purpose, and maps to one step in section 12.
- All new logic in Parsing, Evaluation, Equation and DictationSession has unit tests. Table-driven where possible.
- No force unwraps, no `try!`, no `fatalError` outside truly unreachable code.
- No business logic in views. Views render state and forward intents to the view model.
- Services sit behind protocols; inject fakes in tests and previews.
- SwiftLint (default config) and SwiftFormat run clean; zero new warnings.
- Every PR description includes: what changed, how it was tested, and simulator or device screenshots for UI changes. Use real-device notes for anything involving the mic, since the simulator's audio input is unreliable.
- Conventional commit messages (`feat:`, `fix:`, `test:`, `refactor:`).
- Add a short `ARCHITECTURE.md` after step 7 explaining the dictation commit model.

## 16. Info.plist requirements

- `NSMicrophoneUsageDescription`: "Used so you can dictate calculations by voice."
- `NSSpeechRecognitionUsageDescription`: "Used to turn your spoken numbers and operators into an equation."

## 17. Decisions (confirmed with the product owner)

- Inactivity default is 10s, with the 3-minute hard cap.
- "Equals" (spoken or tapped) solves the equation and speaks the result.
- Pending tokens use `text/pending`; committed tokens use `text/primary`.
- No live caption and no history button in v1.
- The product owner handles all git branching, pushing and PRs; code is written locally, one build step at a time.
