# CopyCue Privacy

CopyCue is designed to provide local visual feedback when the macOS clipboard changes.

## Data CopyCue reads

- The app polls `NSPasteboard.general.changeCount` to detect clipboard changes.
- After a change, it asks macOS for the clipboard's plain-text representation.
- It does not monitor global keyboard input.

## Data CopyCue retains

- The current and immediately previous distinct text values are retained in process memory.
- Each retained value is limited to 1 MiB of UTF-8 text. Larger clipboard changes still receive visual confirmation but are not retained in history.
- Clipboard history is cleared when CopyCue quits. CopyCue does not intentionally write that history to files, preferences, logs, or a database.
- The selected cursor-feedback duration is stored in macOS user preferences.

## Data CopyCue displays

When the user opens the menu-bar menu, CopyCue displays shortened previews of the retained values. Control characters are removed from those previews. The complete value is restored to the clipboard only when the user chooses **Restore previous**.

## Network activity

CopyCue contains no networking, advertising, analytics, account, or telemetry functionality. Clipboard content is not sent anywhere by CopyCue.

## Removing data

Choose **Clear Text History** from the CopyCue menu, or quit CopyCue, to remove the two retained values from the running app.
