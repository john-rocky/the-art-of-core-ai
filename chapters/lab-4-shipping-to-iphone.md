# Lab 4 — Shipping to iPhone

This lab takes a model that has passed numerical verification on the Mac and runs it on a physical iPhone, all the way to collecting numbers. It is the implementation companion to Chapter 11. One term up front: **sideload** = sending files directly from the developer's machine to the device, bypassing App Store or Hub downloads. Embedding a multi-GB model in the app itself breaks builds and transfers, so in practice the standard move is to ship only the model separately, after the fact.

## A. AOT compilation — crush large graphs ahead of time

**AOT** stands for Ahead-Of-Time. As opposed to JIT (Just-In-Time), which compiles "at the moment of execution," it means getting compilation done "in advance."

The deciding factor is size. **Small graphs up to the 50MB class are fine with first-run on-device compilation (JIT)** — ship them as `.aimodel` and you keep the portability of running on any device. **Anything in the 1GB class or above requires AOT** (Chapter 11: JIT either stalls for minutes or dies out of memory).

```bash
xcrun coreai-build compile model.aimodel \
  --output out/ --platform iOS --architecture h18p \
  --preferred-compute gpu --min-deployment-version 27.0
# -> model.h18p.aimodelc (about 2x the source size; contains the precompiled graph)
```

- `h18p` refers to the **device-identifier generation** (iPhone 17 Pro = internal name `iPhone18,1` → `h18p`; M-series Mac → `h16c`). Note that this is not the marketing name
- The runtime API (`AIModel(contentsOf:)` etc.) **reads `.aimodel` and `.aimodelc` interchangeably**. No code changes needed

## B. sideload — transferring with devicectl, and its traps

`devicectl` is the device-control CLI that ships with Xcode (it does installation, file transfer, and app launch, all of it). The transfer destination is `Documents/` inside the app's **data container** — the dedicated storage area allocated to each app.

```bash
xcrun devicectl device copy to --device <UDID> \
  --domain-type appDataContainer --domain-identifier <bundle-id> \
  --source model.aimodelc --destination "Documents/Models/MyModel/model.aimodelc"
```

(UDID = the device's unique ID. Visible via `xcrun devicectl list devices`)

**Traps (in order of importance):**

1. **Always verify the transfer completed before the first load.** Load a partially copied bundle even once, and the residue of the failed first compilation gets **cached keyed on the content hash** — that model then keeps dying with a "file not found" error even after the copy completes (a variant of the Lab 3 trap, and recovery is hell). After transferring, use `devicectl device info files` to confirm the inner `main.mlirb` is **present at full size** before launching
2. **Transfer multiple files one at a time.** Sending them in a batch can **report success while files are actually missing**. When in doubt, copy them back with `copy from` and compare
3. **Never use `--remove-existing-content true`.** Add it thinking "clear the existing content first" and **the app's entire data container gets wiped** (every sideloaded gigabyte, all of it)
4. One piece of good news: **reinstalling the app preserves the data container.** Fix the app's code and reinstall, and the models you pushed are still alive

## C. Getting numbers on the device — the headless self-test

Poking the UI by hand and timing with a stopwatch is not how this is done. Use a **headless self-test** — build a measurement-only entry point into the app, triggered by an environment variable, that measures "load + N runs" with no UI and writes the results to a text file. The first run includes first-run compilation (cold); runs from the second onward are the true speed (warm), so record them separately.

```bash
# launch (env vars are passed via -e as JSON)
xcrun devicectl device process launch --device <UDID> \
  -e '{"MYMODEL_SELFTEST":"1"}' <bundle-id>
# collect the result
xcrun devicectl device copy from --device <UDID> \
  --domain-type appDataContainer --domain-identifier <bundle-id> \
  --source "Documents/selftest_result.txt" --destination /tmp/result.txt
```

- **The order is Mac → device.** Run the same self-test on the Mac first, confirm its output matches the reference (the oracle), and only then go to the device. Do not debug numbers and correctness on the device at the same time
- `devicectl --console` (streaming log display) **never exits on its own**. Waiting on a fixed timeout wastes that full duration every time, so dump the log to a file and poll: "kill when the completion marker appears"
- **Measure with a Release build** (Lab 3: Debug is about 3x slower). Note that starting a Release build in a fresh working directory can appear to hang on re-fetching Swift packages — reusing the Debug build's `-derivedDataPath` is fast

## D. The final check — memory life-or-death

For large models, once it runs, check the **memory headroom** (Chapter 11: the enemy is not capacity but jetsam). The weights of an AOT-compiled bundle are a read-only map (clean), so they should be off the books — add free-memory logging to the self-test and you can detect "it ran, but on the edge of the cliff" before shipping. For the 2GB class and above, do not forget the `increased-memory-limit` entitlement (Lab 3).

And, to repeat: **do not run an iOS bundle on a Mac** (the whole Mac reboots. Chapter 11).
