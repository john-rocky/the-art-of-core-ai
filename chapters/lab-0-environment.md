# Lab 0 — Environment Setup

From here on, the Lab section converts the "why" of the main chapters (Chapters 1–13) into "how." The style changes too: copy-paste-ready commands, code verified by actually running it, and bulleted traps.

## What you need

- An Apple Silicon **Mac (macOS 27)** — conversion and numerical verification are done entirely on the Mac (Chapter 1, Section 1.2)
- **Xcode 27** — if you are shipping to iPhone. Bundles the AOT compiler (`coreai-build`)
- **Python 3.12**
- An **iPhone (iOS 27)** if you are verifying on a real device

## Python side

```bash
python3.12 -m venv .venv && source .venv/bin/activate
pip install coreai-core coreai-torch coreai-optimization
#   coreai-core        : compiler + runtime (the closed part, as a wheel)
#   coreai-torch       : PyTorch -> Core AI converter
#   coreai-optimization: quantization / palettization
git clone https://github.com/apple/coreai-models   # official zoo + Swift runtime + primitives
python -c "import coreai.runtime, coreai_torch; print('ok')"
```

**Traps:**

- The `coreai-core` wheel is **tied to the OS version** (it links against the OS's `CoreAI.framework`). After an OS update, re-verify starting from `import coreai`
- Conversion reproducibility is also coupled to the OS. **After an OS update, numerically verify one previously converted model before** trusting any new conversion (every number in this book is protected by this procedure)

## Xcode side

You can use the beta without moving it to `/Applications` and without sudo:

```bash
export DEVELOPER_DIR=/path/to/Xcode-beta.app/Contents/Developer
xcodebuild -version          # Xcode 27.x
xcrun coreai-build --help    # AOT CLI (compile / package / inspect / metadata)
xcrun devicectl list devices # connected iPhones (iOS 27)
```

**Traps:**

- `coreai-build` is not on pip or PATH; it is found via `xcrun` **only when the active Xcode is the beta**. If you see `unable to find utility`, check `xcode-select -p`
- **Code that uses CoreAI will not even build for the iOS simulator** (the framework is absent from the simulator SDK). To check compilation, do an unsigned build against the device SDK:
  `xcodebuild … -sdk iphoneos -destination 'generic/platform=iOS' build CODE_SIGNING_ALLOWED=NO`

## Checkpoint

If `import coreai.runtime` succeeds and `xcrun coreai-build --help` prints, you are ready for Lab 1.
