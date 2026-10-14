# Part 5: Advanced RL, LLM post-training, efficient tuning, distributed training and compression (#201–250)

Same format and the same contract (roles; rules NR1–NR8; guardrails NX1–NX5).

## E1. Advanced reinforcement learning

### 201. Soft actor-critic (SAC)

**Definition:** An off-policy actor-critic method for continuous actions that maximizes reward plus policy entropy, giving stable, sample-efficient learning with built-in exploration.

**Cost:** Several networks. Efficient use of environment samples.

### 202. Deterministic policy gradients (DDPG, TD3)

**Definition:** Off-policy actor-critic methods with deterministic policies for continuous actions. TD3 adds fixes for DDPG's overestimation and instability.

**Cost:** Similar to SAC.

### 203. Model-based RL and world models (Dreamer)

**Definition:** Learning a model of the environment's dynamics, then training the policy largely inside that learned model ("in imagination"), which needs far fewer real interactions.

**Cost:** World-model training plus cheap imagined rollouts. Very sample-efficient.

### 204. Monte Carlo tree search with learned networks (AlphaZero, MuZero)

**Definition:** Planning by tree search guided by a neural network that predicts move probabilities and position values, trained from the search's own results (self-play).

**Cost:** Many network evaluations per decision.

### 205. Offline reinforcement learning (CQL, IQL)

**Definition:** Learning policies purely from a fixed dataset of past interactions, without new exploration, while avoiding over-optimistic estimates for actions the data never shows.

**Cost:** Like off-policy RL, without environment cost.

### 206. Imitation learning (behavior cloning, DAgger)

**Definition:** Learning a policy from demonstrations of good behavior instead of from rewards.

**Cost:** Supervised training, plus expert labeling for DAgger.

## E2. LLM post-training and alignment

### 207. Curriculum learning

**Definition:** Ordering training data from easier to harder (or adjusting the mix over time), so the model learns more efficiently.

**Cost:** Scoring examples for difficulty.

### 208. Supervised fine-tuning (SFT) and instruction tuning

**Definition:** Fine-tuning a pretrained language model on example conversations or (instruction, response) pairs, so it follows instructions and uses a consistent format.

**Cost:** Small relative to pretraining.

### 209. Reward modeling (Bradley-Terry preference models)

**Definition:** Training a model to score responses so that preferred responses score higher, from pairwise human (or AI) comparisons.

**Cost:** One forward pass per response.

### 210. RLHF with PPO and a KL penalty

**Definition:** Optimizing a language model's responses against a learned reward model with reinforcement learning, while keeping it close to its starting model.

**Cost:** Expensive: generation, reward scoring, policy and value training, and a reference model, all at once.

### 211. Direct preference optimization (DPO)

**Definition:** Training directly on preference pairs with a simple classification-style loss, without a separate reward model or RL loop.

**Cost:** About 2× SFT cost (reference log-probabilities can be precomputed).

### 212. DPO variants (IPO, KTO, ORPO, SimPO)

**Definition:** Modifications of DPO that address overfitting, unpaired data, the reference model's cost, or length bias.

**Cost:** Similar to or lower than DPO.

### 213. Group relative policy optimization (GRPO)

**Definition:** A PPO-style RL method for LLMs that estimates advantages by comparing several responses to the same prompt, removing the need for a value network.

**Cost:** G generations per prompt. No value model.

### 214. RL with verifiable rewards (RLVR)

**Definition:** Reinforcement learning where rewards come from automatic checks of correctness (tests passing, exact answers matching, formal verification), instead of learned reward models.

**Cost:** Generation + verification (running tests can dominate).

### 215. RL from AI feedback (RLAIF) and constitution-guided critique

**Definition:** Using AI models, guided by written principles, to generate preference labels or critiques, instead of (or alongside) human labels.

**Cost:** Model inference for labeling: cheaper and faster than human labeling at scale.

### 216. Rejection sampling fine-tuning and best-of-n (expert iteration)

**Definition:** Generating many candidate responses, keeping the best by a reward or verifier, and either returning the best (best-of-n) or fine-tuning on the kept ones (iterating).

**Cost:** n× generation per prompt.

