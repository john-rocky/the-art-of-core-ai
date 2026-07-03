# Chapter 10 — Watts, the Other Currency

This book has talked about almost nothing but LLMs so far, but in fact, of the zoo's 30 models, fewer than half can chat. The rest: a model that turns sound into text. A model that measures depth from a single photo. A model that cuts "the cup on the left" out of a photo when you point at it with a sentence. A model that turns text into a voice.

They share one trait: **the shape of their input is fixed.** Audio arrives in chunks of a fixed number of seconds. Images are resized to a fixed pixel count before going in. There is no input that grows like a conversation, so no KV cache and no state. The whole model, from entrance to exit, becomes **a single fixed compute graph**.

This property makes conversion work absurdly straightforward. The depth model (Depth Anything 3) matches the original model on the converted engine at **cos 1.000000** — ones through the sixth decimal place. The cutout model (SAM 3), dropped to fp16, differs from fp32 by **less than one part in ten thousand**. The LLM struggles of the previous chapters — state that grows, 4bit that collapses, wiring into the engine — barely exist in this world. That is how much power there is in a fixed shape.

And for a fixed-shape model, every run is bulk computation — in the previous chapter's terms, **every one of them lives in the world of compute**.

But their real demand is not speed. It is **staying on**. Transcription that keeps listening through a meeting. Depth that keeps running while the camera is pointed. Text-to-speech that waits on standby before the user even calls. The budget for this kind of work is written not in milliseconds but in **watts**. Not being fast once — running for an hour without draining the battery.

Here we pick up a thread we walked past in Chapter 3. The ANE.

The ANE, which had no role in LLM decode, becomes the star in this world. Fixed shapes, fp16 only, standard structures — the ANE's constraints are barely constraints for encoders. The audio encoder of the zoo's audio-understanding model needed just one trick to fit the ANE's style (folding the attention over variable-length audio segments into a single fixed-shape attention — the result is bit-exact), became always-on (resident) on the ANE, never touched the GPU, and the final output text did not change by a single character. It does the same inference on an order of magnitude less power — and it **leaves the GPU free**. The app's stars (the rendering, or one more LLM) can run on the GPU as usual.

The power ledger has one more currency unit — the same shape as the division in Chapter 1. Moving one byte of memory costs far more than doing one computation (in energy terms). So the "read fewer bytes" techniques of Chapters 4–7 were, all along, **power-saving techniques too**. Every byte cut for speed is, as-is, a saving in watts.

---

To close this chapter, one story where all three take the stage together. It happened while porting a text-to-speech model (Kokoro, just 82M).

The heart of this model is an old-fashioned LSTM — a sequential design that processes one character at a time. Run on the GPU, it was oddly slow. Measuring revealed why. Hundreds of small sequential computations were chained one after another, and **the overhead of issuing commands to the GPU outweighed the computation itself** — exactly the same disease as Chapter 2. Only this time it was outside the pipelined engine's territory.

The answer was to **run it on the CPU**. The CPU has no command-issue round trip. Working through small jobs in order has always been the CPU's specialty. Measured, the CPU beat the GPU.

That fills in the seating chart for the three compute units. Big matrices and bulk computation: **GPU**. Fixed-shape always-on (resident) work: **ANE**. Small sequential work: **CPU**. The answer to "where should it run" is decided not by how new or how prestigious the chip is, but by **the shape of the job**.

---

The story of the world of compute ends here. Looking back, the whole story of on-device AI performance can be written in three currencies. **Bytes** (what you read — Chapters 4–7). **Compute** (how much you can stack into one batch — Chapters 8 and 9). **Watts** (whether you can keep running — this chapter). Figuring out which currency a job pays in is, you could say, all there is to design.

But everything so far rested on one assumption: that the model **starts at all**.

The next part begins where that assumption breaks. Send a model that ran perfectly on a Mac to an iPhone, and it vanishes silently before producing its first token. Without even leaving a crash report.
