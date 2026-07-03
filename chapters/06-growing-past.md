# Chapter 6 — The Ever-Growing Past

Let's start by giving the trick away. When an LLM's attention mechanism produces one new token, it computes a comparison against every token so far. Token 1000 needs comparison material for 999 tokens. With no cleverness, that material gets recomputed from scratch every token. Double the conversation and the compute quadruples. Long conversations aren't just slow — they're unusable.

Fortunately, the material comes out the same every time. The material for tokens 1 through 9, built at token 10, can still be used unchanged at token 1000. So don't throw it away — keep it. This is the **KV cache**. The name comes from what the material is (K = keys, V = values). Instead of recomputing the past's material, you read what you remembered.

This is where one of the features Core AI added over Core ML comes in. **state** — a region the model reads and writes on its own. It is exactly where the KV cache lives. In the Core ML era, the only place to keep it was outside the model: every token, you handed the entire cache to the model and took it back again. In Core AI, the cache stays put next to the GPU, and the model appends to its tail by itself.

But did you notice? The KV cache eliminated the **compute**, not the **reading**. The remembered material gets read every token. A 1000-token conversation means 1000 tokens' worth; 10,000 tokens means 10,000 tokens' worth. The KV cache is a device that converts a "recompute problem" into a "reading problem." And we already know how to do the math on reading problems. Per-token reading = weights + **cache**. The longer the conversation, the more the latter grows, and the slower generation gets. This is why token 1000 is heavier than token 10.

Chapters 4 and 5 cut the weights. How do you cut a cache that keeps growing?

Start with the radical answer. There are **LLMs that carry no cache**.

They are a lineage called RWKV (with a few relatives, such as Mamba). Instead of remembering past tokens one by one, the model holds a single fixed-size "state." Each time a new token arrives, it rewrites that state a little. The past remains not as a sequence of tokens but blended into the state.

Whether the conversation is 10 tokens or 100,000, the state stays the same size. Per-token reading = weights + a fixed-size state. Which means this model **never slows down, no matter how long the conversation gets**. Token 1000 and token 10 weigh the same.

This property is not free. To blend into a fixed size is to compress. Where the Transformer's cache is a complete record of the conversation, RWKV's state is closer to a summary. At the job of pulling out "that proper noun from 3000 tokens ago" word for word, the side holding the complete record is stronger. It hands over precision of memory in exchange for speed.

Getting this to run on Core AI hit one interesting obstacle: the pipelined engine from Chapter 2. That engine is built on the premise that "an LLM has a KV cache," and hooking up a cache-less model doesn't work. We wanted the engine's speed, but the premise didn't fit. The answer was to write our own small runtime that binds the model's states by name (how to build it is in the appendix).

The RWKV-7 1.5B shipped this way runs at 25.2 tokens per second on an iPhone 17 Pro. More important than the number itself is that this speed is **independent of conversation length**. If you're building an always-on assistant that listens for hours on a battery-powered device, this property matters more than speed.

A complete record, or a fixed-size summary? Model design in 2026 is, in fact, graduating from this either-or. The answer is a blend.

The recent new designs — Qwen3.5, IBM's Granite, Liquid's LFM — make most layers the fixed-state kind and keep the complete record (ordinary attention) in **only one layer out of every few**. In most layers the reading is constant; the occasional record-keeper layer handles "the proper noun from 3000 tokens ago." The best of both speed and memory. Another blend cuts the record down to "only the most recent few thousand tokens" (the sliding window), used by Gemma and others. Old records get overwritten, and the cache tops out at a fixed size.

Seen from Core AI's side, all of these are just "**different shapes of state**." The complete record is a state that grows. RWKV is a fixed state. Hybrids are a mix of the two. The window is a state bent into a ring. Chapter 1 said Core AI made state a first-class citizen. Part of what that means is that it can absorb this diversity — though Apple's off-the-shelf runtimes assume only the standard shape, and the wiring that connects the odd ones to the engine is, time and again, yours to build. In shipping the zoo, the most labor-intensive part is in fact this wiring.

And with that, the paths for "cutting what gets read" are exhausted. Compress the weights (Chapter 4). Don't read the weights you don't use (Chapter 5). Compress the past (this chapter). Every one was about reducing the amount of reading itself.

One last path of a different kind remains. Remember the condition attached to the division in Chapter 1? "**As long as every token reads all the weights**, this division cannot be beaten" — that "as long as."

Not reducing what gets read. **Making two or more tokens from a single read.** The next chapter is about breaking the ceiling's premise.
