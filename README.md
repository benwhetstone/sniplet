# Sniplet

Sniplet is a lightweight macOS screenshot app built to feel closer to Windows Snipping Tool:

- region capture
- current-screen capture
- automatic clipboard copy
- optional default screenshot folder
- optional markup-after-capture flow
- edited screenshots overwrite the original saved image file
- menu bar UI with a minimalist preferences window
- launch-at-login support in app-bundle builds

## Shortcuts

- `Control-Shift-4`: capture a selected area
- `Control-Shift-3`: capture the current screen

Menu options also include capture modes that open markup immediately.

## Markup Mode

Markup mode opens a simple editor with:

- pen
- rectangle
- color picker
- stroke width
- undo
- save

When you save from markup mode, Sniplet overwrites the original saved image in your configured screenshot folder and refreshes the clipboard with the edited image.

## Build And Run

```bash
swift build
swift run
```

On first launch:

1. Allow Screen Recording when macOS asks.
2. Open Preferences and choose a screenshot folder if you want saved files or markup mode.

## Package As A Real App

```bash
swift scripts/generate_icon.swift
./scripts/package_app.sh
./scripts/create_dmg.sh
```

That creates a runnable app bundle here:

```bash
/Users/benwhetstone/Documents/Software Projects/Sniplet/dist/Sniplet.app
```

You can launch it with Finder or:

```bash
open "/Users/benwhetstone/Documents/Software Projects/Sniplet/dist/Sniplet.app"
```

## Install From GitHub

The public download page is:

```bash
https://github.com/benwhetstone/sniplet/releases/latest
```

Because Sniplet is shared without Apple notarization, the public DMG uses the normal Mac drag-to-Applications flow:

1. Download `Sniplet-Installer.dmg`
2. Open the disk image
3. Open `1 - Open Anyway Guide.html` if you want a plain-language walkthrough first
4. Drag `Sniplet.app` into `Applications`
5. Open `Sniplet` from `Applications`
6. If macOS blocks the first launch, follow the steps in `1 - Open Anyway Guide.html`

## Launch At Login Note

The launch-at-login toggle is implemented with `SMAppService`, which works properly when Sniplet is packaged as a standard macOS `.app`. When running directly from SwiftPM during development, macOS may refuse to register it for login items even though the rest of the app works.
