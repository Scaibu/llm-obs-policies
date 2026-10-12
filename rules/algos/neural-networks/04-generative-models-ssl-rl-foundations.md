# Part 4: Generative models, self-supervised learning, scientific ML, recommendation and RL foundations (#151–200)

Same format and the same contract (roles; rules NR1–NR8; guardrails NX1–NX5).

## D1. Autoencoders, GANs, flows and autoregressive models

### 151. Denoising autoencoder

**Definition:** A network trained to reconstruct clean inputs from corrupted versions, which forces it to learn the structure of the data rather than copy it.

**Cost:** One encoder and decoder pass per example.

### 152. Variational autoencoder (VAE)

**Definition:** A generative model that encodes inputs into a probability distribution over a latent space, samples from it, and decodes, trained by maximizing a lower bound on the data likelihood.

**Cost:** Like an autoencoder.

### 153. Vector-quantized VAE (VQ-VAE)

**Definition:** An autoencoder whose latents are discrete codes from a learned codebook, turning images or audio into token sequences.

**Cost:** Nearest-code search per position.

### 154. Generative adversarial networks (GANs)

**Definition:** Training a generator to produce realistic samples by competing against a discriminator that tries to tell real from generated samples.

**Cost:** Two networks trained together. Sampling is a single fast forward pass.

### 155. Wasserstein GAN with gradient penalty (WGAN-GP)

