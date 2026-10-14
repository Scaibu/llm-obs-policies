# Part 3: Attention, transformers and decoding (#101–150)

Same format and the same contract (roles; rules NR1–NR8; guardrails NX1–NX5).

## C1. Attention and training objectives

### 101. Scaled dot-product attention

**Definition:** Each position builds its output as a weighted mix of all positions' values, with weights from how well its query matches their keys.

**Cost:** O(n² × d) time and O(n²) memory for the score matrix (reduced by #116).

### 102. Multi-head attention

**Definition:** Running several attention operations in parallel on lower-dimensional projections, then combining them, so different heads can track different relationships.

**Cost:** About the same as single-head attention of full width.

### 103. Causal language modeling (next-token prediction)

**Definition:** Training a model to predict each token from the tokens before it, using a causal mask.

**Cost:** One forward and backward over the sequence per training example.

### 104. Masked language modeling (MLM)

**Definition:** Training a bidirectional encoder by hiding some input tokens and predicting them from both sides of context.

**Cost:** One forward and backward per sequence. Only selected positions give loss (ELECTRA uses all).

### 105. Span corruption (denoising objectives, T5)

**Definition:** Pretraining an encoder-decoder by replacing random spans of text with sentinel tokens and training the decoder to output the missing spans.

**Cost:** Encoder over the full input, decoder over the short targets.

## C2. Position information

### 106. Sinusoidal positional encoding

**Definition:** Adding fixed sine and cosine waves of different frequencies to token embeddings, so the model knows each token's position.

**Cost:** None (precomputable).

### 107. Learned absolute position embeddings

**Definition:** A trainable vector for each position index, added to the token embeddings.

**Cost:** Maximum length × dimension parameters.

### 108. Rotary position embeddings (RoPE)

**Definition:** Encoding positions by rotating query and key vectors by angles proportional to their position, so attention scores depend on relative distance.

**Cost:** Negligible.

### 109. ALiBi (attention with linear biases)

**Definition:** Adding a penalty to attention scores that grows linearly with distance, instead of adding position embeddings.

**Cost:** Negligible.

### 110. Relative position bias (T5 buckets, Transformer-XL)

**Definition:** Learned attention biases that depend on the relative distance between query and key positions.

**Cost:** Small.

### 111. Context window extension (position interpolation, NTK-aware scaling, YaRN)

**Definition:** Methods that let a RoPE-based model handle longer sequences than it was trained on, with little or no fine-tuning.

**Cost:** Fine-tuning on long sequences (quadratic attention cost, #116).

## C3. Transformer architecture and efficiency

### 112. The transformer block

**Definition:** The repeated unit of transformers: attention to mix information across positions, and a feed-forward network to transform each position, each with a residual connection and normalization.

**Cost:** About 12 × L × d² parameters (dense), roughly 2 FLOPs per parameter per token forward, plus attention's n² term.

### 113. Encoder-only, decoder-only and encoder-decoder transformers

**Definition:** The three main transformer layouts, each suited to different tasks.

**Cost:** Depends on layout. Encoders are cheapest for understanding tasks.

### 114. Multi-query and grouped-query attention (MQA, GQA)

**Definition:** Sharing key and value projections across several query heads, to shrink the KV cache and speed up generation.

**Cost:** Fewer K/V parameters, and a smaller KV cache.

### 115. Multi-head latent attention (MLA)

**Definition:** Compressing keys and values into a small shared latent vector per token, caching only that latent, and reconstructing keys and values from it.

**Cost:** KV cache far smaller than standard multi-head attention, with quality comparable to or better than GQA.

### 116. FlashAttention (IO-aware tiled attention)

**Definition:** An exact attention algorithm that avoids writing the full n × n score matrix to GPU memory, by computing attention in tiles that fit in fast on-chip memory.

**Cost:** Same FLOPs as standard attention. Much less memory traffic and memory.

### 117. KV cache

**Definition:** Storing the keys and values of already-processed tokens during generation, so each new token only computes its own.

**Cost:** Large memory. Decoding is memory-bandwidth-bound.

### 118. PagedAttention (paged KV cache memory)

**Definition:** Storing the KV cache in fixed-size blocks (pages), like virtual memory, so memory isn't wasted and can be shared between requests.

**Cost:** Small indirection overhead. Much higher achievable batch sizes.

### 119. Sliding window (local) attention

**Definition:** Each token attends only to a fixed number of recent tokens, so cost grows linearly with length.

**Cost:** O(n × w).

### 120. Sparse attention patterns (Longformer, BigBird)

**Definition:** Attention restricted to a structured subset of pairs (local windows plus a few global and random connections), giving linear cost for long documents.

**Cost:** O(n × (w + g + r)).

### 121. Linear attention (kernel feature maps)

**Definition:** Replacing softmax attention with a kernel form that can be computed in linear time, by reordering the multiplications.

**Cost:** Linear in n.

### 122. Structured state space models (S4)

**Definition:** Sequence models based on continuous-time linear state space systems, discretized and computed efficiently as either a long convolution (for training) or a recurrence (for inference).

**Cost:** O(n log n) training (FFT), O(1) per step inference.

### 123. Mamba (selective state space models)

**Definition:** A state space model whose parameters depend on the input, so it can choose what to remember or ignore, computed with a hardware-efficient parallel scan.

**Cost:** Linear in sequence length in training, constant per step at inference.

### 124. RWKV and RetNet (recurrent transformer alternatives)

**Definition:** Architectures that train in parallel like transformers but run as recurrent networks at inference, with constant memory per token.

**Cost:** Constant per step at inference. Parallel training.

## C4. Mixture of experts

### 125. Mixture of experts with top-k gating

**Definition:** Replacing a dense feed-forward layer with many expert networks and a router that sends each token to only a few of them, increasing parameters without proportional compute.

**Cost:** Compute ≈ k experts per token. Memory must hold all experts.

### 126. Load balancing, capacity factors and token dropping

**Definition:** Techniques that keep MoE experts evenly used, because routers naturally collapse onto a few favorite experts.

**Cost:** Small overhead.

### 127. Expert-choice routing

**Definition:** Instead of tokens choosing experts, each expert chooses its top tokens, guaranteeing perfect load balance.

**Cost:** Same compute as top-k routing at equal capacity.

## C5. Vision, multimodal and memory-augmented transformers

### 128. Vision Transformer (ViT)

**Definition:** Applying a standard transformer to images by splitting them into fixed-size patches and treating each patch as a token.

**Cost:** Quadratic in the number of patches.

### 129. Swin Transformer (shifted window attention)

**Definition:** A hierarchical vision transformer computing attention within local windows, shifting the windows between layers so information crosses window borders.

**Cost:** Linear in image size.

### 130. Perceiver (cross-attention to a latent array)

**Definition:** An architecture that handles very large or varied inputs by having a small fixed set of latent vectors attend to the inputs, then processing only the latents.

**Cost:** Linear in input size.

### 131. Cross-attention for conditioning

**Definition:** Attention where queries come from one sequence and keys/values from another, letting a model condition on external information (an encoder output, an image, retrieved text).

**Cost:** O(query length × source length).

### 132. CLIP (contrastive image-text pretraining)

**Definition:** Training an image encoder and a text encoder together so matching image-caption pairs have similar embeddings, enabling zero-shot classification and cross-modal search.

**Cost:** Large-batch training. Inference is two encoder passes.

### 133. Multimodal LLM connectors (projection layers, Q-Former, resamplers)

**Definition:** Modules that turn a vision (or audio) encoder's outputs into tokens a language model can read.

**Cost:** Visual tokens consume LLM context: hundreds to thousands per image.

### 134. Segment-level recurrence (Transformer-XL)

**Definition:** Letting a transformer use cached hidden states from the previous text segment as extra context, extending its memory beyond one segment.

**Cost:** Attention over L + memory length per segment.

### 135. Retrieval-enhanced transformers (RETRO chunked cross-attention)

**Definition:** A model that retrieves similar text chunks from a large database during processing, and attends to them with cross-attention, so knowledge lives partly in the database instead of the weights.

**Cost:** Retrieval per chunk, plus cross-attention.

### 136. Prefix language modeling and mixture of denoisers (UL2)

**Definition:** Training objectives that combine bidirectional understanding of a prefix with causal generation of the rest, and mix several denoising tasks in one model.

**Cost:** Similar to standard pretraining.

### 137. Multi-token prediction

**Definition:** Training a model to predict several future tokens at each position (not just the next one), using extra output heads.

**Cost:** Small extra compute per position, with memory-efficient sequential head computation.

## C6. Scaling and stability

### 138. Scaling laws (compute-optimal training)

**Definition:** Empirical power laws relating model size, data size and compute to loss, used to choose model and dataset sizes for a compute budget.

**Cost:** The cost of the small fitting runs.

### 139. Attention sinks and streaming generation (StreamingLLM)

**Definition:** The observation that models put large attention weight on the first few tokens regardless of content, and the method of keeping those tokens plus a recent window for unlimited-length streaming.

**Cost:** Bounded KV cache.

### 140. Logit stabilization (output z-loss, router z-loss)

**Definition:** Small auxiliary losses that keep logits from growing too large, preventing numerical instability in large-scale training.

**Cost:** Negligible.

## C7. Decoding

### 141. Greedy decoding and temperature sampling

**Definition:** The basic ways of choosing the next token: always the most likely (greedy), or sampling from the probability distribution, sharpened or flattened by a temperature.

**Cost:** O(vocabulary) per step.

### 142. Top-k sampling

**Definition:** Sampling only among the k most likely tokens.

**Cost:** O(vocabulary) per step (partial sort).

### 143. Nucleus (top-p) and min-p sampling

**Definition:** Adaptive truncation: keep the smallest set of tokens whose probabilities sum to p (top-p), or every token at least a fraction of the top token's probability (min-p).

**Cost:** O(vocabulary) per step.

### 144. Repetition, frequency and presence penalties

**Definition:** Adjusting logits of tokens that already appeared, to reduce repetitive output.

**Cost:** O(generated length) bookkeeping.

### 145. Contrastive search and contrastive decoding

**Definition:** Decoding methods that balance likelihood with avoiding degenerate repetition, or that contrast a strong model with a weaker one to favor "expert" predictions.

**Cost:** Extra computation per step (hidden-state similarities or a second model).

### 146. Speculative decoding (draft and verify)

**Definition:** Speeding up generation by having a small fast model propose several tokens, which the large model verifies in one parallel pass, with output identical in distribution to the large model alone.

**Cost:** Draft model compute + one target pass per round. Typical speedups: 2–3×.

### 147. Self-drafting decoding heads (Medusa, EAGLE)

**Definition:** Speculative decoding without a separate draft model: small extra heads on the target model predict several future tokens, verified with tree attention.

**Cost:** Small extra heads. Often 2–3× or more speedup.

### 148. Constrained (grammar-guided) decoding

**Definition:** Forcing generated text to follow a formal structure (JSON schema, regex, grammar) by masking out tokens that would break it at each step.

**Cost:** Precomputation of token masks. Small per-step overhead with good implementations.

### 149. Self-consistency (sample and vote)

**Definition:** Generating several independent answers (with reasoning) and taking the most common final answer.

**Cost:** N× generation cost.

### 150. Lookahead and Jacobi decoding (parallel decoding without a draft model)

**Definition:** Generating several tokens in parallel by iteratively refining guesses for future positions with the model itself, until they stabilize.

**Cost:** Extra parallel computation per step. Speedups depend on the content's predictability.

---
