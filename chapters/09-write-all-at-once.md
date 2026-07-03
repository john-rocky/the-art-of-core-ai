# Chapter 9 — Writing It All at Once

Something strange happens on a Mac's screen.

Ask "What is 48 + 24?" and the answer field first shows a row of masks, something like `░░ ░ ░░ = ░░`. The next instant, **the middle digits fill in first**: `48 + ░4 = 7░`. Then the rest fills in: `48 + 24 = 72`. The text is not being written left to right. The whole thing appears at once, darkening into view.

This model is called a **diffusion LLM** (dLLM). Its generation principle differs at the root from the LLMs of the chapters so far — the write-one-token-at-a-time, left-to-right approach (called autoregressive).

Here is how it works. First, prepare a fixed-length canvas for the answer and fill every cell with `[MASK]` — masks. The model reads the whole canvas at once and predicts **candidates for every cell simultaneously**. Then it peels the masks off the cells it is confident about. The revealed characters become hints, and the next prediction is a little more certain. Peel again. Repeat this a dozen or so times until the canvas is full.

This approach has no KV cache. There is no past and no future — every step computes the whole canvas at once. — Doesn't this shape of work look familiar? **It's prefill.** The shape the last chapter called "ruled by computation." Instead of sequential token-by-token reads, a small number of large batched computations. A diffusion LLM is an LLM that does all of its generation in prefill's world.

You can restate this in Chapter 7's terms too. That chapter's conclusion was: make more than one token per read, and the ceiling's premise breaks. A diffusion LLM peels multiple cells at once in a single batched computation — **it does "multiple tokens per read" not as a bolted-on trick, but as the model's very design**.

So how fast is it? LLaDA-8B, ported for the zoo (8 billion parameters, 4.9GB at 4-bit), runs at around 40 tokens per second on an M4 Mac. ...Let's be honest. Today, it loses to the autoregressive 8B in Chapter 2's table (94 tokens per second). Each batched computation is heavy (the whole canvas plus the 8B weights), and repeating it a dozen or so times is not yet cheap.

Why devote a chapter to this approach anyway? Because **the source of its speed is different**. Autoregressive speed is bound by memory bandwidth, and bandwidth barely grows as chips move through generations. Diffusion speed is bound by compute power, and compute power is exactly what is growing every generation right now — the previous chapter's neural accelerator is a circuit for this shape of work. Today's win-loss record, and the direction the growing axis points, are separate stories.

There are two interesting measurements.

First. **On this model, 4-bit did not break the language.** Chapter 4's "4-bit without QAT falls through the floor" does not hold here. The trick lies in the generation principle. In autoregressive generation, one wrongly picked token is carved into the text as-is, and every subsequent token piles up on top of that mistake. In diffusion, even when quantization error changes the order of which cells get peeled first, the model **lands on a different but equally coherent sentence**. In fact, the 4-bit version matched the original model on only 20 of 64 tokens — yet reading it, the answers were correct throughout. Only the phrasing differed. We nearly looked at that number alone and threw 4-bit away as "broken." **Some models must not be graded by token match rate. Grade them by the text of the answer.** A new variation on Chapter 2's "question what you're measuring."

Second. **Get greedy with parallelism, and the language breaks.** The more cells you peel at once, the faster the generation — but push it too far and the answer to "count from 1 to 20" garbles into `11,22,2,3…`. Characters finalized simultaneously, without seeing each other, cannot keep their story straight. The shipped version cuts the canvas into blocks of 32 cells and peels in parallel only within a block. Overall order is kept by advancing block by block; speed is earned by the parallelism inside each block.

---

The same "diffusion" principle works even more vividly outside language. Time to collect the other fact placed at the opening of Chapter 1: **a model that makes 11 seconds of music in 0.9 seconds** — Stable Audio Open Small, 341M.

Its construction is a sibling of the diffusion LLM. A small text encoder reads the prompt; **8 rounds** of rewriting (denoising) finish a latent representation — the "blueprint of the sound" — and finally a decoder unfolds it into a waveform. Measured on an iPhone 17 Pro: generating 11.9 seconds of stereo audio takes **0.9 seconds**. 13× faster than real time. Loading the model is a one-time 3.9 seconds; after that, it answers the moment you ask.

Why "music generation on a phone" is fast should need no explanation by now. 8 batched computations plus 1 unfolding, and 11 seconds' worth comes out **all at once**. Sequential token-by-token, note-by-note reads simply don't exist. At a small 341M, nearly all the work is computation — riding exactly the axis the iPhone's GPU strengthens every generation.

---

Let's sort it out. Generation has two worlds. The sequential world (autoregressive decode) is bound by reads, and fights with the tools of Chapters 4–7. The batched world (prefill, diffusion) is bound by computation, and receives the growth in chip compute power directly.

And the compute world has residents we haven't introduced yet. The **fixed-shape encoders** we walked past in Chapter 3 with nothing more than "they get along well with the ANE." Models that transcribe sound, models that measure depth in images, models that cut subjects out of photos. The next chapter is about them — and about a currency other than speed, waiting where they live.
