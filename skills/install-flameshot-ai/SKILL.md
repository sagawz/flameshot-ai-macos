---
name: install-flameshot-ai
description: Build, install, upgrade, and verify this Flameshot AI fork on macOS from source. Use when a user wants to install the repository on an Intel or Apple-silicon Mac, diagnose missing build dependencies, replace an existing app safely, or validate signing and Screen Recording readiness.
---

# Install Flameshot AI

## Preflight

1. Confirm the host is macOS and detect `uname -m`; supported values are `x86_64` and `arm64`.
2. Verify Apple Command Line Tools with `xcrun --find clang`.
3. Verify CMake 3.13 or newer.
4. Locate Qt 5.15 with `QT_ROOT`, Homebrew `qt@5`/`qt5`, or `~/Qt/5.15.2/clang_64`. Require `lib/cmake/Qt5` and `bin/macdeployqt`.
5. Explain that this source repository is not a directly installable DMG/PKG and that the produced app is ad-hoc signed, not Apple-notarized.

## Install

Run the bundled installer from the repository root:

```sh
./skills/install-flameshot-ai/scripts/install.sh
```

Pass a nonstandard Qt location through `QT_ROOT=/path/to/Qt/5.15.x/clang_64`. The installer delegates to `scripts/install-macos.sh`, backs up an existing `/Applications/Flameshot AI.app`, builds for the current architecture, deploys Qt frameworks, signs the bundle, installs it, and verifies the signature.

Do not delete the backup until the newly installed app has been tested. Do not change Screen Recording permissions automatically.

## Verify

1. Check `file "/Applications/Flameshot AI.app/Contents/MacOS/flameshot"` for the expected architecture.
2. Run `codesign --verify --deep --strict "/Applications/Flameshot AI.app"`.
3. Launch the app and ask the user to grant Screen Recording under System Settings if macOS requires it.
4. On macOS 12.3+, test a short GIF and MP4. System audio requires macOS 13+; microphone permission is requested only when enabled; control-level snapping optionally requires Accessibility permission.
5. Test capture on the current Space, magnetic selection, Chinese tooltips, invalid QR feedback, OCR translation, and AI summary.
6. If Gatekeeper blocks first launch, direct the user to System Settings → Privacy & Security to explicitly allow the app; do not disable Gatekeeper globally.
