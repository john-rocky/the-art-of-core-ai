# Epilogue — How Many Bytes Did You Move?

We have reached the end, so it is time to bring out the one thread this book has been hiding all along.

**The fate of on-device AI is decided not by how fast you compute, but by how many bytes you move.**

Everything we did in each chapter was a variation on that one sentence. Generation speed was a division by the bytes you read (Chapter 1). The engine's job was to erase the gaps between reads (Chapter 2). The ANE misunderstanding was born from looking at compute power while forgetting to count the bytes (Chapter 3). Quantization cut the bytes in half (Chapter 4), kernels skipped the bytes that never needed reading (Chapter 5), state was a way of arranging past bytes (Chapter 6), and speculation was reusing bytes you had already read once (Chapter 7). The compute-dominated world (Chapters 8 and 9) was the world of "work dense in compute per byte moved," watts (Chapter 10) were the electricity bill for the bytes you moved, and jetsam (Chapter 11) was the gallows for the bytes you dirtied. The same seat as first-party (Chapter 12) and off the rails (Chapter 13) were about whose hands this byte craft ends up in.

So when you see news of a new model or a new chip, ask this first. **"Does it reduce the bytes you move? Does it move them faster? Does it make the compute per byte denser?"** If it is none of these three, generation will not get faster. If you take home this one question, this book has done its job.

This book is a living book. Draft-model speculation (Chapter 7), diffusion LLM caching (Chapter 9) — wherever it says "in progress," real measurements will be added as each one is settled. In fact, the conclusion of Chapter 4 was once killed by a measurement and rewritten while the first draft was still being written. That is how this book was written. If you find a number that is wrong, please let me know. Every number can be measured again — that is this book's only boast.

The iPhone of 2026 can run an 8-billion-parameter language model.

Behind that one line sat all of this. The giant in your pocket does not stand on the march of chips. **It stands on the gigabytes that were never read.**
