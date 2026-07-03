# Chapter 11 — The Law of Memory

On a Mac, a model was running perfectly. A 4.5GB model that listens to audio and describes what it hears. Numerical parity with PyTorch: confirmed. All that remained was to send it to an iPhone — or so it seemed.

Launch it on the iPhone, and midway through loading the model, the whole app vanished. The screen goes black for a moment, then back to the home screen. No ordinary crash report is left behind.

There were two causes of death. Anyone who runs models on an iPhone hits these two laws sooner or later.

**Law 1: Big models cannot be compiled on the device.**

On first run, a model is compiled for that device's chip (this process is called **specialization**). On a Mac, even a big model finishes if you wait a few minutes. Not on an iPhone. Compiling a big compute graph, under memory and time constraints, **collapses partway through and takes the whole process down**. Relaunch as many times as you like; it dies in the same place every time.

The answer is **AOT compilation**. AOT stands for Ahead-Of-Time — not at the moment of execution (Just-In-Time, JIT for short), but "in advance." With `coreai-build compile`, **your Mac does the heavy compilation in the iPhone's place**. Ship the resulting `.aimodelc` in your app, and all that remains on the device is a light per-device finishing pass (the official docs say "specialization remains but becomes drastically lighter" — measured, second and later loads of an AOT-compiled bundle finish in an instant). For a big model, then, AOT is not an "option that speeds up first launch." **It is a precondition — without it, the act of launching does not exist.**

**Law 2: iOS kills you not for the memory you use but for the memory you dirty.**

Get past the compilation problem, and you can still die. iOS has a mechanism called **jetsam** that terminates apps that put pressure on memory, without warning. The key point here is that what jetsam counts is only **dirty memory** — memory that can be written to. Read-only memory mapped directly from a file (clean) does not count, no matter how large. The OS can drop those pages at any time and read them back from the file when needed.

Here is AOT's other face. **The weights of an AOT-compiled bundle load as a read-only file mapping.** In other words, clean. That 4.5GB model, on the iPhone after AOT, had nearly all of its weights move outside jetsam's ledger, and launched safely — free memory after launch measured 5.9GB. With one change in how the weights are held, a size that meant instant death becomes a size with room to spare.

Did you notice? This book's established truth has surfaced with yet another face. In the decode chapters, how many bytes you **read** determined speed. For survival on an iPhone, how many bytes you **dirty** determines life or death. In both cases the answer sits on the same side — weights are read-only things, so hold them in a read-only form (clean).

**Bonus law: Never run an iOS bundle on a Mac.**

Finally, one law learned at high tuition. Take a bundle exported for iOS and "just quickly check it on the Mac before sending it to the device" — do this and the Mac's GPU driver stops responding, and 90 seconds later **the Mac reboots**. Not the app crashing. The whole Mac. The author lost two working sessions this way. Verify iOS bundles on a real device. No exceptions (the sideload procedure and its traps are in the appendix).

---

With that, the model launches, survives, and runs. But beyond "running" there is one more stage.

As it stands, this model is an island inside the app. Invisible to Siri, to Spotlight, to every other feature of the OS. Apple's first-party on-device LLM lives on the OS's prime real estate while your own model is a lodger — is that what you are thinking?

Actually, no. In 2026, Apple built **a mechanism that seats your own model in the same seat as the first-party one**. That is the next chapter.