### 217. Process reward models (step-level verification)

**Definition:** Reward models that score each intermediate reasoning step, not just the final answer, giving denser and more precise feedback.

**Cost:** Expensive labeling. Inference is one pass per solution.

## E3. Parameter-efficient fine-tuning and model merging

### 218. LoRA (low-rank adaptation)

**Definition:** Fine-tuning by freezing the pretrained weights and learning a small low-rank update for selected weight matrices.

**Cost:** Small trainable parameter count. Little memory beyond the frozen model.

### 219. QLoRA (quantized base with LoRA)

**Definition:** Training LoRA adapters on top of a base model stored in 4-bit, so large models can be fine-tuned on a single GPU.

**Cost:** About 4× less memory for the base model.

### 220. LoRA variants (DoRA, rsLoRA, LoRA+, PiSSA)

**Definition:** Improvements to LoRA's parametrization, initialization or learning rates, to get closer to full fine-tuning quality.

**Cost:** Similar to LoRA.

### 221. Adapter modules (bottleneck adapters)

**Definition:** Small trainable bottleneck networks inserted into each transformer layer, while the pretrained weights stay frozen.

**Cost:** Small parameter counts. Adds a little inference latency (unlike merged LoRA).

### 222. Prefix tuning and prompt tuning (soft prompts)

**Definition:** Adapting a frozen model by learning continuous "virtual tokens" prepended to the input (prompt tuning) or to every layer's keys and values (prefix tuning).

**Cost:** Tiny trainable parameter counts. Uses k extra context positions.

### 223. Minimal-parameter tuning (IA³, BitFit)

**Definition:** Fine-tuning only tiny sets of parameters: learned scaling vectors on activations (IA³), or just the bias terms (BitFit).

**Cost:** Minimal.

### 224. Model merging (task arithmetic, TIES, DARE, SLERP)

**Definition:** Combining several fine-tuned models (from the same base) into one model by operating directly on their weights, without retraining.

**Cost:** Cheap (weight arithmetic, no training).

## E4. Distillation and continual learning

### 225. Knowledge distillation (soft targets)

**Definition:** Training a smaller student model to match a larger teacher's output probabilities, not just the hard labels.

**Cost:** Teacher inference on the training data (can be precomputed).

### 226. Sequence-level and on-policy distillation for language models

**Definition:** Distilling generative models by training on the teacher's generated outputs (sequence-level) or by scoring the student's own generations with the teacher (on-policy).

**Cost:** Teacher inference on generated sequences.

### 227. Elastic weight consolidation (EWC)

**Definition:** Protecting knowledge from earlier tasks during new training by penalizing changes to the weights most important for the old tasks.

**Cost:** One Fisher estimate per task, plus a penalty term.

### 228. Replay and rehearsal against catastrophic forgetting

**Definition:** Mixing a sample of earlier training data (or generated substitutes) into new training, so the model doesn't forget earlier skills.

**Cost:** Buffer storage and extra training compute.

## E5. Training at scale

### 229. Long-context training (progressive sequence lengths)

**Definition:** Training models to use long contexts efficiently, by training mostly on short sequences and extending to long ones in later stages.

**Cost:** The long stage is expensive per token, but short in duration.

### 230. Sequence packing with document masking

**Definition:** Filling each training sequence with several shorter documents back to back, so no compute is wasted on padding, while preventing documents from attending to each other.

**Cost:** Removes padding waste (often a large fraction of compute for short-sequence data).

### 231. Mixed-precision training (FP16 with loss scaling, BF16)

**Definition:** Doing most computation in 16-bit floating point while keeping critical values in 32-bit, for faster training and less memory.

**Cost:** Roughly 2× faster than FP32, with half the activation memory.

### 232. FP8 training

**Definition:** Training with 8-bit floating-point formats for matrix multiplications, using per-tensor or per-block scaling factors, for further speed and memory gains.

**Cost:** Up to about 2× faster matrix multiplications than BF16 on supporting hardware.

### 233. Data parallelism with all-reduce (ring and tree all-reduce)

**Definition:** Replicating the model on every device, giving each device different data, and averaging gradients across devices every step.

