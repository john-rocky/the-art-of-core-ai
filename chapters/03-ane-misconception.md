# Chapter 3 — The Dedicated-Chip Misunderstanding

Both the iPhone and the Mac carry a processor built purely for machine learning. **ANE** — the Apple Neural Engine. Its power efficiency is far better than the GPU's, and it's that part Apple presents every year at its chip announcements with "trillions of operations per second."

Core AI can run a converted model on the CPU, the GPU, or the ANE. So isn't the ANE where LLMs belong? I thought so too. My first few weeks with Core AI vanished into the work of getting an LLM onto the ANE.

"Getting it on" was not simple. The ANE accepts only computations of fixed shape. Input length: fixed. Numerics: fp16 only. Attention: one head at a time, in order. I rebuilt the model wholesale to the ANE's ways, and carried it to the point where its output matched PyTorch on the iPhone 17 Pro's ANE.

With that done, here is what was measured on real hardware.

| Model | ANE | GPU |
|---|---:|---:|
| Qwen3.5 0.8B | 14.7 tok/s | **71.9 tok/s** |
| Gemma4 E2B | 6 tok/s | **30 tok/s** |

**It lost by 5×.** The ANE version I had spent weeks building couldn't touch the GPU version of the same model.

It's the dedicated chip. Why?

Half the answer lies in Chapter 1's division.

What sets decode speed was memory bandwidth. And on Apple silicon, the CPU, the GPU, and the ANE all connect to **the same single memory** (unified memory). The ceiling on read speed is the same for all three. The ANE's billboard number — "trillions of operations per second" — is a compute number, and the decode contest isn't held there.

So on paper, there's no reason ANE decode shouldn't run about as fast as the GPU. And this can actually be checked. Align the weight format — make the bytes read the same — and measure again: **ANE decode comes out at nearly the same speed as the GPU.** The chip wasn't slow.

Then where did the 5× come from? It came from the constraints.

To take a shape that fits on the ANE, both how the weights are held and how execution is driven must change to the ANE's way. The ANE version has fixed shapes, tends the cache on the host side, and holds its weights in the lookup-table scheme (weights expressed as a small table of representative values plus indices — Chapter 4). The GPU version has free shapes, its cache lives inside the model, and above all, it can ride Chapter 2's pipelined engine. The ANE version can't. The true identity of the 5× gap wasn't a difference in chip performance — it was **this difference in tooling**.

So this gap isn't a matter of principle; it's where Apple's implementation stands today. But where it stands won't change any time soon. And the constraints bind the model side too. Only small, architecturally standard models fit inside the "fixed shapes" the ANE will take. An architecture like MoE — the odd-looking row in Chapter 2's table — is never even a candidate.

Of the thirty-odd models shipped by the zoo this book grew out of (the model depot I run), not one runs LLM decode on the ANE. All of them are on the GPU.

Then what is the ANE for?

The ANE's value doesn't sit on the speed axis.

One is **power**. The ANE does the same inference on far less energy than the GPU. That's what its dedicated design is for, and "trillions per second" is really a number for this context. Not whether one reply comes back fast, but whether the battery holds through a day of running. Whether it can sit resident in the background without heating up. In that contest, the ANE wins.

The other is that **the GPU comes free**. Put inference on the ANE and the GPU is left whole — for a game's rendering, for the app's UI, for one more model. When you want an iPhone doing several jobs at once, that's worth more than speed.

And there are models that get along with the ANE's constraints from the start. Models whose input shape is fixed — audio and vision **encoders**. In this book's zoo, the audio encoder of an audio-understanding model (it listens to sound and describes what it hears) lives resident on the ANE. Conversion agreement: 0.99. The final output text didn't change by a single character. When the shape is fixed, the ANE gives up no quality.

Put in order: LLM decode goes to the GPU. Fixed-shape encoders, and resident jobs that fight on battery, go to the ANE. Not "it's a dedicated chip, so it's fast" but **"it's a dedicated chip, so power is cheap"** — that's the right way to read the ANE.

The groundwork is now laid. Speed is set by the bytes you read (Chapter 1). Using them fully is the engine's job (Chapter 2). The place to run is the GPU (this chapter). From here on, we enter the techniques of how not to read. The first tool is the plainest of them — compress the weights by half, read half as much, and the ceiling should double.

Does it really double? And how far down can you cut?
