# Lab 2 — Driving It from Swift

Drive the `tiny.aimodel` you built in Lab 1 (and any single-`main` bundle) from Swift. The code consists of device-verified patterns excerpted from shipped apps and tools (the engines in `coreai-models/swift`, the zoo's verification tools).

**First, distinguish the API layers.** What the OS's `CoreAI` framework provides is the low-level layer — `AIModel` (initialized from a URL), `InferenceFunction` (an executable computational graph), `NDArray` (input/output data), and `MutableView` (non-escaping, safe buffer access). This is the layer WWDC 324 explains. In contrast, the `PreparedModel` and `fillNDArray`/`flattenAsFloat` appearing in the code below are **helpers on the side of Apple's `coreai-models` package**, not OS APIs. Keep this distinction in mind when you consult the official documentation.

**Setup**: depend on the `coreai-models/swift` package via SwiftPM. If you don't need the heavy LLM libraries, depending on the `CoreAISegmentation` (or `CoreAIObjectDetection`) product pulls in only the foundational `CoreAIShared` + `CoreAI` frameworks. A CLI running on Mac **requires macOS 27** (the package declares `.macOS("27.0")`). Building the iOS app itself works with Xcode 27 on macOS 26.4+. Before writing code, **open the `.aimodel` in Xcode** to check the function signatures (input/output names, shapes, dtypes; dynamic dimensions show as `?`) — it's faster to squash input-name typos before you start writing.

## Pattern 1: Running a Single-main Bundle

```swift
import CoreAI
import CoreAIShared

// Load: PreparedModel probes the bundle structure and picks sane options
// (a single dynamic `main` -> GPU + expectFrequentReshapes).
let pm = try await PreparedModel.prepare(at: url)

// Load the function ONCE and hold the handle (see traps).
guard let fn = try pm.model.loadFunction(named: "main") else { fatalError("no main") }

// Build inputs: the descriptor gives you shapes/dtypes; helpers fill/cast.
let desc = pm.model.functionDescriptor(for: "main")!
guard case .ndArray(let d) = desc.inputDescriptor(of: "x") else { fatalError() }
var x = NDArray(descriptor: d)
fillNDArray(&x, as: Float16.self, with: inputFloats)  // fp16 bundle -> Float16, NOT Float

// Run and read.
var out = try await fn.run(inputs: ["x": x])
let logits = out.remove("logits")?.ndArray            // Outputs is NOT a Dictionary
let values = flattenAsFloat(logits!)                  // fp16 -> [Float]
```

## Pattern 2: Driving an LLM (with State)

Apple's `CoreAISequentialEngine` is the prototype (2 states). Your own runner generalizes it to support N states.

```swift
// States are passed as mutable views and MUTATED IN PLACE across calls:
// reuse the same buffers and the KV cache persists between steps.
var states = InferenceFunction.MutableViews()
states.insert(&keyCache, for: "keyCache")
states.insert(&valueCache, for: "valueCache")
var outputs = InferenceFunction.MutableViews()
outputs.insert(&logits, for: "logits")
_ = try await fn.run(inputs: ["input_ids": ids, "position_ids": positions],
                     states: consume states, outputViews: consume outputs)
```

- **One dynamic graph covers both prefill and decode**: prefill = all tokens + zero state; decode = one new token + the carried-over state. For `position_ids`, pass the full length `[0..<total)` every time
- logits are usually fp16 (`Float16`), and some bundles emit only the final token (`[1,1,vocab]`)

## Traps (All Firsthand Experience)

- **Opening a single-main bundle with a raw `AIModel(contentsOf:)` + default settings sends it to the ANE and dies** (`Program load failure (0x10004)`). `PreparedModel.prepare(at:)` inspects the structure and picks the right destination (GPU + `expectFrequentReshapes`) for you
- **Call `loadFunction` exactly once and keep holding the handle.** If you call it again every step, decode from the second call onward starts **returning zeros with no error**
- **Pass `Float16` to an fp16 bundle.** Passing a `Float` NDArray gives `CoreAIError 3`
- **The return value of `fn.run` (`Outputs`) is not a Dictionary.** Extract with `out.remove(name)?.ndArray` (there is no `removeValue(forKey:)`)
- **Swift 6 strict concurrency will complain**: `InferenceFunction`/`NDArray` are non-Sendable. If you call them from a `@MainActor` engine, wrap them in a `struct Wrapper: @unchecked Sendable` and call serially (on the premise of one inference at a time)

## Checkpoint

The logits of `tiny.aimodel` must match the Python run from Lab 1. If they match here, you have verified "the conversion on the Python side" and "the driving on the Swift side" independently, and in later debugging you can isolate the culprit.
