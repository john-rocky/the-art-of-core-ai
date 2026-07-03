# Chapter 1 — It Wasn't Compute That Caught Up

The 2026 iPhone can run an 8-billion-parameter language model. It also runs a model that composes 11 seconds' worth of music in 0.9 seconds. Not long ago, both were datacenter jobs.

Did the chip catch up with the datacenter in a few years? No. The compute of the iPhone's GPU still doesn't come anywhere near a server GPU's. What caught up wasn't compute.

LLM generation was never a compute problem in the first place.

An LLM produces text one token at a time. And for every token it makes, it reads the model's weights from memory — all of them, start to finish. With an 8GB model, that's 8GB per token. The computation itself takes far less time than this reading. What sets generation speed isn't the chip's compute but how fast it reads from memory — **memory bandwidth**.

Put numbers on it. The M4 Max, a Mac chip, can read 546GB per second from memory. With an 8GB model, it can finish that read only 68 times per second. So on this Mac, an 8GB model will never go faster than 68 tokens per second. **As long as you read all the weights for every token**, no implementation, however clever, can beat this division.

That leaves only two roads to faster: read faster, or read less. Read speed — memory bandwidth — is a hardware spec, and software can't change it. So everything software can do comes down to how not to read.

Compress the weights to half the bits and you read half as much; the ceiling doubles (Chapter 4). If the model's architecture uses only part of its weights per token, read only what it uses (Chapter 5). And there's a move that targets that "as long as" above: since you've read them anyway, make not one token but several (Chapter 7).

But the division gives you the ceiling, not a promise you'll reach it. In fact, the first Core AI I measured was far below the ceiling.

In 2026, a tool arrived for fighting this how-not-to-read battle on Apple devices. **Core AI** — Apple's machine learning framework, successor to the Core ML line that ran from 2017. Convert a model built in PyTorch to Apple's format once, and from then on the OS takes over deciding whether it runs on the CPU, the GPU, or the ANE (Apple's dedicated machine learning processor — the protagonist of Chapter 3).

This book is the record of shipping thirty-odd models to iPhone and Mac with that Core AI. Every number is measured on real hardware, with the device and conditions stated. The reason is simple: in this field, plausible guesses get betrayed by real measurements, every single time.

Let's start with the first failure. Soon after I started using Core AI, I compared its speed against MLX — the de facto standard for running LLMs on a Mac. Total defeat. Half the speed. I broke down the factors and wrote it all into a report, right down to the conclusion: "this gap is structural, and it will not close." The numbers were measured on real hardware. The conclusion was still wrong.

What was wrong wasn't Core AI, and it wasn't the measured numbers. **It was how I was using it.** And worse: it was the way everyone writes it the first time.
