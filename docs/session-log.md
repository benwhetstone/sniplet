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

### Crop And Sharing Pass
- Replaced the old preset-driven center crop behavior with the start of a real crop-selection mode.
- Crop now begins with a drawn selection on the image, and aspect presets constrain the crop box instead of blindly center-cropping.
- Added `Cancel Crop` alongside `Apply Crop` and kept `Revert Original` available to return to the uncropped image state.
- Tightened clipboard and saved-image sizing further by lowering the normalized export dimension and JPEG quality target to improve paste/share compatibility.
- Rebuilt the app, regenerated the installer DMG, replaced `/Applications/Sniplet.app`, and relaunched the installed app.

### Edit Loop And Packaging Reliability
- Strengthened selection/editability by adding a `Delete Selected` action in the markup toolbar.
- Switched move-mode hit testing to use on-screen selection geometry so selecting and manipulating existing markups is more direct.
- Fixed the packaging pipeline to copy files without extended attributes and explicitly clear problematic Finder/file-provider metadata before codesign.
- Rebuilt the app, regenerated the installer DMG, replaced `/Applications/Sniplet.app`, and relaunched the installed app.

### Selection And Move Tightening
- Added an explicit click-to-select path in move mode using spatial tap location instead of relying only on drag-start behavior.
- Clamped moved annotation positions so items stay inside the editable canvas instead of drifting outside the image.
- Rebuilt the app, regenerated the installer DMG, replaced `/Applications/Sniplet.app`, and relaunched the installed app.

### Browser Tutorial
- Added a bundled `Tutorial & Help` page that opens in the user’s default browser from the Sniplet dropdown menu.
- Packaged the tutorial HTML inside the app resources so it ships with the installed app.
- Included setup guidance, permissions help, feature explanations, crop instructions, sharing notes, and update instructions in one place for non-technical users.
- Rebuilt the app, regenerated the installer DMG, replaced `/Applications/Sniplet.app`, and relaunched the installed app.

### Naming Recovery
- Found another round of internal naming drift where the app package was still `Sniplet` but the Swift target, source folder, test target, and app entry point still used `Snipboard`.
- Renamed the executable target and source/test folders back to `Sniplet` so the codebase matches the shipped app name again.
- Kept project memory updated here and in `PROJECT_NOTES.md` so the rename is easier to recover if thread context is lost again.

### Rebuild And Reinstall
- Rebuilt the current `Sniplet` app bundle from the renamed `Sniplet` target structure.
- Regenerated the installer DMG at `dist/Sniplet-Installer.dmg`.
- Replaced `/Applications/Sniplet.app` with the freshly packaged app and relaunched the installed copy.

### Export Reliability Pass
- Replaced the fixed JPG export quality with an adaptive compression budget that scales with image area, which should keep saved screenshot sizes more predictable while preserving more detail on smaller captures.
- Kept clipboard and saved-file output on the same normalized rendered image path so edited output stays aligned across both destinations.
- Changed overwrite saves to write through a temporary file replacement step before swapping in the edited file.
- Added coverage for export sizing helpers in `SnipletTests`.

### Packaging Hardening Follow-Up
- Packaging failed again because the app bundle still carried stubborn macOS metadata like `com.apple.provenance` and `FinderInfo`.
- Strengthened `scripts/package_app.sh` to recursively strip extended attributes before codesigning.
- Rebuilt the app, regenerated the DMG, replaced `/Applications/Sniplet.app`, and relaunched the installed app successfully after the packaging fix.

### Texting File Size Tightening
- Lowered the export long-edge cap from `2200` to `1800` pixels.
- Reduced the adaptive JPG byte budget and quality ladder so saved captures stay smaller for texting workflows.
- Rebuilt the app, regenerated the DMG, replaced `/Applications/Sniplet.app`, and relaunched the installed copy.

### Move And Resize Interaction Rewrite
- Revisited the interaction problem against Apple’s guidance and confirmed `Canvas` is for immediate-mode drawing, not interactive per-element editing.
- Replaced the SwiftUI drag-based interaction path with an AppKit-backed overlay that handles `mouseDown`, `mouseDragged`, and `mouseUp` directly over the image.
- Kept selection, move, and resize logic in the editor state model, but now drive it from deterministic mouse events instead of SwiftUI gesture sequencing.
- Rebuilt, re-signed, replaced `/Applications/Sniplet.app`, and relaunched the installed copy with the new interaction layer.

## 2026-04-04

### Geometry And Save Reliability Pass
- Centralized crop, movement, and text-overlay geometry into shared helpers so the editor uses one consistent layout model instead of drifted copies.
- Fixed text hit-testing and selection boxes so text annotations are treated as leading-anchored overlays instead of being incorrectly centered for editing.
- Improved `Undo` and `Clear` so they also clean up in-progress crop and editor interaction state instead of only removing committed annotations.
- Prevented saved-capture filename collisions by suffixing repeated timestamps instead of silently reusing the same `.jpg` name.
- Added targeted tests for crop mapping, constrained crop ratios, bounded movement, text selection geometry, export sizing, and filename collision handling.
- Rebuilt the app, repackaged `dist/Sniplet.app`, and relaunched the packaged copy.
