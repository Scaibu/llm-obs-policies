# Part 3: Classical machine learning (#101–150)

Same format and the same contract (roles; rules T1–T8; guardrails TX1–TX5). Already covered elsewhere and not repeated: k-means (V#39–42), PCA/SVD (V#23–24), Platt and isotonic calibration (V#20, K#144), CRFs (graph #276), Bayesian optimization (G92), bandits (G89), conformal prediction (NN#270), SHAP (NN#273), Mahalanobis OOD scoring (NN#267).

## C1. Linear and generalized linear models

### 101. Ordinary least squares (OLS) regression

**Definition:** Fitting a linear model y ≈ Xβ by minimizing the sum of squared residuals.

**Cost:** O(n × p²) for QR.

### 102. Regularized regression (ridge, lasso, elastic net)

**Definition:** Linear models with penalties on coefficient size, which reduce overfitting and (with lasso) select features.

**Cost:** Fast with coordinate descent, even for many features.

### 103. Logistic regression (IRLS, L-BFGS)

**Definition:** A linear model for binary outcomes, predicting the log-odds as a linear function of features, fitted by maximum likelihood.

**Cost:** Fast. A few seconds to minutes even on large data.

### 104. Generalized linear models (Poisson, Gamma, Tweedie)

**Definition:** Linear models for targets that aren't normally distributed (counts, positive amounts, zero-inflated amounts), using a link function and an appropriate distribution.

**Cost:** Like logistic regression.

### 105. Generalized additive models (GAMs)

**Definition:** Models where the prediction is a sum of smooth, learned functions of individual features (plus selected interactions), keeping interpretability while capturing nonlinear effects.

**Cost:** Moderate.

## C2. Trees and ensembles

### 106. CART decision trees

**Definition:** Recursive partitioning of the feature space by binary splits, chosen greedily to make each resulting group as pure (classification) or homogeneous (regression) as possible.

**Cost:** About O(p × n log n) per level.

### 107. Random forest

**Definition:** An ensemble of decision trees, each trained on a bootstrap sample of the data with random feature subsets at each split, averaged for predictions.

**Cost:** O(B × p_subset × n log n). Trivially parallel.

### 108. Extremely randomized trees (Extra Trees)

**Definition:** A random forest variant where split thresholds are drawn at random instead of optimized, giving more randomness, lower variance and faster training.

**Cost:** Faster than random forests (no threshold search).

### 109. Gradient boosting (Friedman's gradient boosting machine)

**Definition:** Building an ensemble of small trees sequentially, each fitted to the negative gradient (residual errors) of the current model's loss.

**Cost:** O(rounds × tree cost). Sequential across rounds.

### 110. Histogram-based gradient boosting (LightGBM: histograms, GOSS, EFB, leaf-wise growth)

**Definition:** A fast gradient boosting implementation that buckets feature values into histograms and adds sampling and feature-bundling techniques.

**Cost:** Much faster than exact gradient boosting on large data.

### 111. XGBoost (second-order, regularized, sparsity-aware boosting)

**Definition:** A gradient boosting implementation that uses second-order gradient information and explicit regularization on tree structure.

**Cost:** Efficient. Parallel split finding, with GPU support.

### 112. CatBoost (ordered boosting and ordered target statistics)

**Definition:** A gradient boosting implementation designed to handle categorical features well and avoid a subtle form of target leakage.

**Cost:** Moderate. Fast inference.

### 113. Monotonic and interaction constraints for tree ensembles

**Definition:** Constraining boosted models so predictions only go up (or down) with chosen features, or only allow chosen features to interact.

**Cost:** Slight accuracy cost in some cases. Same training speed.

### 114. Early stopping and feature importance (gain, permutation)

**Definition:** Stopping boosting rounds when validation performance stops improving, and measuring which features matter, with methods that don't mislead.

**Cost:** Permutation importance needs one evaluation per feature (or group), repeated for stability.

## C3. Kernel and instance-based methods

### 115. Support vector machines (SMO training)

**Definition:** Classifiers that find the separating boundary with the largest margin to the nearest training points (the support vectors), optionally in a kernel-induced feature space.

**Cost:** Kernel SVMs: between O(n²) and O(n³), so they're limited to moderate n. Linear SVMs scale to large data.

### 116. Kernel methods and random Fourier features

**Definition:** Using kernel functions to work implicitly in high-dimensional feature spaces, and approximating them with explicit random features to scale to large data.

**Cost:** Exact kernels: O(n³). Approximations: linear in n.

### 117. k-nearest neighbors classification and regression

**Definition:** Predicting by looking at the k most similar training examples, and taking their majority label or average value.

**Cost:** No training. Query cost is dominated by the neighbor search.

### 118. Naive Bayes classifiers

**Definition:** Probabilistic classifiers that assume features are independent given the class, which makes them extremely fast and data-efficient.

**Cost:** One pass over the data to train. O(features) per prediction.

## C4. Clustering and mixture models

### 119. DBSCAN (density-based clustering)

**Definition:** Clustering points into dense regions, finding clusters of arbitrary shape and labeling isolated points as noise.

**Cost:** O(n log n) with good indexes, O(n²) worst case.

### 120. HDBSCAN (hierarchical density-based clustering)

**Definition:** A density-based clustering method that builds a hierarchy over all density levels and selects the most stable clusters, handling clusters of different densities without choosing ε.

**Cost:** About O(n log n) with spatial acceleration on moderate dimensions.

### 121. Gaussian mixture models (fitted by EM)

**Definition:** Modeling data as a mixture of several Gaussian distributions, giving soft cluster memberships and a density estimate.

**Cost:** O(n × K × d²) per iteration for full covariances.

### 122. Mean shift clustering

**Definition:** Finding clusters as the peaks (modes) of the data density, by moving each point uphill toward the nearest peak.

**Cost:** O(n²) per iteration naively. Speedups with spatial indexes and binning.

### 123. k-medoids (PAM)

**Definition:** Clustering where each cluster's center must be an actual data point (a medoid), which works with any distance measure and is robust to outliers.

**Cost:** Classic PAM O(k × (n − k)²) per iteration. Faster variants are much cheaper.

## C5. Probabilistic models

### 124. The expectation-maximization (EM) algorithm

**Definition:** A general method for maximum-likelihood fitting of models with hidden variables, alternating between estimating the hidden variables and updating the parameters.

**Cost:** Depends on the model. Each iteration is usually linear in n.

### 125. Hidden Markov model training (forward-backward, Baum-Welch)

**Definition:** Learning the parameters of a hidden Markov model (hidden states, transitions, emissions) from observation sequences, using EM with the forward-backward algorithm.

**Cost:** O(T × S²) per sequence per iteration.

### 126. Latent Dirichlet allocation (LDA topic models)

**Definition:** A probabilistic model of documents as mixtures of topics, where each topic is a distribution over words.

**Cost:** Linear in corpus tokens per iteration.

### 127. Gaussian processes

**Definition:** A Bayesian non-parametric model that defines a distribution over functions, giving predictions with calibrated uncertainty.

**Cost:** Exact O(n³). Sparse approximations O(n × m²).

### 128. Alternating least squares for matrix factorization (implicit feedback)

**Definition:** Factorizing a user × item interaction matrix into low-dimensional user and item vectors, by alternately solving least-squares problems for each side.

**Cost:** O(nnz × f² + (users + items) × f³) per iteration.

### 129. Factorization machines

**Definition:** Models that capture all pairwise feature interactions through factorized (low-rank) interaction weights, working well with sparse data.

**Cost:** Linear in nonzero features.

## C6. Anomaly detection

### 130. Isolation forest

**Definition:** Detecting anomalies by how easily they're isolated by random splits: unusual points get isolated in fewer splits.

**Cost:** Linear in data. Very fast.

### 131. One-class SVM

**Definition:** Learning a boundary around normal data in a kernel feature space, so points outside it are flagged as anomalies.

**Cost:** Kernel SVM costs (#115), so moderate data sizes.

### 132. Robust covariance (minimum covariance determinant)

**Definition:** Estimating the center and covariance of data while ignoring outliers, so outliers can then be detected by their distance.

**Cost:** Moderate, for low to moderate dimensions.

### 133. Seasonal hybrid ESD (S-H-ESD) anomaly detection

**Definition:** Detecting anomalies in seasonal time series by removing seasonality and trend, then applying a robust statistical test for outliers.

**Cost:** Linear per series.

## C7. Time series forecasting

### 134. ARIMA and seasonal ARIMA

**Definition:** Forecasting models combining autoregression (past values), differencing (removing trends) and moving averages (past errors), with seasonal extensions.

**Cost:** Fast per series.

### 135. Exponential smoothing (ETS, Holt-Winters)

**Definition:** Forecasting by exponentially weighted averages of past observations, with separate components for level, trend and seasonality.

**Cost:** Very fast. Scales to millions of series.

### 136. Decomposable forecasting models (Prophet-style)

**Definition:** Forecasting with an additive model of trend, seasonalities and holiday or event effects, fitted as a regression, designed for business series with known calendar effects.

**Cost:** Fast per series.

### 137. Intermittent demand forecasting (Croston, SBA, TSB)

**Definition:** Forecasting series with many zeros and occasional demand (spare parts, rare events), by separately forecasting the size and the frequency of nonzero values.

**Cost:** Very fast.

### 138. Hierarchical forecast reconciliation (MinT)

**Definition:** Making forecasts across a hierarchy (total, per region, per service) add up consistently, while improving accuracy at every level.

**Cost:** One matrix computation per forecast run.

### 139. Time-series cross-validation (rolling origin)

**Definition:** Evaluating forecasting models by repeatedly training on the past and testing on the following period, never on shuffled data.

**Cost:** One model fit per cutoff.

## C8. Model selection, data preparation and ensembles

### 140. Cross-validation (k-fold, stratified, grouped, nested)

**Definition:** Estimating a model's performance on new data by training and testing on different splits of the available data.

**Cost:** k × training cost (k × k_inner for nested).

### 141. Categorical encoding (one-hot, target encoding with smoothing, hashing)

**Definition:** Turning categorical values into numbers models can use, without leaking labels or exploding dimensions.

**Cost:** Cheap.

### 142. Missing value imputation (indicators, iterative imputation / MICE)

**Definition:** Handling missing data by filling it in sensibly and recording where values were missing.

**Cost:** Simple: negligible. MICE: several model fits per round.

### 143. Feature selection (mutual information, recursive elimination, stability selection)

**Definition:** Choosing a smaller set of useful features, to improve generalization, speed and interpretability.

**Cost:** Filters: cheap. Wrappers: many model fits.

### 144. SMOTE (synthetic minority oversampling)

**Definition:** Balancing imbalanced classes by creating synthetic minority examples between existing ones.

**Cost:** Neighbor search on the minority class.

### 145. Stacking and blending ensembles

**Definition:** Combining several different models by training a "meta-model" on their predictions.

**Cost:** The cost of all base models plus the meta-model.

### 146. Bagging (bootstrap aggregating)

**Definition:** Reducing a model's variance by training copies on bootstrap samples of the data and averaging their predictions.

**Cost:** B× training cost, parallel.

### 147. AdaBoost

**Definition:** The original boosting algorithm: train weak models one after another, each focusing on the examples the previous ones got wrong, by reweighting examples.

**Cost:** Sequential, with cheap weak learners.

### 148. Partial dependence, ICE and accumulated local effects (ALE)

**Definition:** Visualizing how a model's prediction changes as one feature changes, on average and for individual examples.

**Cost:** Many predictions per feature.

## C9. Online learning and drift

### 149. Online learning with FTRL-Proximal

**Definition:** Training linear models (especially logistic regression) one example at a time on huge, sparse data streams, producing sparse weights.

**Cost:** O(nonzero features) per example.

### 150. Concept drift detection (DDM, ADWIN, Page-Hinkley)

**Definition:** Detecting when the relationship between inputs and outcomes (or the data distribution) changes, so models can be retrained or adjusted.

**Cost:** O(1) or O(log n) per observation.

---
