# Chapter 8 — The Silent Seconds

Paste in a long document, hit send, and the model first goes silent. What it does during this silence is **prefill** — reading the entire prompt and building Chapter 6's KV cache (the matching material for the past).

The difference from decode is in the shape of the work. Decode was "read all the weights, compute one token's worth." Prefill is "read all the weights, compute **1000 tokens' worth at once**." The amount read is about the same; only the computation is 1000× larger.

Recall the division from Chapter 1. Decode became a reading contest because the computation was too light next to the reads. In prefill, this flips. With 1000 tokens' worth of computation hanging off each read, the read time thins out and disappears, and **compute speed becomes speed, directly**.

In other words, even with the same model, the silence and the generation are ruled by different laws.

| | Ruled by | What works |
|---|---|---|
| prefill (the silence after send) | Compute power | Make the computation faster |
| decode (character-by-character generation) | Memory bandwidth | Read less |

The tools of the previous four chapters — quantization, picking experts, state, speculation — all belong to the bottom row of this table. They do almost nothing for prefill. There, the reads were never the bottleneck to begin with. To shorten the silence, you have to make the computation itself faster.

And this table is the key to reading the change Apple has been making to its chips since 2025.

In Apple's chips from 2025 on — the iPhone's A19 Pro, the Mac's M5 — one thing changed inside the GPU. Each GPU core gained a circuit dedicated to matrix computation (a **neural accelerator**). The announcement's words: "several times the AI performance."

Where those "several times" land, the table above answers directly. What a matrix engine speeds up is computation. So it helps **the top row of the table** — prefill, and the encoders and diffusion models in the chapters ahead. What it doesn't help is the bottom row — decode. Multiply the chip's compute power however many times: if the memory bandwidth stays the same, token-by-token generation gets not one token faster. Compute power isn't in Chapter 1's division.

"AI is several times faster on the new chip," says the marketing. "Chat generation speed barely changed," says your own experience. This is why neither is a lie. What gets faster is the silence, not the generation.

The OS also provides the software-side gateway. **TensorOps** — a set of instructions for calling, directly from a GPU program, this matrix engine and matrix computation that consumes quantized weights as read, without restoring them. OS 26 added 8-bit and 4-bit integers; OS 27 added FP4 and FP8.

The division of roles gets one step clearer here. Hand-written GPU programs like Chapter 5's custom kernel were tools for cutting wasted reads. TensorOps is a tool for making computation faster, and it is the only gateway to the dedicated circuit that hand-written programs can't reach. Both are "writing kernels" — but they aim at different enemies.

A word on Chapter 4's FP4. The TensorOps FP4 instructions technically opened the road to "compute on FP4 weights as read" — but as written in the latter half of Chapter 4, in the quality verification FP4 finished in a **dead heat** (a no-op) with lookup-table int4, closing the hope of "4-bit without waiting for QAT." The FP4 instructions' real stage is not decode (a bandwidth contest — faster instructions don't reduce the reads) but the compute-bound batched processing of the chapters ahead: diffusion models and encoders.

One more honest note. Our attempts to make this matrix engine pay off for prefill have not yet won in measurements on the A19 device at hand (M5 unverified). What reliably benefits today is the batched computation of diffusion and encoders. The direction the chip is designed toward, and what software can extract from it today, deserve to be written down as separate things.

Finally, a guide to the rest of this part.

Prefill is not the only place where "computation rules." There are generative models for whom **the compute world is home turf** in the first place.

For example — an LLM that doesn't write one token at a time. It writes the whole text at once first, then finishes that error-riddled text by rewriting it over and over. Each rewrite covers all tokens simultaneously, so the shape of the work is close to prefill. A contest of computation, not reads. It was never bound by Chapter 1's division to begin with.

Does such an LLM really exist? It does. On a Mac first, not an iPhone — but it ran. The next chapter starts there.
