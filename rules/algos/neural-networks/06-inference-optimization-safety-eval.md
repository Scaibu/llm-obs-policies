# Part 6: Inference optimization, robustness, interpretability, safety and evaluation (#251–300)

Same format and the same contract (roles; rules NR1–NR8; guardrails NX1–NX5). This is the final part.

## F1. Quantization

### 251. Post-training quantization (INT8, per-channel, calibration)

**Definition:** Converting a trained model's weights (and often activations) from floating point to 8-bit integers without retraining, using a small calibration set.

**Cost:** About 2–4× less memory than FP16/FP32, and faster integer arithmetic.

### 252. GPTQ (second-order weight quantization)

**Definition:** Quantizing weights layer by layer to 3–4 bits, adjusting the not-yet-quantized weights to compensate for each rounding error, using second-order information from calibration data.

**Cost:** Minutes to hours for large models, on a single GPU.

### 253. AWQ (activation-aware weight quantization)

**Definition:** 4-bit weight quantization that protects the small fraction of weights connected to large activations, by scaling them before quantization.

**Cost:** Fast (no weight reconstruction like GPTQ).

### 254. SmoothQuant (migrating activation outliers into weights)

**Definition:** Making both weights and activations quantizable to INT8 by moving the difficulty of activation outliers into the weights, through a mathematically equivalent rescaling.

**Cost:** Offline rescaling only.

### 255. Quantization-aware training (QAT)

**Definition:** Training (or fine-tuning) with simulated quantization in the forward pass, so the model learns weights that stay accurate after quantization.

**Cost:** Training or fine-tuning compute.

### 256. KV-cache quantization

