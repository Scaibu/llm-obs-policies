This is a new reference: **300 neural network algorithms**, with no repeats from the earlier references. Already covered and excluded: tokenization, pooling, contrastive embedding training, hard negative mining, Matryoshka embeddings, cross-encoders, ColBERT, SPLADE, vector quantization (PQ, binary, int8 vectors), KG embeddings (TransE, RotatE and others), every GNN family (GCN through GraphMAE), DeepWalk/node2vec, PCA/UMAP/t-SNE, autoencoders for vector compression, bandits, Bayesian optimization and k-means.

Same format: definition, how it works step by step, cost, and agent use (role, approach, rules, guardrails). No code, in 6 parts of 50.

**Map:**
- **Part 1 (#1–50):** core building blocks, activations, losses, backpropagation, optimizers, schedules, initialization.
- **Part 2 (#51–100):** normalization, regularization, convolutional networks, detection, recurrent networks and sequence models.
- **Part 3 (#101–150):** attention and transformer internals, position encodings, efficient attention, state space models, mixture of experts, vision and multimodal transformers, decoding.
- **Part 4 (#151–200):** generative models (VAEs, GANs, flows, diffusion, flow matching), self-supervised learning, meta-learning, scientific ML, recommendation and time series, reinforcement learning foundations.
- **Part 5 (#201–250):** advanced RL, LLM post-training and alignment, parameter-efficient tuning, model merging, distillation, continual learning, distributed and mixed-precision training, pruning.
- **Part 6 (#251–300):** quantization and inference serving, robustness, uncertainty, interpretability, model editing, safety, evaluation and training diagnostics.

---

# Neural network agent contract (referenced in every entry)

| Role | Job | Can write? |
|---|---|---|
| **Architect** | Chooses and configures model structures | Configs only |
| **Trainer** | Runs training and fine-tuning jobs | Model checkpoints, in staging |
| **Evaluator** | Measures quality, robustness, calibration and safety | No (can block promotion) |
| **Deployer** | Optimizes and serves models | Production, through approved releases |
| **Analyst** | Debugs and interprets models and training runs | No |

**Rules:**
- **NR1. Full lineage:** every model records its code version, config, data snapshot hashes, seeds, hardware and parent checkpoint.
- **NR2. Baselines first:** every new method is compared against a simple, tuned baseline.
- **NR3. Clean evaluation:** held-out data, leakage checks, fixed evaluation sets, and confidence intervals.
- **NR4. Monitor training:** loss, gradient norms, learning rate, throughput and anomalies are tracked live.
- **NR5. Budget first:** estimate compute, memory and cost before launching a job, and refuse runs over budget.
- **NR6. Reproducible:** fixed seeds and recorded nondeterminism. Results that can't be reproduced aren't trusted.
- **NR7. Gated promotion:** no model reaches production without passing quality, safety and regression gates.
- **NR8. Outputs are proposals:** model predictions that affect people or money are decisions for humans or approved policies.

**Guardrails:**
- **NX1. Compute caps:** time, GPU-hour and cost limits per job.
- **NX2. Data governance:** personal data, licenses and consent are checked before training, and training data is documented.
- **NX3. Safety evaluation:** models are tested for harmful outputs, bias and misuse before release.
- **NX4. Instant rollback:** the previous model version stays deployable.
- **NX5. Untrusted inputs:** inputs and retrieved content are data, not instructions to the system.

---

# PART 1: FOUNDATIONS

## A1. Core building blocks

### 1. Perceptron learning rule

**Definition:** The original trainable neuron: a weighted sum followed by a threshold, with a simple rule that updates weights only on mistakes.

**Cost:** O(d) per example.

### 2. Multilayer perceptron (MLP) and universal approximation

**Definition:** Stacked layers of neurons with nonlinear activations between them, able to approximate any continuous function given enough width.

**Cost:** O(Σ layer_in × layer_out) per example, forward and backward.

### 3. Linear (affine) layer and fan-in / fan-out

**Definition:** The fundamental parametric operation: output = W × input + b.

**Cost:** O(batch × in × out) multiply-adds.

### 4. ReLU family (ReLU, Leaky ReLU, PReLU)

**Definition:** Piecewise linear activations: ReLU(x) = max(0, x), and variants that let a small signal through for negative inputs.

**Cost:** O(1) per element.

### 5. Smooth activations (GELU, SiLU/Swish, Mish)

**Definition:** Smooth, non-monotonic activations that weight inputs by how "positive" they are. Standard in transformers.

**Cost:** A few transcendental operations per element (still small next to matrix multiplications).

### 6. Sigmoid and tanh (and saturation)

**Definition:** S-shaped activations: sigmoid maps to (0, 1), tanh maps to (−1, 1).

**Cost:** O(1) per element.

### 7. Softmax with log-sum-exp stability

**Definition:** Turning a vector of scores (logits) into probabilities that sum to 1, computed in a way that avoids numerical overflow.

**Cost:** O(n) per vector.

### 8. Gated linear units (GLU, SwiGLU, GeGLU)

**Definition:** Feed-forward layers where one linear projection is multiplied elementwise by an activated second projection, acting as a learned gate.

**Cost:** Three weight matrices instead of two, at a smaller hidden width.

### 9. Embedding lookup layers (categorical inputs, sparse gradients)

**Definition:** A trainable table that maps each discrete ID (token, user, product, category) to a learned vector.

**Cost:** O(dimension) per lookup. Memory O(vocabulary × dimension).

### 10. Residual connections

**Definition:** Adding a layer's input to its output (x + F(x)), so the network only learns changes and gradients flow directly through many layers.

**Cost:** One addition per element.

### 11. Dense and highway connections

**Definition:** Alternatives to residual addition: concatenating all earlier layers' outputs (DenseNet) or gating the skip path (highway networks).

**Cost:** DenseNet memory grows with the concatenated feature maps (mitigated by recomputation, #27).

### 12. Weight tying (shared input and output embeddings)

**Definition:** Using the same matrix for the input token embeddings and the output projection to vocabulary logits.

**Cost:** Saves vocabulary × dimension parameters.

## A2. Loss functions

### 13. Regression losses (MSE, L1, Huber)

**Definition:** Measures of prediction error for continuous targets.

**Cost:** O(n).

### 14. Cross-entropy and negative log-likelihood

**Definition:** The standard classification and language modeling loss: the negative log of the probability assigned to the correct class.

**Cost:** O(classes) per example. Large vocabularies are often handled with fused or chunked kernels to save memory.

### 15. Binary cross-entropy with logits

**Definition:** The loss for yes/no (and multi-label) predictions, computed directly from logits for numerical stability.

**Cost:** O(labels).

### 16. Label smoothing

**Definition:** Training against slightly softened targets (for example 0.9 for the correct class, the remainder spread across others), to prevent overconfidence.

**Cost:** None extra.

### 17. Focal loss

**Definition:** Cross-entropy that down-weights easy, well-classified examples, so training focuses on hard ones.

**Cost:** None extra.

### 18. Triplet and angular-margin metric learning losses

**Definition:** Losses that train an embedding space so same-identity items are close and different items are far, by a margin.

**Cost:** Triplet mining can be expensive. Angular-margin losses cost about the same as a softmax.

### 19. KL divergence loss

**Definition:** A loss measuring how one probability distribution differs from another, used to match a model's output distribution to a target distribution.

**Cost:** O(classes).

### 20. CTC loss (connectionist temporal classification)

**Definition:** A loss for aligning a long input sequence (audio frames, image columns) to a shorter label sequence when the exact alignment is unknown.

**Cost:** O(T × L) per sequence, for T frames and L labels.

### 21. Overlap losses for segmentation (Dice, IoU/Jaccard)

**Definition:** Losses that directly optimize the overlap between predicted and true regions, good for small structures.

**Cost:** O(pixels).

### 22. Multi-task loss weighting (uncertainty weighting, GradNorm)

**Definition:** Balancing several losses trained together, so no single task dominates.

**Cost:** Small overhead (extra gradient norms for GradNorm or PCGrad).

## A3. Backpropagation and automatic differentiation

### 23. Computational graphs and reverse-mode automatic differentiation

**Definition:** Recording the operations of a computation as a graph, then computing gradients of a scalar output with respect to all inputs in one backward pass.

**Cost:** Time about 2–3× forward. Memory for saved activations (#27 reduces it).

### 24. Backpropagation through layers

**Definition:** The chain rule applied layer by layer, to compute every weight's gradient in a neural network.

**Cost:** About one matrix multiplication per layer for each of the two gradients.

### 25. Forward-mode differentiation (Jacobian-vector products)

**Definition:** Computing how outputs change for a given input direction, carried along with the forward pass.

**Cost:** About one forward pass per direction.

### 26. Gradient checking (finite differences)

**Definition:** Verifying analytic gradients by comparing them with numerical estimates from small input perturbations.

**Cost:** Two forward passes per checked parameter.

### 27. Gradient checkpointing (activation recomputation)

**Definition:** Saving memory during training by storing only some activations, and recomputing the others during the backward pass.

**Cost:** About 30% more compute for large memory savings.

### 28. Vanishing and exploding gradients, and gradient clipping

**Definition:** The problem of gradients shrinking to nothing or growing without bound through many layers, and the standard fix for the explosion side.

**Cost:** One norm computation per step.

### 29. Straight-through estimator (STE)

**Definition:** A trick for training through non-differentiable operations (rounding, thresholding, sampling discrete values): use the real operation forward, and pretend it's the identity (or a smooth surrogate) backward.

**Cost:** None extra.

### 30. Reparameterization trick and Gumbel-softmax

**Definition:** Ways to backpropagate through random sampling, by expressing samples as a deterministic function of parameters plus independent noise.

**Cost:** None extra beyond sampling.

## A4. Optimizers

### 31. Stochastic gradient descent (SGD)

**Definition:** Updating weights in the direction opposite to the gradient of the loss on a small random batch.

**Cost:** One forward and backward per step. No extra memory.

### 32. Momentum and Nesterov momentum

**Definition:** Accumulating a running average of past gradients, to accelerate along consistent directions and dampen oscillation.

**Cost:** One extra buffer the size of the parameters.

### 33. AdaGrad

**Definition:** Per-parameter learning rates scaled by the inverse square root of the accumulated squared gradients.

**Cost:** One extra buffer.

### 34. RMSProp

**Definition:** AdaGrad with an exponential moving average of squared gradients instead of a sum, so learning rates don't decay to zero.

**Cost:** One extra buffer.

### 35. Adam

**Definition:** Combining momentum (first moment) with RMSProp-style scaling (second moment), with bias correction for early steps.

**Cost:** Two extra buffers: optimizer state is 2× the parameters (in FP32 for mixed-precision training).

### 36. AdamW (decoupled weight decay)

**Definition:** Adam with weight decay applied directly to the weights, instead of being added to the gradient, which makes regularization work as intended.

**Cost:** Same as Adam.

### 37. LARS and LAMB (layer-wise adaptive rates for large batches)

**Definition:** Optimizers that scale each layer's update by the ratio of the layer's weight norm to its update norm, enabling very large batch sizes.

**Cost:** One norm per layer per step.

### 38. Adafactor (factored second moments)

**Definition:** An Adam-like optimizer that stores the second-moment statistics of each weight matrix as row and column averages, cutting optimizer memory drastically.

**Cost:** O(m + n) memory per matrix instead of O(m × n).

### 39. Lion and sign-based optimizers

**Definition:** Optimizers that use only the sign of a momentum-based update, so every parameter moves by the same magnitude.

**Cost:** One state buffer.

### 40. Second-order preconditioning (Shampoo, K-FAC)

**Definition:** Optimizers that use curvature information (approximations of the Hessian or Fisher matrix) to precondition gradients, so steps are better scaled across directions.

**Cost:** Extra memory and periodic expensive matrix operations.

### 41. Sharpness-aware minimization (SAM)

**Definition:** An optimizer that seeks flat regions of the loss (where nearby weights also have low loss), which tends to generalize better.

**Cost:** Two forward and backward passes per step (2× compute).

### 42. Lookahead and weight averaging (EMA / Polyak averaging)

**Definition:** Keeping a smoothed version of the weights, either by periodically pulling "slow" weights toward "fast" ones (Lookahead) or with an exponential moving average.

**Cost:** One extra copy of the weights.

## A5. Schedules and initialization

### 43. Learning rate warmup

**Definition:** Starting training with a small learning rate and increasing it gradually over the first steps.

**Cost:** None.

### 44. Cosine decay and warm restarts

**Definition:** Lowering the learning rate along a half cosine curve, optionally restarting it periodically.

**Cost:** None.

### 45. Warmup-stable-decay (WSD), linear decay and one-cycle schedules

**Definition:** Schedules that keep the learning rate high for most of training and decay it at the end, or (one-cycle) ramp up then down within one run.

**Cost:** None.

### 46. Batch size and learning rate scaling rules

**Definition:** Rules for adjusting the learning rate when changing the batch size, so training behaves similarly.

**Cost:** None, or one short calibration run.

### 47. Xavier (Glorot) initialization

**Definition:** Setting initial weights with variance 2 / (fan_in + fan_out), so signal variance stays roughly constant forward and backward for tanh or sigmoid networks.

**Cost:** None.

### 48. He (Kaiming) initialization

**Definition:** Initial weights with variance 2 / fan_in, compensating for ReLU zeroing half the activations.

**Cost:** None.

### 49. Initialization for deep residual networks (scaled residual init, Fixup, zero-init)

**Definition:** Initialization rules that keep very deep residual networks stable by making each residual branch start small.

**Cost:** None.

### 50. Maximal update parametrization (μP) and hyperparameter transfer

**Definition:** A way of scaling initialization and per-layer learning rates with model width, so the best hyperparameters found on a small model transfer directly to a large one.

**Cost:** None at runtime. Saves most of the hyperparameter tuning cost at scale.

---
