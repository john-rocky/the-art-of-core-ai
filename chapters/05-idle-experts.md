# Chapter 5 — The Idle Experts

gpt-oss-20B is a model of roughly 21 billion parameters. But when it produces one token, only 3.6 billion of them are actually used.

A model built this way is called an **MoE** (Mixture of Experts). The fattest part of a Transformer by weight — the MLP in each layer — is split not into one big block but into many small "experts." Then for each token, a small selection network (the router) picks just a few — "these experts, this time" — and routes the token through them. Not everyone works. Each time, only the chosen few do.

Why build a model this way? Read it through the division from Chapter 1 and you see it is an assault on the ceiling. A model's intelligence grows with its total parameter count; its generation speed is bound by how much it reads per token. MoE **decouples** the two. It gets smart on a total of 21 billion while reading only 3.6 billion's worth per token. It's a design that aims to take both intelligence and speed, and indeed, among the major open models of 2026, the bigger they are, the more likely they are MoE.

So gpt-oss-20B should have behaved not as a 21-billion model but as a "model that reads 3.6 billion." That's why MLX was putting out 100 tokens per second in the Chapter 2 table. Core AI got 78 — a 28% loss.

Investigation showed that Core AI was reading not just the chosen experts' weights but **the weights of every expert, every token**. The router was correctly picking its few. The computed results were correct too. It's just that Core AI was dutifully reading the unchosen experts' weights from memory, computing with them, and throwing the results away at the end.

The culprit was in how the model gets converted.

A converted model becomes a fixed compute graph. Which operations run, in which order, is pinned down in advance. But MoE's "which experts does this token go through" changes token by token. The two don't get along. Core AI's standard component resolved the contradiction in the laziest possible way — **compute everyone's share, then adopt only the chosen few's results**. The choosing comes after the computing. As computation it is correct; the answer comes out the same. But memory reads everyone's share.

You don't have to take this on suspicion; the numbers confirm it. Quantize another MoE, LFM2.5-8B (8 billion total parameters, 1 billion doing the work), to int8, and the bundle comes to 8.8GB. Run it on an M4 Max and you get 39 tokens per second. Do the multiplication. 39 × 8.8GB = 343GB per second. That is the ceiling on the read speed this GPU can actually sustain — in other words, **memory bandwidth is maxed out**. Maxed out, and slow. Because every token reads the full 8.8GB. Reading only the working 1 billion's worth should take roughly one eighth of that.

The numbers confess. "Happens to be slow" and "matches the theoretical value for reading everything" are different things. The latter is hard evidence.

The more extreme the model's design, the greater the damage. Qwen3.6-35B, which picks 8 experts out of 256, reads **32 times** the required amount every token. The 32× at the end of the previous chapter is this calculation. The Core AI version of this model runs at 30.9 tokens per second — only half of MLX.

One option is to wait for Apple to fix the component. But there is another: don't wait. Core AI comes, out of the box, with a mechanism for embedding your own GPU programs (kernels) inside a model.

What I wrote is a small program. It has exactly one job. Take the expert indices the router chose, read **only those experts' weights** from memory, and multiply. The unchosen experts' weights are never even touched.

Core AI's converter has, from the start, a mechanism for embedding a custom kernel like this (a small program that runs on the GPU) into the model's compute graph as a component (where this tool sits is laid out in Chapter 8; the procedure is in Lab 6 at the back of the book). I swapped the standard component's "compute everyone, adopt the chosen results" for the custom component's "choose first, then read," in every MoE layer.

The result:

| Model | Standard component | Custom kernel |
|---|---:|---:|
| LFM2.5-8B (int8) | 39 tok/s | **141 tok/s (3.6×)** |
| Qwen3.6-35B | 30.9 tok/s | **64.9 tok/s (2.1×)** |

Qwen3.6's 64.9 is nearly the same number as MLX. The MoE that was the lone loss in the Chapter 2 table is back to even.

Let me stress that this is not an approximation or a corner-cutting speedup. The weights that went unread were weights whose results would have been thrown away anyway. In fact, the custom-kernel version's output is **bit-for-bit identical** to the read-everything version's — an answer not one bit different, delivered 3.6 times faster. That is what cutting over-read means.

At the same time, let me note that it stops at even. MLX was built to choose-then-read from the start; we merely caught up. A kernel can only win back what was being squandered — it cannot rise above the division from Chapter 1.

This chapter's story has a sequel. Remember the first line of Chapter 1? "A 2026 iPhone can run an 8-billion-parameter language model" — the identity of that model is this LFM2.5-8B.

The int8 version that hit 141 tok/s on the Mac weighs 8.8GB. That will not fit on an iPhone, because there is a hard cap on the memory an iPhone app can use (the full shape of that law comes in Chapter 11). So we return to the tools of Chapter 4. Crush it down to 4-bit (the lookup-table scheme) and the bundle is 4.7GB. That, the iPhone accepts.

LFM2.5-8B with the custom kernel and 4-bit combined ran on an iPhone 17 Pro at 32 tokens per second. As far as I know, it is **the first record of an MoE running on a physical iPhone**.

An honest footnote. This model has no QAT version yet. Which means, as Chapter 4 showed, this 4-bit compromises on quality. There is still distance between "it runs" and "the quality is perfect too," and the key to closing it is for the makers to release a QAT version (as we saw in Chapter 4, that is the only way to use 4-bit unscathed).

Even so: an 8-billion MoE runs in a pocket, and a 35-billion MoE runs even with MLX on a MacBook. Two years ago this was on nobody's schedule. Line up the reasons and they are this chapter. The MoE design that decouples reading from intelligence. The conversion hole that read everything. The small kernel that chooses before it reads. The quantization that cuts weights to a quarter. **Every one of them was a story about how not to read.**

The story of weights you don't need to read ends here. Next is the story of a **past** you don't need to read.

An LLM gets slower as the conversation gets longer. If you've used one, you know this in your bones. The single token at position 1000 is noticeably heavier than the single token at position 10. Why? Because weights are not the only thing the model reads every token. Absent any cleverness, the model **re-reads the entire conversation so far, every token**.
