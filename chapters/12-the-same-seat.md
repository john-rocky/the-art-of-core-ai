# Chapter 12 — The Same Seat as First-Party

iOS app development in 2026 has one new piece of common sense: the **Foundation Models framework** — an API that lets any app call Apple's first-party on-device LLM in 3 lines. Create a session, call `respond(to:)`, and an answer comes back. Streaming is there, and so is structured generation (`@Generable`) — "return JSON of this type." The world's apps are starting to be written against this API.

And here is the big thing Apple did quietly. This `LanguageModelSession` seat is **not reserved for the first-party model**.

`CoreAILanguageModel(resourcesAt:)` — wrap a homegrown `.aimodel` downloaded from the zoo in this one line, and without changing any of the rest of the app's code, **your own model sits in the first-party LLM's seat**. `respond(to:)` and streaming work as-is. Even the oddball from Chapter 6 (the hybrid SSM) was confirmed on a real device to run in this seat.

What does this mean? App developers no longer have to learn each model's dialect. **The model has become a swappable part.** Start building with the first-party model; if the performance or the personality falls short, swap in a zoo model. The reverse is also one line. All the toil of Parts I–III of this book is folded away under this one line.

Not that there are no traps (honestly): a bundle running on the GPU's pipelined engine cannot use structured generation (because the engine does not expose the probability distribution). The seat is the same, but whether every feature of the seat works depends on the model's vehicle.

---

Once seated, the OS's tools become usable. Three examples, all actually run.

**Number 1: Spotlight — a chat that answers about "what is on my iPhone."** Starting with OS 26, Spotlight (on-device search) can be handed to an LLM as a tool. Give it to your own model, and a chat that answers "what was that meeting note I wrote last week?" runs **without uploading a single document anywhere**. The model is on-device; the search is on-device. The design has a privacy twist: the search tool returns only metadata (title and date). When the body is needed, the model explicitly fetches it with a separate tool. The structure was never "search, and the entire contents flow into the LLM" in the first place.

**Number 2: Visual Intelligence — your own model behind the camera.** Behind the iPhone's camera search (the feature that looks up what is on the screen or in the camera), you can plug in your own image model. The surprise is the API design: **the concept of a model appears nowhere in the API**. No special credentials or permissions required. The interface is just "a query comes in, return candidates" — what you answer with is the app's business. The one real gate: **running the model within the background-launch memory budget** — the previous chapter's law kicks in once more here.

**Number 3: the receptionist and the expert.** Within a single conversation, you can switch between two models depending on how heavy the question is (DynamicProfile). A light greeting gets an instant answer from the 0.6B receptionist; when a hard question arrives, the 4B expert takes over — **all on-device, in airplane mode**. In terms of Chapter 1's division, it is a mechanism that changes how much you read per question. There is no reason to read 8GB for an easy question.

---

That completes the set of three things Core AI can do that MLX cannot. Run on iPhone (the previous chapter). Touch the power-sipping unit called the ANE (Chapters 3 and 10). And **melt into the OS** — this chapter. It cannot be measured in a tok/s table, but from the side of the person building the app, this one matters most.

By the way, hasn't a question been forming as you read? If Apple has prepared this much — if there is even a first-party model collection (a zoo) — why did the author port 30 models by hand? Why does this book exist?

The final chapter begins with that answer.
