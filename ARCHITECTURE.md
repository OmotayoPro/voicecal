# Architecture

Voicecal is a calculator where typing and speaking write to the same equation at the same cursor. This note explains the part that is not obvious from reading any single file: how dictation is committed.

## The pieces

| Layer | Type | Role |
|---|---|---|
| Model | `Equation` | The only source of truth: tokens, cursor, the token being edited, and which tokens are still pending. |
| Parsing | `TranscriptLexer`, `SpokenNumberParser`, `SpokenPhraseParser` | Pure functions from a transcript to numbers, operators and commands. |
| Evaluation | `ExpressionEvaluator` | Tokens to a `Decimal` or an error. |
| Speech | `SpeechRecognizing` (protocol), `SpeechRecognizerService` | Microphone and `SFSpeechRecognizer`, emitting transcripts. |
| Speech | `DictationSession` | Turns the transcript stream into pending and committed tokens. |
| View model | `CalculatorViewModel` | Routes keys, taps and speech events; owns the pause timer. |
| Views | `CalculatorView` and children | Render state and forward intents. No logic. |

## The dictation commit model

The recognizer streams a cumulative transcript for the current task and keeps revising it: "to" becomes "two" becomes "twelve". Appending tokens from each partial would duplicate and corrupt the equation, so nothing is appended from a partial.

`DictationSession` keeps two things:

- `heard`: the latest transcript, split into words and symbols.
- `consumedCount`: how many of those words are already committed.

**On every partial result** it re-parses only the words after `consumedCount` and hands the resulting tokens to `Equation.setPending`, which removes the previous pending tokens and inserts the new ones at the same place. Pending tokens always sit immediately before the cursor, so no separate anchor index is stored: the anchor is the cursor minus the pending count. Pending tokens are drawn in the `text/pending` color.

**A commit** makes the pending tokens permanent and advances `consumedCount` to the end of `heard`. It happens when:

1. the recognizer marks a result final,
2. speech pauses for about 0.8 seconds (the view model's timer), or
3. the user does anything by hand: a key, a token tap, a cursor move.

Case 3 is what makes input hybrid. `CalculatorViewModel.prepareForManualEdit` commits before applying any manual edit and never touches the recognizer. The words heard so far are consumed, so a later revision cannot overwrite what the user typed, and because pending tokens are inserted at the cursor, dictation simply continues from wherever the edit left it.

### Details worth knowing

- **Words, not characters.** The spec describes a consumed character length. `consumedCount` counts words instead, because the recognizer reformats text it has already produced ("twelve plus" can become "12+"), which shifts character offsets but not word counts.
- **Commands wait for a commit.** "clear", "delete" and "equals" are not run from a partial, since the recognizer may still revise them. At commit time the uncommitted items are replayed in spoken order, so "two plus two equals times three" works.
- **Minus.** "minus five" is a negative number at the start of an equation or after an operator, and subtraction after a value. The session tells the parser which case applies from the tokens ahead of the pending ones.
- **Tap a token, then speak.** The first spoken number replaces the token being edited, through the same `Equation.insert` rule the keypad uses.
- **Digit by digit.** A plain run of digits arriving straight after a number extends that number instead of being inserted beside it, so "one", pause, "five", pause, "zero" is 150. While the digits are still pending, `Equation` remembers the number as it was, so a revised transcript can take them back.
- **Task rollover.** Recognition tasks end after about a minute or on silence. The service starts a new one and emits `segmentRestarted`; the session commits and resets `heard` and `consumedCount`, because the new task's transcript starts from empty.
- **After equals.** `Equation.isShowingResult` makes the next number (typed or spoken) start a new equation, while an operator continues from the result.

## Testing without a microphone

Everything above the service is tested through `FakeSpeechRecognizer`, which feeds scripted partials (`DictationTests`). UI tests launch the app with `UITEST_SPEECH_SCRIPT`, which swaps in `ScriptedSpeechRecognizer` (DEBUG builds only). The real recognizer needs a device; `testRealMicSmoke` is an opt-in check for that.
