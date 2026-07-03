# Lab 1 — Your First Conversion

Take a single minimal model all the way through **conversion → save → run on the Core AI runtime → verification against PyTorch**. This one script contains every element of the real-world pipeline. The script and output below were verified by actually running them.

```python
# lab1_convert_and_verify.py - smallest end-to-end Core AI conversion
import asyncio, shutil
from pathlib import Path
import numpy as np
import torch
from coreai_torch import TorchConverter, get_decomp_table
import coreai.runtime as rt

class Tiny(torch.nn.Module):
    def __init__(self):
        super().__init__()
        self.fc1 = torch.nn.Linear(64, 256)
        self.fc2 = torch.nn.Linear(256, 10)
    def forward(self, x):
        return self.fc2(torch.nn.functional.silu(self.fc1(x)))

OUT = Path("tiny.aimodel")

async def main():
    torch.manual_seed(0)
    m = Tiny().eval()          # eval mode: freezes dropout/batchnorm for inference
    x = torch.randn(1, 64)     # example input: fixes the graph's shapes and dtypes

    # -- 1) capture: trace the model into a graph of ATen ops --------------
    # torch.export runs the model once with the example input and records
    # every operation into a static graph (an ExportedProgram).
    ep = torch.export.export(m, args=(x,))

    # -- 2) decompose: rewrite the graph into the converter's vocabulary ---
    # High-level ATen ops are broken down into simpler ones the converter
    # knows how to lower. get_decomp_table() is Apple's curated list: the
    # default decompositions MINUS ops Core AI lowers directly (SDPA, silu,
    # ...) - those must stay whole to get their fast fused implementations.
    ep = ep.run_decompositions(get_decomp_table())

    # -- 3) convert: ATen graph -> Core AI IR -------------------------------
    # Unsupported ops fail HERE (validate time), not later at runtime.
    prog = (TorchConverter()
            .add_exported_program(exported_program=ep,
                                  input_names=["x"], output_names=["logits"])
            .to_coreai())
    prog.optimize()            # graph-level optimization passes (fusion etc.)

    # -- 4) save: write the .aimodel bundle (a directory) -------------------
    shutil.rmtree(OUT, ignore_errors=True)   # save_asset never overwrites
    prog.save_asset(OUT, rt.AIModelAssetMetadata())

    # -- 5) run on the Core AI runtime (Mac) ---------------------------------
    # cpu_only: bit-stable numerics for parity checks.
    # Use SpecializationOptions.default() (GPU/ANE) for any real workload.
    model = await rt.AIModel.load(OUT, rt.SpecializationOptions.cpu_only())
    fn = model.load_function("main")         # sync (load is async, call is async)
    res = await fn({"x": rt.NDArray(x.numpy())})
    got = res["logits"].numpy()              # NDArray -> numpy is .numpy()

    # -- 6) verify against the PyTorch reference ----------------------------
    ref = m(x).detach().numpy()
    cos = float((got * ref).sum() / (np.linalg.norm(got) * np.linalg.norm(ref)))
    print(f"cos={cos:.6f}  argmax_match={bool(got.argmax() == ref.argmax())}")

asyncio.run(main())
```

Result of running it (M4 Max / macOS 27):

```
coreai-torch 0.4.0: converting 1 program(s) to Core AI
cos=1.000000  argmax_match=True
```

How to read the result: **cos** (cosine similarity) measures how well the directions of the two output vectors line up; 1.0 is a perfect match. **argmax** is "the index of the highest-scoring candidate" — in classification and token selection, this is what ultimately gets used, so it stands alongside cos as a practical pass criterion. As for `logits`, the name we gave the output: it is the table of raw scores assigned to each candidate (for an LLM, scores over the entire vocabulary).

## What Is a Computational Graph

