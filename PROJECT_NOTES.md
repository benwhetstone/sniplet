# Sniplet Project Notes

## Purpose
Sniplet is a macOS screenshot and markup app being shaped into a fast, dependable daily-use tool for real estate work.

## Product Direction
- Optimize for speed, reliability, and low-friction capture.
- Make markup feel obvious and predictable during heavy daily use.
- Keep clipboard behavior trustworthy.
- Keep saved image sizes practical for sharing in emails, chats, and listings workflows.

## Current Shortcut Set
- `Control-Shift-4`: capture selection
- `Control-Shift-3`: capture current screen
- `Control-Option-4`: capture selection and open markup
- `Control-Option-3`: capture current screen and open markup

## Features Already Added
- Menu bar app with capture actions.
- Text-style shortcut labels in the menu such as `ctrl-shift-4` and `ctrl-opt-4`.
- `About Sniplet` menu item with `Designed by Ben Whetstone, 2026`.
- Local `Update Sniplet` menu action for replacing the installed app from a newer local copy.
- Inline text editing on the image.
- More font controls for text annotations.
- Inline color swatches instead of a separate color screen.
- Draggable annotations.
- Bottom action bar for save flow.
- Text background choices.
- Larger markup window with a minimum size.
- `Save and Close` action label.
- Crop presets:
- `Instagram Square`
- `Portrait 4:5`
- `Story 9:16`
- `Landscape 16:9`
- Privacy tools:
- `Blur`
- `Redact`
- Preferences window cleaned up with macOS-style card layout, no intro copy at the top, larger window sizing, and JPG wording that matches current export behavior.
- About now shows bundle-backed version/build information.

## Known Open Issues
- Saved screenshots may still be larger than desired in some cases.
- Markup UX still needs polish so all tools feel consistent and predictable.
- Need stronger confidence that save-to-disk and clipboard output always match the edited result.
- Need real-world validation that the latest move, resize, blur, and alignment fixes feel correct in use.
- Crop behavior is now being shifted from center-crop resizing into a real user-drawn crop-selection workflow.
- Clipboard/export sizing was tightened further to improve sharing and pasting into texting apps.
- Packaging script now strips problematic macOS metadata before codesigning so app packaging stays reliable.
- Built-in tutorial/help is now packaged with the app and opened from the menu in the user’s default browser.
- Package/module naming had drifted internally to `Snipboard`; it has now been brought back in line with the product name `Sniplet`.
- Export now uses an adaptive JPG compression budget instead of one fixed quality level so saved captures land in a more predictable size range.
- Export was tightened again for texting workflows by lowering the max long edge and overall JPG byte budget.
- Overwrite saves now write through a temporary replacement path before swapping the edited file into place.
- Packaging cleanup was tightened again to recursively strip stubborn macOS extended attributes before codesigning.

## High-Value Next Work
- Finish export/file-size reliability work.
- Continue cleanup toward a more native macOS feel.
- Add more real-estate-friendly annotation workflows if needed after the core flow is stable.
- Keep using semantic marketing versions with a date-based build number in the bundle metadata.

## Recovery Workflow
- Keep this file current after major product decisions.
- Append a short checkpoint to `docs/session-log.md` after meaningful work sessions.
- Commit source and notes regularly so project state does not depend on Codex thread history.
