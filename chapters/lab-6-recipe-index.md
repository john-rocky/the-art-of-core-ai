# Lab 6 — Recipe Index

The final Lab is an index. It gathers the techniques you read as stories in Parts II–IV into entry points for "reproducing this with your own model." Each Recipe runs in the order **When → the gist of the steps → the most important traps**. The full versions (code, all traps, measurement logs) live in the zoo repository's `knowledge/`, and each Recipe ends with a pointer to its file.

## Recipe 1: MoE kernel replacement (Chapter 5)

**When**: a MoE (expert-selection) model is 2–5x slower than expected. First confirm "reading everything" with the Lab 5 sanity check.

**The gist**: replace the stock component (compute all experts, then select) with a custom kernel that reads only the selected experts' weights (the `gather_qmm` approach), across all MoE layers. The zoo implementation swaps every MoE layer in the model with a single function. The output should **match bit-for-bit** with the pre-swap output — if it does not, the kernel has a bug.

**Traps**: choose the experts' weight-quantization scheme **based on how many experts are selected**. Models that select 4 or more per token come through unscathed with linear symmetric 8-bit. **Models that select only 1–2 collapse with linear 8-bit, and recover with the lookup-table approach (k-means)** — with so few experts, per-expert error passes straight through instead of averaging out. And judge a scheme's quality **only via a real export + engine execution** (a quick PyTorch run cannot be trusted). → `knowledge/compute-units-and-authoring.md`

## Recipe 2: Wiring models without a KV cache (Chapter 6)

**When**: running RWKV or Mamba-family models (fixed-size-state models).

**The gist**: the state-update math lowers to standard operations, so **no kernel is needed**. The problem is the execution side: the pipelined engine assumes "a KV cache exists" and cannot be used. Write a small custom runner that binds states **by name** (generalizing Apple's SequentialEngine to N states).

**Traps**: when quantizing, **protect the projections involved in the state update, keeping them at 8-bit even so** (recurrence accumulates error). Verify teacher-forced (Lab 3). → `knowledge/rwkv7-recurrent-linear-attention-coreai.md`

## Recipe 3: The diffusion-LLM host loop (Chapter 9)

**When**: running an LLM that does not generate one token at a time (masked-diffusion type).

**The gist**: the graph is a single function, "whole frame → logits for every cell" (no KV, bidirectional). Write the generation loop on the host side: unmask the confident cells (lowest entropy) first, and loop until the frame fills. Cut the frame into blocks of 32 cells and limit parallelization to within a block. Keep the unmasking threshold in `metadata.json` so it can be tuned without reconverting.

**Traps**: **do not judge quality by token match rate** (Chapter 9: a correct answer can still be phrased differently). Judge by the text of the answer. → `knowledge/diffusion-llms-dllm.md`

## Recipe 4: Putting it on the ANE (Chapters 3 and 10)

**When**: you want fixed-shape encoders resident at low power. Not for LLM decode (Chapter 3).

**The gist**: the ANE has its own dialect. Shapes fully fixed. Matrix multiplies as 1×1 `Conv2d`, not `nn.Linear` (it accumulates in fp32 for you). Attention one head at a time. Numerics fp16 only — write a single fp32 constant like `1.0` in the code and you get evicted from the ANE. Weight quantization **must be the lookup-table approach (palettization)** (linear 4-bit takes down the ANE's compiler itself).

**Traps**: do not use `-inf` in masks (**use -40000**; the ANE's softmax cannot handle -inf correctly). RMSNorm overflows in fp16, so use the equivalent transformation of concatenating `[x, -x]` and passing it through LayerNorm (the hardware accumulates LayerNorm in fp32). Verify **on real data, always** — a quick check with constant inputs lies and says "it matches." → `knowledge/compute-units-and-authoring.md`

## Recipe 5: A Foundation Models provider (Chapter 12)

**When**: seating your own model in the `LanguageModelSession` chair.

**The gist**: the basic form is one line, `CoreAILanguageModel(resourcesAt:)`. If you also want tools (tool calling), conform to the protocol yourself and the full round trip — call → execution → response — goes through (verified on device).

**Traps**: structured generation (`@Generable`) **does not work** with pipelined-engine bundles (the engine does not expose logits). Switching a session's model pays a **re-prefill of the entire conversation**. Some prewarm-style APIs have no effect. → `knowledge/fm-provider.md`

## Recipe 6: The agent safety check (Chapter 13)

**When**: before shipping an app that gives the model tools (search, mail, files).

**The gist**: the principle is **never combine the lethal trifecta** — do not grant "access to secrets," "outbound communication," and "untrusted input" at the same time (Chapter 13). Implementation weapons: inspect before execution with the tool-call hook (`.onToolCall`), mark text of external origin with the history transform (`.historyTransform`), and layer the OS confirmation dialog and authentication policy on destructive operations.

**Traps**: even if "our app only summarizes," the summarization **target** (mail, the web) is untrusted input. Letting the model read it = an injection path. → `knowledge/agentic-security-checklist.md`

## Recipe 7: Pre-ship evaluation (continued from Lab 3)

**When**: beyond numerical agreement (Lab 3), you want to check on every ship that "the model's behavior has not degraded."

**The gist**: with Apple's Evaluations framework, turn the responses to a fixed input set into scored regression tests. This book's addition: put adversarial inputs (including Recipe 6's injection strings) into the evaluation set, and also test **that the model does not give responses it must never give**.

**Traps**: if the evaluation set contains only "inputs that go well," degradation is always discovered in production. → `knowledge/evaluations-framework.md`

---

That is the end of the Labs. Having read the "why" in the main chapters and the "how" in the Labs, all that remains is to pick one model of your own and push it through. When you get stuck, ask the numbers — in the end, that is the one tool this book can hand you.
