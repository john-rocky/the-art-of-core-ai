# Lab 5 — Honest Measurement

When you tell someone how fast your shipped model is, that number must be reproducible, its conditions must be stated, and the comparison must be fair. This Lab collects the procedure behind every measured number in the zoo, and the **typical ways numbers lie** (all experienced firsthand). It is the practical companion to Chapter 2's "what did you measure on."

## A. Tools — measure without going through the UI

- **Mac**: the official CLI's `llm-benchmark`. The protocol is aligned with the MLX-side benchmark (generate 1024 tokens from a 512-token prompt, average of 5 runs), so **comparison against MLX is fair as-is**. The tables in Chapter 2 use these conditions
- **iPhone**: use a measurement-only harness (an evolution of Lab 4's headless self-test). It bypasses the chat UI entirely and logs only the load → prefill → decode times. Every on-device number in the zoo is taken this way

## B. Seven ways numbers lie

**1. Comparing across numbers taken under different conditions.** The only comparison you may cite is "**an A/B measured back-to-back, alternating, under the same conditions**." Do not line up yesterday's number against today's, another bundle's number, or a number from someone else's environment and claim "it got faster."

**2. Measuring on a bundle you will not ship.** Real example: on one VLM (an LLM that also reads images), measuring the effect of an 8-bit LM head on a text-only bundle gives **+48%**. But the VLM bundle actually shipped is heavier — it binds the image buffers every step — and the same improvement dilutes to **+36%**. Do not present a number measured on a proxy (a stand-in configuration) as the shipped artifact's number.

**3. Ignoring temperature.** An iPhone slows down when it gets hot. The same model: 70 in the cold state right after a reboot, 64 in the warmed-up state while being handled. **Absolute values move with temperature, but the A/B ratio is robust** — so cite improvements as percentages. If you publish absolute values, state the thermal conditions (if you publish a demo video, match the video's conditions).

**4. Mixing cold and warm.** The first run includes on-device compilation and is a different animal (Lab 4). Record them separately; cite warm as a rule.

**5. Measuring on a Debug build.** You get numbers about 3x slower (Lab 3). Always measure Release.

**6. Reporting the app's UI bottleneck as the model's number.** Real example: a chat UI that **re-decodes the entire token sequence through the tokenizer from scratch** on every generation grows its workload as the square of the token count, dragging long outputs down to 10 tokens per second — with the model doing nothing wrong. The fix: throttle screen updates to around 25 per second, and **exclude UI-processing time from the measurement timer**. Note that full incrementalization — "decode only the new tokens" — produces garbled characters (�) when one character spans multiple tokens, as in Japanese, so throttling is the safe play.

**7. Not sanity-checking.** Take your number and apply Chapter 1's division in reverse (generation speed × bundle size = effective bandwidth). **If it exceeds the theoretical bandwidth, the measurement is wrong** (not reading everything = normal for MoE or spec-decode; a timing bug for dense). **If it lands exactly on the read-everything theoretical value, suspect wasted reads** (this is exactly how Chapter 5's discovery was made). A number is not done once produced — check it against the physics.

## C. Operational tidbits

- **The GPU "wedges."** On a day of repeated 1GB-class loads, model loading can freeze at first-run compilation and the console connection can drop. It looks like a code regression, but **rebooting the device fixes it**. Before suspecting your code, confirm whether your change really touched the engine side, then try a reboot
- **The citation template**: at minimum, attach these to any number — device (e.g. iPhone 17 Pro) / OS / bundle (quantization, size) / cold or warm / thermal state / protocol (prompt length, generation length, run count). Every number in this book is in this format, as practice of this very template

---

Postscript: of these seven patterns, 1, 2, 3, and 6 were stepped on during the writing of this very book (Chapter 2's "half of MLX" incident = a variant of pattern 1). Rather than hiding measurement failures, publishing them conditions and all, so others can reproduce them, is in the end what earns the most trust.