**Definition:** Storing the attention key/value cache (#117) in 8-bit or 4-bit precision to fit longer contexts and larger batches.

**Cost:** 2–4× less KV memory, with small dequantization overhead.

### 257. Low-bit number formats (NF4, block floating point, MXFP4, GGUF k-quants)

**Definition:** Specialized 4-bit and mixed formats designed to represent neural network weights accurately with shared scales.

**Cost:** About 4–5 bits per weight including scales.

## F2. Inference optimization and serving

### 258. Kernel fusion and compilation (XLA, TorchInductor, Triton)

**Definition:** Combining sequences of operations into single GPU kernels, and compiling model graphs into optimized code, to cut memory traffic and launch overhead.

**Cost:** Compilation time. Often 1.3–3× faster execution.

### 259. Continuous batching (iteration-level scheduling)

**Definition:** Serving generative models by adding and removing requests from the running batch at every decoding step, instead of waiting for a whole batch to finish.

**Cost:** Scheduling overhead is small. Throughput often several times higher than static batching.

### 260. Prefix caching (radix-tree KV reuse)

**Definition:** Reusing the KV cache of shared prompt prefixes (system prompts, documents, conversation history) across requests, so the shared part isn't recomputed.

**Cost:** Memory for cached prefixes. Large savings in prefill compute and time to first token.

### 261. Chunked prefill and prefill/decode disaggregation

**Definition:** Separating the two phases of LLM inference (compute-heavy prompt processing and memory-heavy token generation) so they don't interfere with each other.

**Cost:** KV transfer bandwidth (for disaggregation).

### 262. Early exit and adaptive computation

**Definition:** Letting easy inputs leave the network early, using intermediate prediction heads, while hard inputs use the full depth.

**Cost:** Saves compute on easy inputs.

### 263. Low-rank weight compression (SVD factorization)

**Definition:** Replacing large weight matrices with products of two thin matrices, found by singular value decomposition.

**Cost:** Parameters and compute drop from d × k to r × (d + k).

### 264. Graph-level model optimization (ONNX, constant folding, layout optimization)

**Definition:** Optimizing the model's computation graph before deployment: removing redundant operations, precomputing constants, and choosing efficient data layouts, often through the ONNX interchange format (a Linux Foundation project).

**Cost:** One-time optimization.

### 265. Model cascades and routing (cheap first, expensive on demand)

**Definition:** Sending each request first to a cheap model, and only escalating to a larger model when the cheap one is uncertain or the request looks hard.

**Cost:** Average cost is close to the cheap model's when most requests are easy.

## F3. Robustness and uncertainty

### 266. Certified robustness (randomized smoothing, interval bound propagation)

**Definition:** Methods that give a provable guarantee that a model's prediction doesn't change for any input perturbation within a given size.

**Cost:** Randomized smoothing needs many noisy samples per prediction. IBP is cheap but loose.

### 267. Out-of-distribution detection (max softmax, energy score, Mahalanobis distance)

**Definition:** Detecting inputs that differ from the training data, where predictions are unreliable.

**Cost:** Cheap at inference (feature extraction plus a score).

### 268. Deep ensembles

**Definition:** Training several networks independently (different random initializations and data orders), and averaging their predictions, which gives better accuracy and more reliable uncertainty.

**Cost:** M× training and inference cost.

### 269. Monte Carlo dropout for uncertainty

**Definition:** Estimating prediction uncertainty by keeping dropout active at inference and running several forward passes.

**Cost:** T× inference.

### 270. Conformal prediction

**Definition:** Turning any model's outputs into prediction sets (or intervals) with a guaranteed coverage rate, such as "the true label is in this set 90% of the time", with no assumptions about the model.

**Cost:** Cheap after calibration.

## F4. Interpretability and explanation

### 271. Integrated gradients and gradient saliency

**Definition:** Attributing a prediction to input features by accumulating gradients along a path from a baseline input to the actual input.

**Cost:** Tens to hundreds of backward passes per explanation.

### 272. Grad-CAM (class activation mapping)

**Definition:** A coarse heatmap showing which regions of an image a CNN used for a given class, using gradients flowing into the last convolutional layer.

**Cost:** One forward and backward pass.

### 273. SHAP (Shapley value attribution)

**Definition:** Attributing a prediction among input features using Shapley values from cooperative game theory: each feature's average marginal contribution across all combinations of features.

**Cost:** From cheap (trees) to expensive (KernelSHAP on large models).

### 274. Attention attribution and attention rollout

**Definition:** Using attention weights to estimate which input tokens influenced an output, with methods that account for multiple layers.

**Cost:** Cheap: attention weights are computed anyway.

### 275. Probing classifiers

**Definition:** Training small classifiers on a model's internal activations to test whether specific information (syntax, entity types, truth values, task state) is represented there.

**Cost:** Cheap.

### 276. Activation patching (causal tracing)

**Definition:** Testing which internal components cause a behavior, by replacing activations from one run with activations from another and measuring the output change.

**Cost:** One forward pass per patched location.

### 277. Sparse autoencoders for interpretable features (dictionary learning)

**Definition:** Decomposing a model's internal activations into a large set of sparse, more interpretable features.

**Cost:** Training on very many activations. Large dictionaries.

### 278. Logit lens and tuned lens

**Definition:** Reading out what a transformer "currently predicts" at intermediate layers, by applying the output head to intermediate hidden states.

**Cost:** Cheap.

### 279. Circuit discovery (automated component tracing)

**Definition:** Identifying the minimal subgraph of model components (attention heads, MLP neurons and their connections) that implements a specific behavior.

**Cost:** Many forward passes (fewer with gradient approximations).

### 280. Activation steering (steering vectors, representation engineering)

**Definition:** Changing a model's behavior at inference by adding a direction vector to its internal activations.

**Cost:** Negligible at inference.

## F5. Model editing, unlearning, privacy and security

### 281. Model editing (ROME, MEMIT)

**Definition:** Changing specific facts stored in a model (for example "the CEO of X is Y") by directly editing a few weights, without retraining.

**Cost:** Seconds to minutes per edit batch.

### 282. Machine unlearning

**Definition:** Removing the influence of specific training data or knowledge from a trained model, ideally as if the data had never been used.

**Cost:** From cheap (approximate) to full retraining (exact).

### 283. Membership inference testing

**Definition:** Testing whether an attacker could tell if a specific example was in a model's training data, as a measure of privacy leakage.

**Cost:** Reference model training (for strong attacks).

### 284. Watermarking generated text

**Definition:** Embedding a statistical signal in generated text that a detector can recognize, without noticeably changing quality.

**Cost:** Negligible.

### 285. Backdoor and data-poisoning detection (spectral signatures, activation clustering)

**Definition:** Detecting training examples that were manipulated to plant hidden triggers or corrupt a model's behavior.

**Cost:** Feature extraction and clustering or SVD per class.

### 286. Guard models (input and output safety classifiers)

**Definition:** Separate classifiers that screen model inputs and outputs for policy violations (harmful content, injection attempts, sensitive data) before they're processed or returned.

**Cost:** An extra small-model call per screened item.

### 287. Automated red-teaming and adversarial evaluation

**Definition:** Systematically searching for inputs that make a model behave badly, using automated generators and human experts, before attackers or users find them.

**Cost:** Generation and evaluation compute, plus expert time.

## F6. Evaluation, tuning and diagnostics

### 288. Perplexity and bits per byte

**Definition:** Measures of how well a language model predicts held-out text: the exponential of the average per-token negative log-likelihood, or that loss normalized per byte.

**Cost:** One forward pass over the evaluation text.

### 289. Benchmark contamination detection

**Definition:** Checking whether evaluation data leaked into training data, which would make benchmark scores misleadingly high.

**Cost:** Large-scale n-gram search over training data (with suffix arrays or Bloom filters).

### 290. Population-based training (PBT)

**Definition:** Tuning hyperparameters during training by running a population of models, periodically copying the best performers and perturbing their hyperparameters.

**Cost:** N parallel runs, but no repeated full training cycles.

### 291. Hyperband and ASHA (early-stopping hyperparameter search)

**Definition:** Hyperparameter search that starts many configurations with small budgets, and repeatedly continues only the best ones with larger budgets.

**Cost:** Much less than full training of every configuration.

### 292. Stochastic weight averaging (SWA)

**Definition:** Averaging model weights from several points late in training (with a constant or cyclic learning rate), which finds flatter solutions and better generalization.

**Cost:** One extra copy of the weights.

### 293. Training dynamics monitoring

**Definition:** Tracking signals during training that reveal problems before they ruin a run: gradient norms, update-to-weight ratios, activation statistics, dead units and throughput.

**Cost:** Small overhead.

### 294. Sanity checks (overfit one batch, initial loss check, gradient flow)

**Definition:** Quick tests before any long training run that catch most implementation bugs.

**Cost:** Minutes.

### 295. Reproducibility and determinism in training

**Definition:** Making training and evaluation results repeatable: same inputs, same results, or at least within a known tolerance.

**Cost:** Some speed loss in deterministic modes.

### 296. Learning curves and data scaling estimation

**Definition:** Measuring how performance changes with the amount of training data, to predict whether more data (or a bigger model) is worth collecting.

**Cost:** Several training runs on subsets.

### 297. Learning with noisy labels (co-teaching, loss correction)

**Definition:** Training methods that limit the damage from incorrectly labeled examples.

**Cost:** Modest overhead (two networks for co-teaching).

### 298. Class imbalance handling (reweighting, resampling, logit adjustment)

**Definition:** Methods that keep models from ignoring rare classes when some classes vastly outnumber others.

**Cost:** Negligible.

### 299. Test-time augmentation and test-time adaptation (TENT)

**Definition:** Improving predictions at inference by averaging over augmented versions of the input (augmentation), or by adapting a few parameters to the incoming test data (adaptation).

**Cost:** Test-time augmentation multiplies inference cost. TENT adds a backward pass on small parameter sets.

### 300. Once-for-all and elastic networks (slimmable models)

**Definition:** Training one network that contains many smaller subnetworks (fewer layers, narrower layers, smaller kernels), so a fitting model can be extracted for each hardware target without retraining.

**Cost:** One expensive training run, then nearly free specialization for many targets.

---
