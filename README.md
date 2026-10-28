# WindowMochi

A cute macOS menu bar app that remembers your window layouts and restores them across multiple displays, with global shortcuts and multilingual support.

<p align="center">
  <img src="assets/branding/windowmochi-mascot-v1.png" alt="WindowMochi, a mochi mascot holding two windows" width="320">
</p>

## See it in action

<p align="center">
  <img src="docs/media/windowmochi-demo.gif" alt="WindowMochi demo: windows scattered across three monitors are saved as a layout, get shuffled, and snap back into place with one shortcut" width="640">
</p>

## Requirements

- macOS 13 or later.
- Apple Silicon for the current build script.
- Accessibility permission to move and resize other apps' windows.
- Apple Command Line Tools with Swift 6 to build from source.

## Build and launch

```sh
git clone https://github.com/SuBoYu/windowmochi.git
cd windowmochi
./scripts/build.sh
open dist/WindowMochi.app
```

WindowMochi runs in the menu bar; it does not open a regular app window. Click the mochi icon near the top-right corner of your screen.

The build script compiles the app, creates its mascot icon, and applies a local ad-hoc signature. The app is not notarized by Apple. Rebuilding may require granting Accessibility permission again.

## Run with help from Claude

Use **Claude Code running locally on your Mac** so it can inspect the project and run build and launch commands. Start with the [official Claude Code getting-started guide](https://support.claude.com/en/articles/14552382-your-first-day-in-claude-code) if you have not installed it yet. A regular chat without local command access can explain the steps, but you will need to run the commands yourself.

### First-time setup

Start Claude Code in a local folder where you want to keep the project, then paste this prompt:

```text
Help me build and run WindowMochi on this Mac:
https://github.com/SuBoYu/windowmochi

1. Check that this is an Apple Silicon Mac running macOS 13 or later,
   and that Apple Command Line Tools with Swift 6 are available. If a
   prerequisite is missing, explain what I need to install and wait
   for me to finish any system installer.
2. Reuse an existing local checkout if available. Otherwise, clone the
   repository into the current folder without overwriting existing files.
3. Read README.md and scripts/build.sh. Build with ./scripts/build.sh
   if dist/WindowMochi.app does not exist or I request a rebuild.
4. Open dist/WindowMochi.app using its absolute path and check whether
   the process is running. Tell me where to find its menu bar icon.
5. Guide me through granting Accessibility permission to that exact
   app in System Settings. Let me make the permission change myself.
6. Walk me through saving a layout, moving a window, and restoring
   the layout to verify that window control works.

If something fails, show the relevant error and diagnose it before
retrying. Do not reset system permissions, delete saved layouts,
change code, or rebuild an already authorized app unnecessarily.
```

When macOS asks for Accessibility permission, enable **WindowMochi**, not Claude, for WindowMochi's window-control feature. A running process alone does not confirm that window control works; verify it by saving and restoring a layout.

### Open an app you already built

Start Claude Code in your existing checkout and ask:

```text
Open the existing dist/WindowMochi.app from this checkout using its
absolute path, then verify that it is running. Do not rebuild it.
If it is already running, tell me how to find its menu bar icon.
```

If Claude cannot find your checkout, give it the local folder path. It can then run:

```sh
open "/absolute/path/to/windowmochi/dist/WindowMochi.app"
```

If the Accessibility switch is enabled but window control still fails, ask:

```text
Help me follow the Accessibility permission troubleshooting section
in README.md for this exact WindowMochi.app. Show its absolute path
and guide me through removing and re-adding the old entry myself.
Do not rebuild the app or reset permissions for other applications.
```

See [Accessibility permission troubleshooting](#accessibility-permission-troubleshooting) below for the recovery steps. Local ad-hoc rebuilds can invalidate an earlier authorization, so reuse the existing app when you only want to launch it.

## Save and restore a layout

1. Choose **Grant Accessibility permission…** and enable WindowMochi in **System Settings → Privacy & Security → Accessibility**.
2. Arrange your open windows across your displays.
3. Choose **Save current layout…** and enter a name, such as Work or Meetings.
4. Move or resize your windows, then select the saved layout to restore it.

Save multiple layouts for different activities. Replacing a layout with the same name requires confirmation and preserves its position in the list.

## Screenshot shelf

Choose **Recent screenshots…** from the mochi menu, or press **Control + Option + Command + S**, to open a separate screenshot panel.

### Keep new screenshots off your Desktop

1. Click **Set up folder** to create `~/Pictures/WindowMochi/Screenshots`, or **Choose folder…** to select another dedicated folder.
2. Click **Set macOS save location…**, then **Copy path & open Screenshot**.
3. In the macOS Screenshot toolbar, select a still-image mode and choose **Options → Save to → Other Location…**. Press **Command + Shift + G**, paste the copied folder path, and choose that folder.
4. Take a screenshot with **Command + Shift + 3 / 4 / 5** and return to the shelf.

**The folder selection in WindowMochi and the macOS save destination are separate settings.** Creating or selecting a folder does not change macOS screenshot preferences automatically. Follow the toolbar steps above to route new captures to that folder. You can return to Desktop or choose another save destination through the same macOS Options menu. See [Apple's screenshot guide](https://support.apple.com/en-us/102646).

### Browse, copy, and drag

- The shelf shows up to **30 images**, newest modification time first, from the selected folder. It refreshes every two seconds while open, after macOS finishes saving the file.
- Drag a **thumbnail** to Finder, Mail, Slack, or another app that accepts file drops. The drag offers the original file as a copy; the source stays in its folder. Support depends on the receiving app.
- **Open** launches the image in its default app. **Copy image** puts the image on the clipboard. **Show in Finder** reveals the original file.
- **Open folder** opens the selected storage folder. **Refresh** immediately rescans it.
- The selected folder and its access bookmark persist across launches. If access is lost, use **Choose folder…** to select it again.

The shelf reads image files from the chosen folder only, without searching subfolders. Supported extensions are PNG, JPEG, TIFF, HEIC/HEIF, BMP, and GIF. In a shared folder, other images also appear, so a dedicated screenshots folder is recommended. Clipboard-only captures, screen recordings, hidden files, symbolic links, and empty files are not listed. No screen-recording or Accessibility permission is required for browsing files; macOS may ask for folder access.

### Review and organize old Desktop screenshots

1. Set up the destination folder first.
2. Click **Organize old Desktop screenshots…** and select your Desktop folder to grant access.
3. Review the candidate filenames and check only the screenshots you want to move. **Nothing is checked by default.**
4. Click **Move selected**, or **Cancel** to leave everything in place.

Only regular image files carrying macOS's screenshot metadata flag are offered. Files identified by name alone are not moved, so screenshots that have lost their metadata may need to be moved manually in Finder. The transfer rechecks the flag before moving each file. If a name already exists in the destination, a numbered name keeps both files. Failures are reported per file, and the app does not overwrite existing files or delete unrelated Desktop items. Move files back using Finder if needed. There is no automatic Desktop cleanup.

File-operation tests use isolated temporary files and never modify the real Desktop:

```sh
python3 tests/check_screenshot_library.py
```

## Delete a layout

Open the mochi menu, choose **Delete layout…**, then select the layout to remove. Review the confirmation and click **Delete**. **Cancel** is selected by default.

Deleting a layout removes its saved configuration from disk without moving or closing any windows. The remaining layouts keep their relative order and shift up, so their number shortcuts may change. Deletion cannot be undone. Accessibility permission is not required to delete a saved layout. If saving the deletion fails, the layout stays available and the app displays an error.

## Global shortcuts

| Shortcut | Action |
| --- | --- |
| Control + Option + Command + 1–9 | Restore layouts 1–9 |
| Control + Option + Command + → | Restore the next layout, wrapping to the first |
| Control + Option + Command + ← | Restore the previous layout, wrapping to the last |
| Control + Option + Command + S | Open the screenshot shelf |

Shortcuts work while WindowMochi is running, including when another app is in the foreground. The menu shows layout order and the currently selected layout. Before a layout has been selected, → starts with the first layout and ← starts with the last. Layouts beyond the first nine remain available through the arrow shortcuts and menu.

Successful shortcut restores do not open a dialog. Missing windows or rejected adjustments display a report. Shortcuts are currently fixed; registration failures display a warning, and menu-based restoration remains available. The app registers specific combinations through Carbon rather than capturing general typing.

## Languages

English, Traditional Chinese, Simplified Chinese, and Japanese are included. WindowMochi follows your system language preferences by default and falls back to English for unsupported languages. Choose **Language** from the menu to switch immediately; your choice persists across launches. User-defined layout names are not translated.

UI strings live in `Sources/WindowMochi/Resources/*.json` and use stable keys with format arguments. To add a language, create a matching JSON file and register the locale in `Localization.swift`, the language menu, and the build script's `CFBundleLocalizations` list. Update the expected locales in the translation check as well.

```sh
python3 tests/check_localizations.py
```

This checks translation coverage, nonempty values, and format-argument compatibility.

## Storage and privacy

Layouts are stored locally in:

```text
~/Library/Application Support/WindowHabit/layouts.json
```

The file contains app identifiers, window titles, display identifiers, and window geometry. It is outside the source repository. Choose **Open layouts folder** to inspect it. To clear all layouts, quit the app, delete the file, and relaunch.

## Behavior and limitations

- Only open, non-minimized, non-full-screen standard windows are included. Closed apps are not launched automatically.
- Displays are matched by UUID, and geometry is restored using relative positions and sizes. If a display is missing, windows fall back to the built-in display, or another available display.
- Windows are matched within each app using titles and window order. Changed titles, duplicate titles, or reordered windows can make matching ambiguous.
- The app does not switch Spaces or recreate browser tabs.
- Some apps enforce minimum window sizes, adjust positions themselves, or reject Accessibility operations.
- Automatic restoration on display connection, launch at login, and customizable shortcuts are not yet included.

## Branding and upgrades

The WindowMochi mascot appears in the app icon, menu bar, and About dialog. `scripts/build-icon.sh` packages `assets/branding/windowmochi-mascot-v1.png` into macOS icon sizes and an ICNS file using built-in macOS tools.

The app was originally named WindowHabit. Its bundle identifier remains `local.windowhabit.app`, and its storage folder retains the old name to preserve existing language preferences and layouts. The Swift target and app bundle are now named WindowMochi. Quit the old version before opening `dist/WindowMochi.app` to avoid competing shortcut registrations.

## Validation

Release compilation, signature verification, and translation checks have passed. Global shortcuts, persisted language selection, and actual multi-display window movement still require manual verification with Accessibility permission enabled.

Manual checks:

- Save windows from two apps on different displays, change their geometry, and restore them.
- Save two differently titled windows from the same app and verify matching.
- Disconnect the external display and confirm restored windows remain visible.
- Close a saved window and check the missing-window report.
- Deny Accessibility permission and confirm the app shows guidance without moving windows.
- Switch through all four languages, check dialogs, and restart to confirm the choice persists.
- Switch between two layouts from another foreground app using number and arrow shortcuts.
- Verify cycling at both ends of the list and stable shortcut assignments after replacing a layout.
- Confirm unused number shortcuts and cycling with no layouts have no effect.
- Reserve a shortcut in another app and verify the conflict warning and menu fallback.

## Repository

[SuBoYu/windowmochi](https://github.com/SuBoYu/windowmochi) · [GitHub setup guide](docs/GITHUB_SETUP.md)

## Accessibility permission troubleshooting

If the switch is enabled but window control still fails, the saved authorization may refer to an older build or another copy of the app. Local ad-hoc builds have a hash-based signing requirement that can change after rebuilding. Restarting alone does not repair an authorization for an older signature.

1. Quit WindowMochi, including any older WindowHabit copy.
2. Open **System Settings → Privacy & Security → Accessibility**.
3. Remove the old WindowMochi or WindowHabit entry using the minus button.
4. Use the plus button to add the exact `WindowMochi.app` you intend to run. In the file picker, press **Command + Shift + G** to enter its containing folder.
5. Enable it and reopen that same app. Do not rebuild between authorizing and reopening it.
6. Select **Grant Accessibility permission…** to check the current process. An authorized process now shows a success message; otherwise the dialog includes its exact app path.

The permission action previously displayed enable-permission guidance unconditionally, even for authorized processes. A regression check now exercises the actual action with granted and denied trust responses:

```sh
python3 tests/check_permission_flow.py
```

For development with a persistent signing certificate already configured on your Mac, build with its identity name or fingerprint:

```sh
WINDOWMOCHI_SIGNING_IDENTITY="YOUR_CODE_SIGNING_IDENTITY" ./scripts/build.sh
```

Use the same identity across builds. Without this variable, the script continues to use ad-hoc signing and warns about permission renewal. The build script does not create certificates, modify your keychain, or change macOS permission settings.

Screenshot shelf manual verification:

- Finish the macOS save-location setup, capture an image, and verify it appears in the open panel.
- Drag a thumbnail into Finder and an attachment-capable app, then confirm the source remains intact.
- Copy an image and paste it into Preview or a document; open it and reveal it in Finder.
- Restart and confirm the folder selection persists; switch languages with the panel open.
- Review old Desktop captures, cancel once, then select only a disposable test screenshot and move it.
- Verify that a duplicate filename keeps both files and unrelated Desktop photos stay untouched.
- Remove folder access or move the folder; confirm a readable error and recovery through Choose folder.

Screenshot file-operation checks, compilation, and translation coverage can run automatically. Actual file drops into other apps, macOS's save-location selection, and folder permission dialogs require manual verification on the desktop.
