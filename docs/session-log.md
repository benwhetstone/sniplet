# Sniplet Session Log

## 2026-04-01

### Recovered Context From Lost Codex Thread
- Located the prior project thread in local Codex storage rather than in the project folder.
- Recovered the main working thread: `Build macOS snipping app`.
- Confirmed the project source lives at `/Users/benwhetstone/Documents/Software Projects/Sniplet`.

### Summary Of Work Already Completed
- Built the core macOS screenshot utility and packaged app bundle.
- Added screenshot shortcuts for selection, current screen, and markup variants.
- Added menu text shortcut labels using abbreviations instead of symbol glyphs.
- Added `About Sniplet` with designer credit.
- Added a local `Update Sniplet` menu action for one-click local replacement and relaunch.
- Reworked markup toward inline editing, font controls, color swatches, dragging, and a bottom save bar.
- Added text background choices.
- Increased markup window size and minimum sizing behavior.
- Added crop presets for common social sizes.
- Changed save UI copy to `Save and Close`.
- Repeatedly rebuilt, repackaged, and reinstalled the app into `/Applications/Sniplet.app`.

### Remaining Priorities Carried Forward
- Reduce saved screenshot sizes further where they are still too large.
- Polish markup interactions until all tools behave consistently.
- Add blur and redaction tools for privacy-sensitive real estate use.
- Keep improving the app as a dependable high-frequency work tool.

### Durability Changes Added
- Added `PROJECT_NOTES.md` as a durable project memory file.
- Added this `docs/session-log.md` file for concise session checkpoints.
- Planned first git commit so the project history is no longer thread-dependent.

### Privacy Tools And Preferences Cleanup
- Added a drag-to-area `Blur` tool in the markup editor.
- Added a drag-to-area `Redact` tool with a solid black privacy box.
- Kept both privacy tools movable through the existing move interaction model.
- Updated Preferences to match current export behavior by changing saved-copy wording from PNG to compressed JPG.
- Removed the introductory text block from the top of Preferences.
- Increased the Preferences window size and adjusted spacing so the bottom of the screen feels less cramped.
- Rebuilt the app, regenerated the installer DMG, replaced `/Applications/Sniplet.app`, and relaunched the installed app.

### Editor Reliability And Versioning Pass
- Reworked the markup toolbar into a two-row layout so controls fit more cleanly and feel less cramped.
- Increased the markup window size and minimum size again to reduce clipping pressure.
- Added persistent selection visuals for move/edit mode so annotations remain editable after you click away and come back.
- Added resize handles for rectangle-style annotations including blur and redact boxes.
- Added stronger tool guidance in the editor for move, blur, redact, and text behavior.
- Changed the saved-image rendering path to use a flipped drawing context so saved markups line up with the editor preview.
- Updated capture-related messaging to say "saved capture" or "image file" instead of outdated PNG wording.
- Added a bundle-backed versioning scheme:
- Marketing version: `0.6.0`
- Build version: `20260401.2`
- Surfaced that version/build string in the About menu and About dialog.
- Rebuilt the app, regenerated the installer DMG, replaced `/Applications/Sniplet.app`, and relaunched the installed app.