**Definition:** A GAN that trains a "critic" to estimate the Wasserstein (earth mover's) distance between real and generated distributions, giving smoother, more stable training.

**Cost:** Extra gradient computation for the penalty.

### 156. StyleGAN (mapping network, style modulation)

**Definition:** A GAN generator that maps noise into an intermediate "style" space and injects styles at every resolution, giving high-quality, controllable images.

**Cost:** One forward pass per image.

### 157. Conditional and image-to-image GANs (pix2pix, CycleGAN)

**Definition:** GANs that generate outputs conditioned on an input, with paired training data (pix2pix) or unpaired data using cycle consistency (CycleGAN).

**Cost:** Two (or four) networks trained together.

### 158. Normalizing flows (RealNVP, Glow)

**Definition:** Generative models built from invertible transformations, giving exact likelihoods and exact sampling.

**Cost:** One forward pass for likelihood or sampling. Architectures are constrained by invertibility.

### 159. Autoregressive pixel models (PixelCNN)

**Definition:** Generating images one pixel at a time, each conditioned on all previous pixels, using masked convolutions.

**Cost:** Parallel training, slow sequential sampling.

### 160. Energy-based models and restricted Boltzmann machines (contrastive divergence)

**Definition:** Models that assign an energy (an unnormalized negative log-probability) to each input, trained by lowering energy on data and raising it elsewhere.

**Cost:** MCMC sampling during training.

## D2. Diffusion and flow models

### 161. Denoising diffusion probabilistic models (DDPM)

**Definition:** Generative models that learn to reverse a gradual noising process: start from pure noise and denoise step by step into a sample.

**Cost:** Simple, stable training. Slow sampling with many steps (fixed by #163, #164, #169).

### 162. Score-based generative modeling (score matching, SDEs)

**Definition:** Learning the gradient of the log data density (the "score") at many noise levels, and generating by following it, formalized as stochastic differential equations.

**Cost:** Like diffusion models.

### 163. DDIM (deterministic, fewer-step sampling)

**Definition:** A sampling method for trained diffusion models that skips steps and can be deterministic, giving good samples in far fewer steps.

**Cost:** 20–100 steps instead of 1,000.

### 164. Fast diffusion samplers (DPM-Solver, Euler and Heun methods)

**Definition:** Numerical ODE/SDE solvers specialized for diffusion models, producing good samples in about 10–25 steps.

**Cost:** 10–30 model evaluations per sample.

### 165. Classifier-free guidance (CFG)

**Definition:** Strengthening how closely a conditional generative model follows its condition (such as a text prompt), by extrapolating away from its unconditional prediction.

**Cost:** Two model evaluations per step (batched together).

### 166. Latent diffusion

**Definition:** Running diffusion in the compressed latent space of an autoencoder rather than on pixels, which makes high-resolution generation much cheaper.

**Cost:** Diffusion on much smaller tensors, plus one decoder pass.

### 167. Diffusion transformers (DiT)

**Definition:** Using a transformer instead of a U-Net as the denoising network in diffusion models.

**Cost:** Quadratic in the number of patches.

### 168. Flow matching and rectified flow

**Definition:** Training generative models to learn a velocity field that moves noise samples to data samples along simple (often straight) paths, by direct regression.

**Cost:** Simulation-free training. Fewer sampling steps than standard diffusion.

### 169. Consistency models and few-step distillation

**Definition:** Models that map any point along a diffusion trajectory directly to its clean endpoint, enabling generation in one or a few steps.

**Cost:** 1–4 model evaluations per sample.

### 170. ControlNet and conditioning adapters

**Definition:** Adding new kinds of spatial control (edges, depth, pose, layout, segmentation) to a pretrained diffusion model without retraining it.

**Cost:** Extra encoder compute at sampling. Training is much cheaper than retraining the base model.

### 171. Noise schedules and prediction targets (linear, cosine, v-prediction)

**Definition:** The choice of how quickly noise is added across diffusion steps, and what the network predicts (noise, clean data or "velocity"), which strongly affects quality.

**Cost:** None. These are design choices.

## D3. Self-supervised representation learning

### 172. Non-contrastive self-supervision (BYOL, SimSiam)

**Definition:** Learning representations by making two augmented views of the same input predict each other, without negative examples, using asymmetry to avoid collapse.

**Cost:** Two views per example.

### 173. Redundancy-reduction objectives (Barlow Twins, VICReg)

**Definition:** Self-supervised objectives that make embeddings of two views agree, while keeping the embedding dimensions varied and decorrelated, which prevents collapse without negatives or asymmetry.

**Cost:** O(dimension²) for the correlation matrices.

### 174. Masked autoencoders for vision (MAE)

**Definition:** Self-supervised pretraining of vision transformers by masking most image patches and reconstructing the missing pixels.

**Cost:** Efficient: the encoder sees only 25% of patches.

### 175. Self-distillation without labels (DINO)

**Definition:** Training a student network to match a teacher's outputs on different views of the same image, where the teacher is an EMA of the student. It produces strong features that capture object structure.

**Cost:** Several views per image.

### 176. Joint-embedding predictive architectures (JEPA)

**Definition:** Self-supervised learning that predicts the representations (not pixels) of masked parts of the input from visible parts.

**Cost:** No pixel decoder.

## D4. Few-shot learning, meta-learning and specialized architectures

### 177. Prototypical networks (few-shot classification)

**Definition:** Classifying new examples by comparing their embedding to the average embedding (prototype) of a few labeled examples per class.

**Cost:** One embedding pass per example.

### 178. MAML (model-agnostic meta-learning)

**Definition:** Learning an initialization from which a model can adapt to a new task with a few gradient steps on a few examples.

**Cost:** Expensive (inner loops plus second-order gradients).

### 179. Neural ordinary differential equations (neural ODEs)

**Definition:** Models whose hidden state evolves continuously over time according to a learned derivative function, solved with an ODE solver.

**Cost:** Depends on the number of solver steps.

### 180. Neural radiance fields (NeRF) and implicit neural representations

**Definition:** Representing a 3D scene (or any signal) as a neural network that maps coordinates to values, trained from observations such as images.

**Cost:** Many network queries per ray. Accelerated variants are far faster.

### 181. 3D Gaussian splatting (differentiable rasterization)

**Definition:** Representing a scene as many 3D Gaussian blobs with color and opacity, rendered by fast rasterization and optimized from photos.

**Cost:** Real-time rendering. Training takes minutes to tens of minutes.

### 182. Physics-informed neural networks (PINNs)

**Definition:** Neural networks trained to satisfy known physical laws (differential equations) in addition to fitting observed data.

**Cost:** Many residual evaluations. Training can be slow and sensitive to loss weighting.

### 183. Neural operators (Fourier neural operator)

**Definition:** Networks that learn mappings between functions (for example from a PDE's initial conditions to its solution), working at any resolution.

**Cost:** O(n log n) per layer (FFT).

### 184. Hypernetworks

**Definition:** A network that generates the weights of another network, conditioned on some input (a task, a style, a user).

**Cost:** Hypernetwork pass per condition. Generated weights can be cached.

### 185. Differentiable memory (memory networks, neural Turing machines)

**Definition:** Networks with an external memory they can read from and write to with differentiable (soft) addressing.

**Cost:** O(N) per read or write.

### 186. Differentiable neural architecture search (DARTS)

**Definition:** Searching for a good network architecture by relaxing the choice between operations into a continuous mixture, and learning the mixture weights by gradient descent.

**Cost:** About one to a few GPU-days, far less than reinforcement-learning-based search.

### 187. Spiking neural networks (surrogate gradient training)

**Definition:** Networks of neurons that communicate with discrete spikes over time, which suit event-driven, low-power neuromorphic hardware.

**Cost:** Simulation on GPUs is slow. Efficient on specialized hardware.

### 188. Mixture density networks

**Definition:** Networks that output the parameters of a mixture of distributions (for example several Gaussians), so they can represent multi-modal predictions.

**Cost:** K × output parameters.

## D5. Time series and recommendation

### 189. Deep forecasting with basis expansion (N-BEATS, N-HiTS)

**Definition:** Pure MLP forecasting models built from stacked blocks that each produce part of the forecast and remove what they explained from the input.

**Cost:** Cheap MLP computation.

### 190. Time-series transformers with patching (PatchTST, Temporal Fusion Transformer)

**Definition:** Transformer forecasting models designed around time-series properties: treating segments of the series as tokens, and handling covariates and multiple horizons.

**Cost:** Moderate. Patching keeps attention cheap.

### 191. Feature-interaction recommenders (Wide & Deep, DeepFM, DCN)

**Definition:** Models for click and conversion prediction that combine learned feature interactions with deep networks on sparse categorical inputs.

**Cost:** Embedding lookups plus small dense layers.

### 192. Sequential recommendation (SASRec, BERT4Rec)

**Definition:** Recommending the next item from a user's ordered interaction history, using self-attention.

**Cost:** Attention over the history length.

### 193. Multi-task recommendation (MMoE, PLE)

**Definition:** Predicting several objectives at once (click, conversion, watch time, satisfaction) with shared and task-specific experts.

**Cost:** Shared experts amortize compute.

### 194. Target attention over user behavior (Deep Interest Network)

**Definition:** Representing a user's interests differently for each candidate item, by attending over their past behaviors relative to that item.

**Cost:** Attention over the history per candidate.

### 195. Large embedding-table recommenders (DLRM, hashing tricks)

**Definition:** Recommendation models dominated by huge embedding tables for categorical features, with techniques to keep their memory manageable.

**Cost:** Memory-bound, with heavy all-to-all communication for sharded tables.

## D6. Reinforcement learning foundations

### 196. Deep Q-Networks (DQN)

**Definition:** Learning the value of each action in each state with a neural network, trained from stored experience, for problems with discrete actions.

**Cost:** One forward and backward per mini-batch, plus environment interaction.

### 197. DQN improvements (Double DQN, dueling networks, prioritized replay)

**Definition:** Standard extensions that make value-based deep RL more accurate and data-efficient.

**Cost:** Small overheads.

### 198. Policy gradients (REINFORCE) with baselines

**Definition:** Directly optimizing a stochastic policy by increasing the probability of actions that led to high returns.

**Cost:** High-variance gradients need many samples.

### 199. Actor-critic with generalized advantage estimation (A2C, GAE)

**Definition:** Combining a policy (actor) with a learned value function (critic), where the critic's estimates reduce the variance of policy updates. GAE controls the bias-variance trade-off of advantage estimates.

**Cost:** Two networks (often sharing layers).

### 200. Proximal policy optimization (PPO)

**Definition:** A policy-gradient method that limits how much the policy changes per update, by clipping the probability ratio. It's stable and simple, and widely used.

**Cost:** Several passes over each batch. Needs value-network training.

---
