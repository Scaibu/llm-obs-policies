# Part 2: Normalization, regularization, convolutional networks, detection and recurrent models (#51–100)

Same format and the same contract (roles; rules NR1–NR8; guardrails NX1–NX5).

## B1. Normalization

### 51. Batch normalization

**Definition:** Normalizing each feature (channel) to zero mean and unit variance over the current mini-batch, then applying a learned scale and shift.

**Cost:** O(elements). Needs synchronization across devices for "sync BatchNorm".

### 52. Layer normalization

**Definition:** Normalizing across the features of each individual example, independent of the batch.

**Cost:** O(features) per example.

### 53. RMSNorm

**Definition:** A simplified layer normalization that only rescales by the root mean square, without centering (no mean subtraction, no bias).

**Cost:** Cheaper than LayerNorm.

### 54. Group normalization and instance normalization

**Definition:** Normalizing over groups of channels (GroupNorm) or each channel separately (InstanceNorm), per example, so results don't depend on the batch size.

**Cost:** O(elements).

### 55. Weight normalization and spectral normalization

**Definition:** Normalizing the weights themselves rather than the activations: separating direction from magnitude (weight norm), or limiting the largest singular value (spectral norm).

**Cost:** One power iteration per layer per step for spectral normalization.

### 56. Normalization placement (pre-norm, post-norm, sandwich, DeepNorm)

**Definition:** Where normalization sits relative to residual connections in a transformer block, which strongly affects training stability.

**Cost:** None, or one extra normalization.

### 57. QK-norm and logit soft-capping

**Definition:** Stabilization techniques for large transformers: normalizing attention queries and keys, and smoothly limiting the size of logits.

**Cost:** Negligible.

## B2. Regularization and augmentation

### 58. Dropout

**Definition:** Randomly zeroing a fraction of activations during training, so the network can't rely on any single unit.

**Cost:** Negligible.

### 59. Stochastic depth (DropPath)

**Definition:** Randomly skipping entire residual blocks during training, so each block's output is sometimes replaced by its input.

**Cost:** Saves some compute in training.

### 60. Early stopping and checkpoint selection

**Definition:** Stopping training (or choosing the checkpoint) when validation performance stops improving.

**Cost:** The cost of validation runs.

### 61. Image data augmentation (geometric, photometric, RandAugment)

**Definition:** Creating varied training examples by transforming images in ways that don't change their label.

**Cost:** CPU or GPU time in the data pipeline.

### 62. Mixup and CutMix

**Definition:** Training on blends of two examples (and their labels): a pixel-wise blend (Mixup) or a pasted patch from one image into another (CutMix).

**Cost:** Negligible.

### 63. Adversarial training (FGSM, PGD)

**Definition:** Training on inputs deliberately perturbed to fool the model, to make it robust against small adversarial changes.

**Cost:** Several extra forward and backward passes per step (about 3–10× training cost).

### 64. Consistency regularization and pseudo-labeling (FixMatch)

**Definition:** Semi-supervised learning: train the model to give the same prediction on differently augmented versions of unlabeled data, using its own confident predictions as targets.

**Cost:** Extra forward passes on unlabeled data.

### 65. SpecAugment (audio augmentation)

**Definition:** Augmenting speech data directly on its spectrogram by masking blocks of time steps and frequency bands.

**Cost:** Negligible.

### 66. Text augmentation (back-translation, token-level noise)

**Definition:** Creating varied text training examples while preserving meaning.

**Cost:** Back-translation needs model inference. Token operations are cheap.

## B3. Convolutional networks

### 67. Convolution operation (kernels, stride, padding, channels)

**Definition:** Sliding small learned filters over an input grid (image, audio, sequence), computing weighted sums at each position.

**Cost:** O(H × W × k² × C_in × C_out) per layer.

### 68. Fast convolution algorithms (im2col + GEMM, Winograd, FFT)

**Definition:** Implementation methods that make convolutions fast on real hardware.

**Cost:** Depends on the algorithm. Auto-tuning picks the fastest per shape.

### 69. Pooling (max, average, global)

**Definition:** Downsampling feature maps by summarizing small regions.

**Cost:** O(elements).

### 70. Dilated (atrous) convolution

**Definition:** Convolution with gaps between kernel elements, which enlarges the receptive field without more parameters or lower resolution.

**Cost:** Same as a normal convolution with the same kernel size.

### 71. Depthwise separable convolution

**Definition:** Splitting a standard convolution into a per-channel spatial convolution followed by a 1×1 convolution that mixes channels, cutting compute dramatically.

**Cost:** O(H × W × C_in × (k² + C_out)).

### 72. Transposed convolution and learned upsampling (pixel shuffle)

**Definition:** Increasing spatial resolution with learned layers, used in decoders and generators.

**Cost:** Similar to the corresponding convolution.

### 73. 1×1 convolutions and bottleneck blocks

**Definition:** Convolutions with 1×1 kernels that mix channels at each position, used to shrink and expand channel counts cheaply.

**Cost:** O(H × W × C_in × C_out).

### 74. Residual network (ResNet) blocks

**Definition:** The CNN architecture built from residual blocks, which made very deep networks trainable.

**Cost:** ResNet-50: about 4 GFLOPs per 224×224 image.

### 75. Inception (multi-branch) modules

**Definition:** Blocks that run several convolution sizes in parallel and concatenate their outputs, capturing features at several scales.

**Cost:** Controlled by the bottleneck widths.

### 76. Inverted residuals with linear bottlenecks (MobileNetV2)

**Definition:** An efficient block that expands channels, applies a depthwise convolution, then projects back down, with the residual connection between the narrow layers.