**Cost:** Communication proportional to model size per step.

### 234. ZeRO and fully sharded data parallelism (FSDP)

**Definition:** Data parallelism where the optimizer states, gradients and even parameters are split across devices instead of replicated, which makes much larger models trainable.

**Cost:** About 1.5× the communication of plain data parallelism for stage 3, with far less memory.

### 235. Tensor parallelism (Megatron-style)

**Definition:** Splitting individual weight matrices across devices, so each layer's computation is divided among them.

**Cost:** Frequent communication. Best within a node.

### 236. Pipeline parallelism (GPipe, 1F1B, interleaved schedules)

**Definition:** Splitting a model's layers into stages on different devices, and feeding micro-batches through them like an assembly line.

**Cost:** Point-to-point communication between stages only. Bubble overhead.

### 237. Context and sequence parallelism (ring attention)

**Definition:** Splitting a long sequence across devices, and computing exact attention by passing key/value blocks around a ring of devices.

**Cost:** Memory per device grows with the chunk, not the whole sequence.

### 238. Expert parallelism (all-to-all routing)

**Definition:** Placing different MoE experts on different devices, and sending each token to the device holding its chosen experts.

**Cost:** Two all-to-all exchanges per MoE layer, which are often the bottleneck.

### 239. Gradient accumulation

**Definition:** Simulating a larger batch by summing gradients over several smaller micro-batches before each optimizer update.

**Cost:** Same compute as the large batch, but sequential: memory of only one micro-batch.

### 240. Offloading (activations, optimizer states, parameters)

**Definition:** Moving training data that isn't needed right now from GPU memory to CPU memory or NVMe storage, and bringing it back when needed.

**Cost:** PCIe or NVMe bandwidth limits speed. Large memory savings.

### 241. Distributed checkpointing and exact resumption

**Definition:** Saving and restoring the full training state across many devices, so training can resume exactly where it stopped, even on a different number of devices.

**Cost:** I/O time (mostly hidden with asynchronous writes).

### 242. Loss spike detection and recovery

**Definition:** Detecting sudden jumps in training loss (often caused by instability or bad data) and recovering without wasting the run.

**Cost:** Rolled-back steps.

### 243. Data mixture optimization (DoReMi and related methods)

**Definition:** Choosing the proportions of different data sources (web, code, books, domain data) in training, using small proxy models instead of guesswork.

**Cost:** A few small proxy runs.

### 244. Critical batch size and batch size schedules

**Definition:** The batch size beyond which larger batches stop reducing the number of training steps much, estimated from gradient noise, and schedules that grow the batch during training.

**Cost:** Negligible estimation cost.

### 245. Synthetic data generation with filtering (self-instruct, evolution, verification)

**Definition:** Using models to generate training data (instructions, responses, problems with solutions), then filtering it for quality, diversity and correctness.

**Cost:** Generation and filtering compute.

### 246. Federated learning (FedAvg, secure aggregation)

**Definition:** Training a shared model across many devices or organizations without collecting their raw data in one place.

**Cost:** Many communication rounds. Client compute.

### 247. Differentially private training (DP-SGD)

**Definition:** Training with mathematical guarantees that the model reveals little about any single training example, by clipping each example's gradient and adding noise.

**Cost:** Per-example gradients are expensive, and noise lowers accuracy (more data and larger batches help).

## E6. Pruning and sparsity

### 248. Magnitude pruning and the lottery ticket hypothesis

**Definition:** Removing the weights with the smallest magnitudes, and the finding that dense networks contain sparse subnetworks that can train to similar accuracy.

**Cost:** Retraining cycles.

### 249. Structured and one-shot pruning of LLMs (SparseGPT, Wanda, head and channel pruning)

**Definition:** Pruning large language models without full retraining, either by removing whole structures (heads, channels, layers) or with weight-level methods that compensate for removed weights.

**Cost:** Minutes to hours on calibration data.

### 250. Semi-structured 2:4 sparsity

**Definition:** A sparsity pattern where, in every group of 4 consecutive weights, exactly 2 are zero, which modern GPUs accelerate directly.

**Cost:** 50% sparsity, with hardware acceleration.

---
