# Chapter 7 — Grading Guesses

Start with a strange fact. To make an 8GB model produce one token, you read 8GB. Now suppose we hand it a guess — "aren't these the next 8 tokens?" — and ask it only to **grade** them. How many GB does that read?

The answer: the same 8GB.

An LLM can verify all 8 offered tokens in a single computation. It reads the weights once, for that one pass. Which means — if all 8 guesses are right, an 8GB read advances 8 tokens. If all of them miss, 8GB still advances 1 token (verification produces the correct next token as a side effect). **Guessing never loses, and a hit cuts the reads to one eighth.**

This is the skeleton of **speculative decoding**. If it sounds too good to be true, add one important property. Only guesses that pass verification are accepted, so **the output does not differ by a single byte from normal generation**. It just gets faster — no change to intelligence, no change to wording. A lossless speedup.

This is how Chapter 1's condition — "as long as you read all the weights for every token" — breaks. One read was tied to one token only because we didn't know the next token. If we know it — if we can guess it — the tie is gone.

Only one problem remains. Who guesses "the next 8 tokens," and how?

The answer turned out to be almost disappointingly simple. **Search the conversation.**

Think about what chat gets used for. "Quote the third condition in this document." "Fix the bug in this code." "Extract the dates from this article." In jobs like these, most of the words the model is about to write are **already on the screen**. In the document. In the code. In the article.

So the draft is built like this. Take the few tokens currently being written and string-search the whole conversation for them. If the same sequence turns up, copy the 8 tokens that follow it and offer them: "is this what comes next?" No second model, no training. It's plain string matching, so the cost is effectively zero. A hit advances 8 tokens; a miss is the same as generating one token normally. There is no way to lose.

We built this mechanism into the zoo chat app as a "⚡Spec" mode and compared the same questions with it ON and OFF. Measured on a real iPhone, with a 4B model:

| Task | Speedup |
|---|---:|
| Quoting / tracing from a document | **8.0×** |
| Answers grounded in source material (RAG) | **3.5×** |

And as promised, the ON and OFF outputs were **byte-for-byte identical**. The same answer, just 8× faster.

Once you see the trick, you know how to read the multipliers. The real meaning of 8.0× is "most of the output was copied from the source text"; 3.5× means "about half was." The model didn't get faster. We just skipped the reads for the repetition the task already contained.

Then the next experiment is obvious. A bigger model. On an 8B, where each read is heavy, this trick of reusing reads should pay off most. And if it works, it works exactly where the benefit is largest.

So we measured on an 8B.

The result was the opposite.

On the 8B, the drafts are almost never accepted. The measured acceptance rate was essentially zero. The 8 tokens we offered got thrown back, one after another: "wrong." The average speedup that ran above 2× on the 4B all but vanished on the 8B.

We investigated, and the problem was not how the drafts were made. **The model had stopped copying the source text.**

On the same "answer based on this material" task, the 4B reuses the material's phrasing largely as-is. The 8B doesn't. Faithful to the content, it recasts the phrasing in its own words. It summarizes, paraphrases, reorders. In a human, we'd praise this as better reading comprehension. But for a method that drafts by copying from the source text, paraphrasing means total loss. **The model's intelligence had crushed the seed of our guesses.**

"The bigger the model, the heavier each read, the more this should help" — the logic was right. But speed = read savings × hit rate, and we had looked only at the former, never the latter. The hit rate was inversely correlated with intelligence. Once again, measurement broke a plausible-sounding guess.

We are not out of moves. Instead of copying from the source text, there is a method where **a small model writes the draft** (a 4B drafts, the 8B grades). A drafter that can mimic the paraphrasing habits themselves should bring the acceptance rate back. As of this writing, that verification is in progress — when it settles, we'll add it here.

Either way, speculative decoding's place is now clear. It is not a universal speed doubler. It is **a device that folds the repetition inside a task into the reads of a single verification pass**. Quoting, extraction, code fixes, answers grounded in source material. The most common on-device jobs happen to have exactly that shape.

— With that, the "techniques for not reading" are all on the table. Quantization, MoE, state, speculation. These four chapters were all about decode — token-by-token generation.

But the felt time of a chat has one more segment. That **silence** right after you paste in a long document and hit send. The few seconds before the first character appears. What is the model doing in there?

It is doing the one job this book has never once cast in the lead role — **computation**. In the next part, the law changes.