Let me first explain the "graph" that appears at every stage of the script. A **computational graph** is a **recipe**: the model's computation written down as nothing but "which operations, in what order, applied to which data." A Python `forward` is a living program that can branch and loop freely every time it runs. A graph, by contrast, has its sequence of operations fixed in advance. Precisely because it is fixed, it can be optimized and compiled ahead of time, and it can run on an iPhone, where Python does not exist. **Conversion is the work of transcribing the program into this recipe**, and the single execution `torch.export` performs (the trace) is "a trial run to record the steps."

> **Column: The graph pendulum.** If you felt here that "this is inconvenient compared to eager PyTorch," that intuition matches the industry's history. TensorFlow 1.x (2015) was a framework that made developers write this computational graph by hand — define the graph first, pour data through it afterward. Its rigidity and painful debugging were disliked, and the leading role was taken by PyTorch, which "runs the moment you write it." But when the time comes to ship a model to a device, every advantage of the graph becomes necessary: ahead-of-time optimization, compilation, execution without Python. So the pendulum swung back. But not all the way. Today's answer is a compromise — "develop in eager, transcribe into a graph exactly once at the shipping boundary" — and `torch.export` is that boundary. The graph's inconvenience has not disappeared, but it has been confined from the entire span of development to a single point at shipping.

## What Is Decomposition

The graph `torch.export` records is written at the granularity of PyTorch's internal operations (**ATen ops**). The ATen vocabulary has hundreds of entries, and the converter does not know all of them. So a **decomposition** step is inserted — rewriting high-level operations into combinations of basic operations the converter does know. For example, `layer_norm` can be expanded into mean, variance, multiply, and add.

However, **decomposing too much is also bad**. If you break the attention mechanism (`scaled_dot_product_attention`) apart into matmuls and softmax, the converter can no longer recognize "this is attention," and you lose Core AI's fast fused implementation.

`get_decomp_table()` is Apple's answer to this tug-of-war. Its contents are "PyTorch's standard decomposition table, **minus the ops Core AI implements directly and fast**" — the ops removed (i.e., kept whole) are these six: SDPA, silu, hardswish, hardsigmoid, instance_norm, and pixel_shuffle (`coreai_torch/_decomp.py`). The `silu` in this Lab's Tiny model is also on the "keep" side. The line between what to decompose and what not to is itself the know-how of Core AI porting; the kernel substitution in Chapter 5 and the extension points in Chapter 13 are about redrawing this line yourself.

## Pass Criteria (If You Fall Below, Do Not Proceed)

**PSNR** is a metric that expresses how close two tensors are in dB (decibels); larger is closer (signal-to-noise ratio). At each stage of conversion, if you fall below the levels in the table, investigate the cause before moving on.

| Comparison | Criterion |
|---|---|
| After re-authoring vs original model (fp16) | PSNR > 70dB (investigate below 60) |
| After conversion vs torch | PSNR 40–50dB or higher, **cos ≈ 1.0 + argmax match** |
| After 4-bit quantization | PSNR ~40dB (investigate below 30) |

## Traps You Will Step On (All Firsthand Experience)

- **The async/sync/async mix**: `AIModel.load` is async, `load_function` is **sync**, and calling the function is async. Your first error is almost always this
- **`save_asset` does not overwrite**: `shutil.rmtree` first
- **Extract from an `NDArray` with `.numpy()`**. `np.asarray()` does not work
- **`AIModel.load(path, None)` dies with `MPSGraph Unresolved symbol`** — always pass an explicit `SpecializationOptions`
- **Numerical verification uses `cpu_only()`; real workloads use `default()`** (automatic GPU/ANE; on one model, 24.2 seconds → 2.6 seconds, 9.3×). Carrying cpu_only into your app is the cause of "mysteriously slow"
- **Keep holding a reference to the `AIModel` itself**. If you hold only the return value of `load_function` and let the model itself get GC'd, it **returns garbage without crashing** (the worst way to break — it looks like a conversion bug)
- **Unsupported ops surface at conversion time (`add_exported_program`)**, not at runtime. Complex-number ops (`torch.polar`, etc.) are not supported — rewrite RoPE as real-valued cos/sin arithmetic
