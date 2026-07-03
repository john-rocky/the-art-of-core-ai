# Chapter 4 — Sixteen Levels

Cutting the weights in half is easy to say. But what gets halved, and how?

A model's weights are normally stored as 16-bit floating-point numbers (fp16), one per weight. Eight billion parameters means 16GB. Replace each with an 8-bit integer and you get 8GB; with 4 bits, 4GB. Plug that into the division from Chapter 1 and the ceiling doubles, then quadruples. This is **quantization**.

There are essentially only two ways to do the replacement. Fix evenly spaced levels and round each weight to the nearest one (**linear quantization**). Or collect the common values into a table of representatives, and have each weight store only its index into the table (**the lookup-table scheme** — the format the ANE was using in Chapter 3). Either way, you are settling for a nearby value. The question is where the cost of settling shows up.

For 8-bit, here is the answer up front: it barely shows up at all. With Core AI's standard 8-bit quantization, comparing a 41-token generation against the original fp16 model, the difference was a single token — and even that was a swap within fp16's own margin of error. Half the reading, quality effectively unchanged. This is why on-device LLM weights are 8-bit by default.

So what about 4-bit? Half the reading again, four times the ceiling. MLX's default was, in fact, 4-bit (this is why, in the Chapter 2 table, MLX closed in more the bigger the model got). Just do the same thing in Core AI.

I did. The words broke.

The breakage had a signature.

The "one token" at 8-bit was a swap between equally ranked candidates. The 4-bit swaps were different. In the same 41-token comparison, there were 12 swaps. And they were not close calls. The model picked words the original would never pick, confidently and by wide margins. Even the words that hold the grammar together — particles, punctuation — got swapped. The output text hadn't wavered; **it had become the text of a different model**.

The mechanism goes like this. 8-bit has 256 levels. 4-bit has only 16. Most weights cluster near zero, and a handful of outliers set the spacing of the levels. With only 16 levels, the moment you stretch the spacing to fit the outliers, the vast majority of small weights get crammed into a few levels, and their fine differences vanish. Per layer the distortion is tiny, but by the time it has passed through dozens of layers and reached the probabilities of the final token choice, the rankings have flipped.

I tried the usual escape routes. Protect only the most fragile layers (the input side of the MLP) at 8-bit. Drop linear for the lookup-table scheme. Get clever about how the levels are assigned. Each one made the breakage slightly less bad, and none brought back a model that speaks the same words as fp16.

Only one way back is known: **a model retrained from the start on the assumption that it will live in 4-bit** — QAT (Quantization-Aware Training). If the weights grow up fitted to 16 levels from the training stage, the words don't break at 4-bit. But that is work only the model's makers can do, and the published QAT versions can be counted on one hand. For those of us converting models, 4-bit tolerance was something a model either was born with or wasn't — not something conversion tricks could grant.

That was the received wisdom through the first half of 2026. **8-bit is the floor. 4-bit falls through, unless it's QAT.**

That wisdom gets shaken by a single measurement — and then, where it lands, flipped over once more. This section tells the story in the order it happened.

There is a 4-bit that isn't integer. Floating-point 4-bit — **FP4**. Instead of placing the 16 levels at uniform spacing, it places them densely near zero and sparsely farther out. It's the same "floating-point" idea as fp16, done with just 16 levels.

On a smallish model (LFM2.5-1.2B), I compared evenly spaced int4 against FP4.

| Quantization | Quality degradation (perplexity increase) |
|---|---:|
| int4 (evenly spaced) | +10.2% |
| **FP4** | **+1.0%** |

One tenth the degradation — on par with 8-bit. And here is the strange part: measure the approximation error over the weights as a whole, and FP4's is **larger**. The only reading is that what matters is not the total amount of error but where the error lands. The vast majority of weights are packed near zero, and evenly spaced levels crush that dense zone into a handful of levels. FP4 concentrates its levels near zero, so the fine detail of the dense zone survives.

When the measurements had gotten this far, I wrote this chapter's conclusion as follows: "'4-bit falls through' was never a property of 4-bit. **It was a property of uniform spacing.**" It was a clean conclusion.

**That conclusion died while the first draft of this book was being written.**

It happened during re-verification on the 35B flagship. The 4-bit actually in use at that scale is not evenly spaced. It is the **lookup-table scheme** from Chapter 3 — the placement of the 16 representative values is chosen to fit the weight distribution, so "dense near zero" was already achieved. If uniform spacing were the culprit, this scheme should be innocent. Yet its quality was still collapsing. So I threw FP4 at it.

| Word-choice swaps (35B flagship, out of 512 tokens) | |
|---|---:|
| int8 (lookup table) | 32 |
| int4 (lookup table) | **104** |
| **FP4** | **104** |

**Exactly the same.** Drop uniform spacing, fit the level placement to the distribution, go floating-point — 16 levels are 16 levels. FP4's win at 1.2B had been a match of "FP4 versus a bad int4 (evenly spaced)"; against a good int4 (lookup table), the difference vanished. **The true identity of the 4-bit cliff was not how the levels are arranged, but the capacity of 16 itself.**

As a bonus, one more lesson about metrics tumbled out. A variant of FP4 that carries its scales differently had **smaller** weight approximation error, yet **more** swaps (117). A moment ago it was "larger error, better quality"; now it is "smaller error, worse quality." **Weight approximation error predicts quality in neither direction.** Don't trust proxy metrics; measure the final output — a lesson we will meet again, in a different form, in Chapter 9.

And so the conclusion comes back to where it started. **8-bit is the floor. The only way to use 4-bit unscathed is QAT.** The weights have to be raised, from the start, to live in a world with only 16 levels. Conversion-side tricks — dropping uniform spacing, learning the levels, going floating-point — shift the cliff's position a few steps, but they don't fill it in.

The practical answer is clear. **Default to 8-bit. If the model has a QAT version, 4-bit.** Between the two, the reading shrinks to roughly one half down to one quarter.

That's it for doubling the ceiling. Next comes tripling it, even quintupling it — though unlike quantization it isn't universal; it works only on models with one particular structure. That structure is called MoE. In the comparison table in Chapter 2, one row looked off. We return to gpt-oss-20B, the one where Core AI lost by 28%.

Trace the cause of that loss, and you find Core AI reading, every token, all of the weights it had no need to read. In one model, **32 times** the necessary amount.
