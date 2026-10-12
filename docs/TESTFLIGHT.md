# Getting Voicecal onto TestFlight

Everything that can be done without an Apple Developer account is done. This is what is left.

## Already in place

- App icon (1024×1024, no transparency). Source: `design/app-icon.svg`.
- Privacy manifest (`Voicecal/PrivacyInfo.xcprivacy`): no tracking, no data collected, `UserDefaults` declared for storing the user's own settings.
- Export compliance: `ITSAppUsesNonExemptEncryption` is `NO`, so App Store Connect does not ask per build.
- Microphone and speech recognition usage descriptions.
- Version 1.0, build 1. Bundle id `com.omotayotaiwo.voicecal`. iPhone only, portrait, iOS 17+.
- An unsigned release archive for device builds successfully, and contains none of the UI-test hooks.

## What you need to do

1. **Join the Apple Developer Program** ($99 a year) at developer.apple.com/programs.
2. **Install the release Xcode** from the Mac App Store. Only the Xcode 27 beta is on this Mac, and App Store Connect rejects builds made with a beta. Then select it:

   ```bash
   sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
   ```

3. **Sign in to Xcode** with the developer account: Xcode > Settings > Accounts.
4. **Create the app record** at appstoreconnect.apple.com: My Apps > + > New App. Platform iOS, bundle id `com.omotayotaiwo.voicecal` (register it under Certificates, Identifiers & Profiles first if it is not offered), any SKU.
5. **Upload a build.** Either run the script with your Team ID (shown in the developer account's Membership page):

   ```bash
   scripts/testflight.sh YOUR_TEAM_ID
   ```

   or do it by hand in Xcode: pick the Voicecal target > Signing & Capabilities > choose your team, then Product > Archive > Distribute App > TestFlight.
6. **Add testers** in App Store Connect > TestFlight once the build finishes processing.
   - Internal testers (up to 100 people on your team): available straight away.
   - External testers (up to 10,000, by email or public link): needs a short Beta App Review, a description of what to test, and a privacy policy URL.

## For each later build

Raise `CURRENT_PROJECT_VERSION` in `project.yml` (1, 2, 3…), then upload again. `MARKETING_VERSION` only changes for a new release (1.0, 1.1…).

## Worth knowing before testers try it

- Tested on iOS 26 and iOS 27 simulators only. The app allows iOS 17 and later, but iOS 17 to 25 have never been run: this Xcode beta offers no older simulators.
- If "Use Apple's servers" is on in voice settings, speech audio is sent to Apple for recognition. The system permission prompt says so. A privacy policy for external testers should mention it.
- The privacy manifest says no data is collected. That holds as long as the app has no analytics or accounts.
