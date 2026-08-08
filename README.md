# CopyCue

CopyCue is a minimal native macOS utility that confirms successful clipboard changes with a small rounded capsule beneath the pointer and a temporary white circled check in the menu bar. It keeps only the current and immediately previous text values, so an accidentally overwritten copy can be restored from the menu bar.

## MVP behavior

- Watches the macOS pasteboard rather than global keyboard events.
- Shows a brief Apple-blue capsule beneath the pointer for any clipboard change.
- Holds a white circled checkmark in the menu bar for two seconds.
- Provides Short, Medium, and Long cursor-feedback timing in Settings.
- Keeps the last two distinct text values in memory only.
- Restores the previous text from the menu-bar menu.
- Shows the blue cursor indicator when an older value is restored.
- Does not appear in the Dock or application switcher.
- Clears its two-item history when it quits.

CopyCue reads clipboard text only after macOS reports that the pasteboard changed. Non-text copies still receive visual confirmation but are not added to text history.

## Install from npm

The npm release installs CopyCue into `~/Applications` and opens it with one command:

```bash
npx --yes @morning-corp/copycue@latest install
```

The current MVP package supports Apple Silicon Macs. It is ad-hoc signed, so macOS may require manual approval the first time it opens. See [PUBLISHING.md](PUBLISHING.md) for the maintainer release process and npm organization setup.

## Build and run

Requirements: macOS 13 or later and a Swift toolchain from Xcode or the Command Line Tools.

```bash
./scripts/build-app.sh
open dist/CopyCue.app
```

The generated app is ad-hoc signed for local development. A polished public release should use a Developer ID certificate and notarization.

## Test

```bash
npm test
```

## Use

1. Start CopyCue and look for the overlapping-pages icon in the macOS menu bar.
2. Copy two different pieces of text using Command-C, a context menu, or any other method.
3. Click the CopyCue icon and choose **Restore previous**.
4. Paste normally with Command-V.

Choose **Settings…** from the menu-bar menu to adjust how long the blue cursor feedback remains visible.

Because CopyCue deliberately does not monitor keyboard input, it can confirm successful clipboard changes but cannot report a failed copy attempt.

## Privacy and security

CopyCue has no network or analytics code. It does not monitor keyboard input and does not intentionally write clipboard history to disk. It retains at most two text values of up to 1 MiB each in process memory and clears them when the app quits. The menu displays shortened previews only after the user opens it.

See [PRIVACY.md](PRIVACY.md) for the data-handling details and [SECURITY.md](SECURITY.md) for responsible vulnerability reporting.

## License

No open-source license has been granted yet. The source is publicly visible, but remains `UNLICENSED` until the project owner chooses a license.
