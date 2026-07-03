# Lab 3 — Porting an LLM

Run an ordinary dense LLM from Hugging Face on Core AI. The measured finish line is Qwen3.5-0.8B (int8): **210 tokens per second** versus the naive loop's 58.5 (M4 Max; the 204 in Chapter 2 is the same-conditions number from before LM head quantization), and **about 70 tokens** on iPhone 17 Pro. This Lab is the implementation companion to Chapter 2 and Chapter 6.

## A. Export — Housing Prefill and Decode in One Graph

An LLM's computational graph (= a fixed recipe of operations; Lab 1) has two jobs: **prefill**, which processes the prompt in one batch, and **decode**, which generates one token at a time (Chapter 8). The standard Core AI move is to cover both with **one dynamic graph** (a graph whose input length is variable). The steps:

**1. Make a home for the KV cache.** The KV cache = the storage for past tokens' matching material (Chapter 6). On the PyTorch side you declare it with `register_buffer` — the standard mechanism for creating "a tensor that is not trained but is saved and moved together with the model," also used in the WWDC 324 demo. Then, inside forward, you **partially write** the material for this call's tokens into the corresponding positions in the cache (an operation that rewrites only part of a tensor; the `slice_update` family). This "declaration + partial write" becomes, after conversion, the state — a region the graph reads and writes on its own.

**2. Decide the input shapes.** The graph has two inputs: `input_ids` = the token sequence being processed this call (length S), and `position_ids` = the running index over the whole conversation. For prefill, S = the prompt length and the running indices go from 0 to S-1; for decode, S = 1 and you pass **all** the running indices from 0 up to the current position. "Length of the running indices − length of this call" is the length of the past already in the cache.

**3. Trace with a "past exists" shape.** As seen in Lab 1, `torch.export` runs the example input once and records the steps (trace). When it does, **always record with an example where "length of the running indices > length of this call"** (e.g., S=4 with 8 running indices). If you record with an example where both have the same length, export assumes "these two dimensions are always the same length," and with S=1 and only the running indices long, **the decode shape will no longer go through**.

**4. Call `remove_functionalization(ep)`.** When recording, `torch.export` converts "rewrite a tensor" operations into a "create a new, already-rewritten tensor" form (an internal process called functionalization). Since the essence of state is "rewrite in place," undo this process with `remove_functionalization` before conversion. **Forgetting it produces no error.** The writes just silently vanish, and it surfaces later in this form: the first token is correct, and things break from the second token on.

**5. At conversion time, pass the state names with `state_names=[...]`.**

## B. Conditions for Riding the Pipelined Engine

To run the converted bundle on Apple's fast execution stack (`coreai-pipelined`, from Chapter 2), the bundle must have a specific structure.

- **One `main` graph: `input_ids [1,S] → logits`.** logits = the table of scores assigned to every candidate in the vocabulary, and generation means "picking the next word from this table." Put both the embedding (the lookup table from token index to vector) and the lm_head (the transform from final vector to logits) **inside the graph**. The engine only feeds token indices in and receives the selected index back; there is no opening to insert host-side processing in between
- **A growing KV pair `keyCache`/`valueCache`** (all layers stacked into one tensor, with the length dimension dynamic)
- **Export with dynamic shapes.** A fixed-length chunk format gets routed to a different execution stack (the static engine for the ANE)
- **Make it a LanguageBundle-format directory.** Besides the `.aimodel`, the engine needs a tokenizer (the conversion table between strings and token indices) and a config (`metadata.json`: model type, vocabulary size, maximum context length, etc.). **A bare `.aimodel` alone will not load**
- States other than KV (like the fixed states of the hybrid SSM in Chapter 6) will not ride on an unmodified engine (it **hard-codes exactly 2 KV states**). With the engine patch the zoo distributes, up to 2 additional fixed-shape states can be carried

## C. Oracle Verification — Checking Against the Reference

The correctness of a port is judged by matching against an **oracle** (= the reference). The reference is the Hugging Face model run as-is in plain PyTorch (called eager execution).

- Feed a fixed prompt to both and confirm **cos ≈ 1.0 + next-token argmax match** (the highest-scoring candidate is the same). Even if the intermediate numbers diverge substantially, first suspect fp16 rounding noise — **judge pass/fail by argmax**
- Verify multiple tokens **teacher-forced**. If you let both generate freely and compare, the moment one position diverges, the entire rest of the text changes and comparison breaks down. So force-feed the sequence the reference generated at every step, and compare only "the prediction of the next single token" at each step (it's like having the student copy the answer sheet while grading only their judgment along the way)
- **Re-verify after any OS or toolchain update.** The runtime is coupled to the OS (Lab 0)

**The relationship to the official verification tools.** Each piece exists officially. The converter has `verify()` (automatic matching of the conversion result against torch), but it forces graph optimization internally and **effectively hangs on large models** (measured on the order of 90 minutes) — this is why this book teaches manual `run()` comparison. For finding the cause when verification fails, there is **Core AI Debugger** (an official app; peek at intermediate tensor values and trace each operation back to the Python line that produced it). For measuring speed, the official CLI's `llm-benchmark` (Lab 5). For evaluating the model's **behavior** — safety and regressions — Apple's **Evaluations framework** (Lab 6). The division of labor: **numerical match = this section's manual gate, cause-finding = Debugger, speed = llm-benchmark, behavior = Evaluations**.

## Traps (All Firsthand Experience)

- **Do not call `engine.warmup()` on an S=1 bundle.** Warmup = a dummy run before the real thing to get compilation out of the way, but this function tries to warm up at length 256, so it crashes on a graph fixed at S=1. Generate one token after loading, and that serves as the warmup
- **Set the chunk-threshold environment variable (`COREAI_CHUNK_THRESHOLD=1`) before creating the engine.** Changing it afterward is never read
- **Do not benchmark on a Debug build.** Unoptimized Swift host-side processing dominates and you get numbers **about 3× slower** (the Swift version of Chapter 2's "what did you measure on")
- **Bundles of 2GB class and above require the `increased-memory-limit` entitlement on iPhone.** An entitlement = Apple's mechanism for granting an app special permission; this one raises the memory ceiling. Without it, the first on-device compilation (cold specialization, Chapter 11) crashes with `std::bad_alloc`
- **A failed first compilation leaves a half-written cache on the device.** From then on, loading that model keeps failing with a "file not found" error, and it eats disk too (about 3.5GB for a 2B). Recovery is deleting the cache from inside the app
- Rough first-compilation times (iPhone, GPU path without AOT): about 5 seconds for 0.8B, about 29 seconds for 2.3GB. From the second time on, the cache kicks in: 0.2–6 seconds