**Cost:** Very low compute per block.

### 77. Squeeze-and-excitation and channel/spatial attention modules (SE, CBAM)

**Definition:** Small modules that learn to reweight channels (and, in CBAM, spatial positions) according to global context.

**Cost:** A small number of extra parameters and operations.

### 78. Compound model scaling (EfficientNet)

**Definition:** Scaling a network's depth, width and input resolution together, in fixed proportions, for the best accuracy per unit of compute.

**Cost:** Grows about 2^φ.

### 79. U-Net (encoder-decoder with skip connections)

**Definition:** An architecture that downsamples to capture context, then upsamples to full resolution, with skip connections that pass fine details from encoder to decoder.

**Cost:** Moderate. Memory use is high at full resolution.

### 80. Feature pyramid networks (FPN)

**Definition:** Combining feature maps from several network depths into a pyramid where every level has both strong semantics and appropriate resolution.

**Cost:** Moderate overhead on top of the backbone.

### 81. ConvNeXt (modernized CNN design)

**Definition:** A pure convolutional network redesigned with transformer-era choices, matching vision transformers on many benchmarks.

**Cost:** Similar to vision transformers of comparable size.

### 82. Deformable convolution

**Definition:** Convolution where each sampling position gets a learned offset, so the kernel adapts its shape to the content.

**Cost:** More expensive than standard convolution, because of irregular memory access.

### 83. Receptive field analysis

**Definition:** Computing which input region each output unit can see, which determines what context a CNN can actually use.

**Cost:** Cheap to compute.

## B4. Object detection

### 84. Region proposal networks and two-stage detection (Faster R-CNN)

**Definition:** Detection in two stages: first propose likely object regions with a small network, then classify and refine each proposal.

**Cost:** Slower than single-stage detectors, often more accurate.

### 85. Single-stage detectors (YOLO, SSD, RetinaNet)

**Definition:** Detection in one pass: predict classes and boxes directly from feature maps at every location, without a separate proposal stage.

**Cost:** Real-time inference on GPUs and many edge devices.

### 86. Non-maximum suppression (NMS) and Soft-NMS

**Definition:** Removing duplicate detections of the same object by keeping the highest-scoring box and suppressing overlapping ones.

**Cost:** O(n²) worst case per class, fast in practice.

### 87. DETR (detection as set prediction with bipartite matching)

**Definition:** A transformer-based detector that predicts a fixed set of objects directly, matched one-to-one with the ground truth, removing anchors and NMS.

**Cost:** Transformer cost on image features. Original DETR trains slowly.

### 88. RoIAlign and instance segmentation (Mask R-CNN)

**Definition:** Extracting fixed-size features for arbitrary boxes with exact bilinear sampling, and adding a mask branch for per-object segmentation.

**Cost:** Moderate overhead on top of two-stage detection.

### 89. Anchor-free detectors (FCOS, CenterNet)

**Definition:** Detectors that predict objects directly from points (pixel locations or object centers) without predefined anchor boxes.

**Cost:** Similar to single-stage detectors.

## B5. Recurrent networks and sequence models

### 90. Recurrent neural networks and backpropagation through time (BPTT)

**Definition:** Networks that process sequences step by step, keeping a hidden state that carries information forward, trained by unrolling the steps.

**Cost:** O(T × hidden²) per sequence. Steps are sequential (hard to parallelize).

### 91. Truncated BPTT

**Definition:** Training recurrent networks on long sequences by backpropagating only through a limited window of recent steps, while still carrying the hidden state forward.

**Cost:** O(k) memory per update.

### 92. LSTM (long short-term memory)

**Definition:** A recurrent unit with a separate memory cell and gates that control what to forget, what to add and what to output, allowing long-range dependencies.

**Cost:** About 4× a vanilla RNN per step.

### 93. GRU (gated recurrent unit)

**Definition:** A simplified gated recurrent unit with two gates and no separate cell state.

**Cost:** About 3× a vanilla RNN per step.

### 94. Bidirectional RNNs

**Definition:** Two recurrent networks, one reading the sequence forward and one backward, with their states combined at each position.

**Cost:** 2× a single RNN.

### 95. Sequence-to-sequence encoder-decoder

**Definition:** An architecture mapping an input sequence to an output sequence of different length: an encoder reads the input, and a decoder generates the output step by step.

**Cost:** Encoder pass + sequential decoder steps.

### 96. Additive and multiplicative attention (Bahdanau, Luong)

**Definition:** Letting the decoder look back at all encoder states at each step, weighting them by relevance, instead of compressing the input into one vector.

**Cost:** O(input length) per decoder step.

### 97. Teacher forcing and scheduled sampling

**Definition:** Training sequence generators by feeding the true previous token as input (teacher forcing), optionally mixing in the model's own predictions (scheduled sampling).

**Cost:** Teacher forcing is cheap and parallel. Scheduled sampling needs sequential sampling for the sampled steps.

### 98. Beam search with length normalization

**Definition:** Approximate search for the most likely output sequence, keeping the B best partial sequences at each step.

**Cost:** O(B × vocabulary) per step.

### 99. Pointer networks and copy mechanisms

**Definition:** Decoders that can output positions in the input (pointing) or copy input tokens directly, instead of only generating from a fixed vocabulary.

**Cost:** Small overhead on attention-based decoders.

### 100. Temporal convolutional networks (WaveNet-style dilated causal convolutions)

**Definition:** Sequence models built from causal convolutions (using only past inputs) with exponentially increasing dilation, giving long memory with parallel training.

**Cost:** O(T × layers × kernel × channels²), parallel in training.

---
