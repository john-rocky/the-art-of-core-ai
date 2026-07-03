# Chapter 2 — 11% of the Ceiling

The first code anyone writes to run an LLM on Core AI comes out looking about the same. Load the converted model. Feed in the prompt. Run the model once, get the next token. Append it to the end of the input and run again. Repeat until the text ends. From here on, this one-token-at-a-time generation is called **decode**.

It's the natural way to write it, and it's also the shortest form you can build with just the basic API. Written this way, Core AI ran a model called Qwen3.5 0.8B at 58.5 tokens per second. Run the same model on MLX and you get roughly twice the speed. The "structural gap" report was born here.

The number to look at wasn't tok/s (generated tokens per second). Run Chapter 1's division backwards and you get how many GB per second that run is reading: generation speed × model size. Do the math, and this run was using **only 11%** of the M4 Max's 546GB/s of memory bandwidth.

The ceiling wasn't low. Ninety percent of the usable memory bandwidth was going unused. Most of the time, the model wasn't even reading.

The reason is the fineness of the work. Generating one token issues about 1000 small computations to the GPU, one after another. Each computation is over in an instant. But between one issue and the next comes, every time, the dispatch overhead of handing the GPU its next job. The smaller the jobs, the larger the share dispatch overhead takes. One-token-at-a-time generation was the worst case.

Apple had the answer ready from the start. **coreai-pipelined** — an execution engine bundled with Core AI, built solely for LLM generation. The heart of it: keep issuing the next commands ahead of time, without waiting for the current computation to finish. Instead of stopping for a round trip on every token, it pours an unbroken stream of commands into the GPU.

Same model, same weights, same Mac — replace the loop with this engine.

| Execution | Qwen3.5 0.8B decode |
|---|---:|
| The naive loop | 58.5 tok/s |
| pipelined engine | **204 tok/s** |

3.5×. Zero code written, zero custom kernels. Just by switching engines, the Core AI that had been "half of MLX" became "about twice MLX." The gap that was structural and would never close vanished without a fight. What my report had measured wasn't Core AI's ceiling. It was my loop's ceiling.

That failure became, as is, this book's rule of measurement. When you see a number, first question what it was measured on top of. What gets called "the framework's speed" is usually "the speed of that framework's most common usage."

So, with the engine chosen correctly, how big is the gap with MLX really?

I measured again. Same M4 Max, same conditions (1024 tokens generated from a 512-token prompt, averaged over 5 runs). This time the Core AI side runs the pipelined engine too.

| Model | Core AI | MLX | Gap |
|---|---:|---:|---|
| Qwen3 0.6B | **484** | 432 | +12% |
| Qwen3 4B | 145.4 | 145.8 | even |
| Qwen3 8B | **94.1** | 90.0 | +5% |
| Gemma3 4B | **141.5** | 136.3 | +4% |
| Gemma3 12B | 55.0 | 55.1 | even |
| Mistral 7B | **101.7** | 97.5 | +4% |
| gpt-oss-20B | 78.1 | **100.2** | **MLX +28%** |

(decode tok/s)

The structural gap was nowhere. On an ordinary Transformer, Core AI is even with MLX, or slightly faster.

Look closer and there's one more pattern in this table. The smaller the model, the more Core AI wins; the bigger it gets, the closer to even. This too reads through Chapter 1's division. Small models read little, so the contest is decided by who handles dispatch overhead better — and there, Apple's engine is strong. The bigger the model, the more it becomes a memory bandwidth contest, and MLX's 4-bit quantization (Core AI's default is 8-bit; what that difference means is for Chapter 4) catches up by reading less.

But one row looks off. gpt-oss-20B. This model alone loses outright. By 28%.

There's an architecture only this model has. **MoE** — Mixture of Experts. That story waits until Chapter 5. Because there's one misunderstanding to clear up first: "wouldn't it be fast if you ran it on the dedicated chip?"
