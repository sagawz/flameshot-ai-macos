---
name: extend-flameshot-ai
description: Continue secondary development of the Flameshot AI macOS fork. Use when adding or fixing screenshot tools, Chinese UI, OCR, translation, QR recognition, AI summarization, macOS permissions, Spaces behavior, packaging, or related Qt/C++ code in this repository.
---

# Extend Flameshot AI

## Establish the baseline

1. Treat this repository as a GPL-3.0 fork of Flameshot 12.1.0; preserve upstream attribution and license notices.
2. Read `README.md` and `docs/SMART_FEATURES_ZH.md` before changing behavior.
3. Inspect the relevant Qt/C++ implementation instead of assuming current upstream Flameshot behavior.
4. Preserve unrelated local changes and never commit credentials, `.env` files, build output, or application bundles.

## Follow the architecture

- Add capture toolbar actions through `CaptureTool::Type`, `src/tools/toolfactory.cpp`, and a focused tool implementation.
- Keep orchestration and user feedback in `src/widgets/capture/capturewidget.*`.
- Keep OCR and QR logic in `NativeVisionService`; provide a non-macOS stub when changing its interface.
- Keep remote AI requests in `AiService`. Send recognized text only, never screenshot pixels, unless the user explicitly changes the privacy design.
- Put user-facing strings behind Qt translation and update Chinese translations/tooltips. Keep the repository build following the operating-system language; never force Chinese globally.

## Protect macOS behavior

- Keep OCR and QR recognition local through Apple Vision.
- Keep failure messages non-modal so the capture overlay never traps mouse or keyboard input.
- Preserve the window collection behavior that allows capture on the current Space.
- Do not repeatedly request Screen Recording permission. Diagnose bundle identity and signing requirements before changing permission code.
- Keep a stable designated requirement when ad-hoc signing so macOS privacy authorization survives rebuilds.

## Verify changes

1. Build with `./scripts/build-macos-intel.sh`; despite the legacy name, it detects `x86_64` or `arm64`.
2. Run the smallest relevant checks, then verify the app bundle with `codesign --verify --deep --strict build-smart/src/flameshot.app`.
3. For UI changes, manually test capture on the current desktop, Escape recovery, success and error paths, and Chinese labels/tooltips.
4. For AI changes, test missing-key, network-error, malformed-response, and success paths without logging the API key.
5. Update `README.md` and `docs/SMART_FEATURES_ZH.md` when behavior, installation, privacy, or configuration changes.
