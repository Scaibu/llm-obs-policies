# Part 4: Experimentation and statistics (#151–200)

Same format and the same contract (roles; rules T1–T8; guardrails TX1–TX5). This is the final part. Already covered elsewhere and not repeated: interleaving (V#166), bandits (G89), conformal prediction (NN#270), causal DAGs, d-separation, PC/FCI and do-calculus (graph #279–281), KS and PSI drift tests (V#170), change-point detection (graph #215, G89), off-policy evaluation (NN#205).

## D1. Testing foundations

### 151. Hypothesis testing framework (p-values, significance, power, MDE)

**Definition:** The standard framework for deciding whether an observed difference (between treatment and control) is larger than random noise would plausibly produce.

**Cost:** Cheap computation. The real cost is sample size (#157).

### 152. t-tests and Welch's t-test

**Definition:** Tests comparing the means of two groups, with Welch's version not assuming equal variances.

**Cost:** O(n).

### 153. Tests for proportions (z-test, chi-squared, Fisher's exact test)

**Definition:** Tests comparing rates (conversion, error rate, click-through) between groups.

**Cost:** Cheap.

### 154. Nonparametric tests (Mann-Whitney U, permutation tests)

**Definition:** Tests that don't assume a particular distribution, comparing ranks (Mann-Whitney) or using reshuffling of group labels (permutation).

**Cost:** Mann-Whitney O(n log n). Permutation: many recomputations.

### 155. Bootstrap confidence intervals (percentile, BCa)

**Definition:** Estimating a statistic's uncertainty by resampling the data with replacement many times and looking at the spread of the recomputed statistic.

**Cost:** B recomputations of the statistic.

### 156. Delta method for ratio metrics

**Definition:** Approximating the variance of a function of estimates (such as a ratio of two means), needed when the metric's denominator is random.

**Cost:** O(n).

### 157. Power analysis and sample size calculation

**Definition:** Calculating how many units (or how long) an experiment needs to detect an effect of a given size with given confidence.

**Cost:** Negligible.

## D2. Randomization and validity checks

### 158. Randomization and hash-based bucketing

**Definition:** Assigning units to experiment variants randomly but deterministically, so each unit always gets the same variant.

**Cost:** One hash per assignment.

### 159. Sample ratio mismatch (SRM) check

**Definition:** Checking that the observed split of units between variants matches the designed split, which detects broken assignment or logging.

**Cost:** Negligible.

### 160. A/A tests

**Definition:** Running experiments where both variants are identical, to verify that the experimentation system and statistics behave correctly.

**Cost:** Traffic or simulation.

## D3. Variance reduction

### 161. CUPED (controlled experiments using pre-experiment data)

**Definition:** Reducing the variance of experiment metrics by adjusting each unit's outcome with its own pre-experiment behavior.

**Cost:** Negligible.

### 162. Stratification and post-stratification

**Definition:** Reducing variance by accounting for known subgroups (platform, country, user tenure), either in the assignment or in the analysis.

**Cost:** Negligible.

### 163. Regression adjustment (ANCOVA, Lin's estimator)

**Definition:** Estimating treatment effects with a regression of the outcome on the treatment indicator plus pre-treatment covariates, which reduces variance.

**Cost:** One regression.

### 164. Winsorization and capping of heavy-tailed metrics

**Definition:** Limiting extreme values in a metric (for example revenue or session time per user) to reduce variance from a few outliers.

**Cost:** Negligible.

## D4. Sequential and Bayesian testing

### 165. Group sequential designs and alpha spending (O'Brien-Fleming, Pocock)

**Definition:** Allowing a fixed number of planned interim analyses during an experiment, with adjusted significance thresholds so the total false positive rate stays at α.

**Cost:** Slightly larger maximum sample size than a fixed design.

### 166. Always-valid inference (mSPRT, confidence sequences)

**Definition:** Methods that let you check results continuously at any time and stop whenever, while keeping the false positive rate guaranteed.

**Cost:** Some loss of power compared with a fixed design, in exchange for flexibility.

### 167. Bayesian A/B testing (beta-binomial, expected loss)

**Definition:** Analyzing experiments by computing posterior distributions of each variant's metric, and deciding with probabilities and expected losses instead of p-values.

**Cost:** Cheap.

## D5. Multiple testing and metric design

### 168. Family-wise error control (Bonferroni, Holm)

**Definition:** Adjusting for many simultaneous tests, so the probability of at least one false positive across all of them stays at α.

**Cost:** Negligible.

### 169. False discovery rate control (Benjamini-Hochberg)

**Definition:** Controlling the expected fraction of false positives among the results declared significant, which is less strict than family-wise control and suits many exploratory metrics.

**Cost:** Negligible.

### 170. Overall evaluation criterion and guardrail metrics

**Definition:** Designing the metric set for experiments: one primary decision metric (the OEC) that reflects long-term value, plus guardrails that must not degrade.

**Cost:** Design effort.

## D6. Complex experimental designs

### 171. Cluster randomization and intraclass correlation

**Definition:** Randomizing groups (teams, stores, regions, accounts) instead of individuals, when individuals within a group affect each other, and analyzing with the right variance.

**Cost:** Much larger sample sizes for the same power.

### 172. Switchback experiments

**Definition:** Alternating the whole system (or a region) between treatment and control over time periods, for interventions that affect everyone at once (pricing algorithms, dispatch, matching).

**Cost:** Needs many periods for power.

### 173. Network experiments (graph cluster randomization)

**Definition:** Experiments on networks where treated units affect untreated neighbors (interference), designed by randomizing clusters of the network.

**Cost:** Fewer effective units, so less power.

### 174. Long-term effects (holdouts and surrogate indices)

**Definition:** Estimating the long-term impact of changes that experiments can only observe for a short time.

**Cost:** Holdouts forgo improvements for some users. Surrogate models need historical data.

### 175. Heterogeneous treatment effects (causal forests)

**Definition:** Estimating how a treatment's effect varies across individuals, based on their characteristics, with honest uncertainty.

**Cost:** Like random forests (#107).

### 176. Uplift modeling (meta-learners: S, T and X-learners)

**Definition:** Predicting the incremental effect of a treatment for each individual (who would respond because of the treatment), using standard ML models arranged in specific ways.

**Cost:** A few model fits.

### 177. Novelty and primacy effect detection

**Definition:** Detecting effects that change over time because users react to the newness of a change (novelty: initial excitement fades; primacy: initial resistance fades).

**Cost:** Requires longer experiments.

### 178. Trigger analysis and dilution

**Definition:** Analyzing only the users who could actually have experienced the change (the triggered population), then translating the effect back to the whole population.

**Cost:** Requires counterfactual trigger logging.

## D7. Causal inference from observational data

### 179. Difference-in-differences (DiD)

**Definition:** Estimating a causal effect by comparing the before/after change in a treated group with the before/after change in an untreated group.

**Cost:** Cheap.

### 180. Synthetic control

**Definition:** Building a weighted combination of untreated units that closely matches the treated unit before treatment, and using it as the counterfactual afterward.

**Cost:** One optimization per unit.

### 181. Regression discontinuity

**Definition:** Estimating causal effects where treatment is assigned by a threshold on a score, by comparing units just above and just below the threshold.

**Cost:** Cheap.

### 182. Instrumental variables (two-stage least squares)

**Definition:** Estimating causal effects when the treatment is confounded, using a variable (instrument) that shifts the treatment but affects the outcome only through it.

**Cost:** Cheap.

### 183. Propensity scores (matching, inverse probability weighting)

**Definition:** Adjusting observational comparisons for confounding by modeling each unit's probability of receiving treatment from observed covariates.

**Cost:** One model fit plus matching or weighting.

### 184. Doubly robust estimation (AIPW) and double machine learning

**Definition:** Effect estimators that combine an outcome model and a propensity model, remaining correct if either one is correct, and allowing flexible ML models with valid inference.

**Cost:** Several model fits with cross-fitting.

### 185. Interrupted time series and Bayesian structural time series (CausalImpact)

**Definition:** Estimating the effect of an intervention on a single time series by forecasting what would have happened without it, from its pre-intervention behavior and related unaffected series.

**Cost:** Moderate (MCMC for the Bayesian model).

## D8. Operational statistics and robust estimation

### 186. Statistical process control charts (Shewhart, EWMA charts)

**Definition:** Monitoring a process metric over time with control limits that separate normal variation from signals needing investigation.

**Cost:** Negligible.

### 187. Survival analysis (Kaplan-Meier, Cox proportional hazards)

**Definition:** Analyzing time until an event (churn, failure, conversion, resolution) when some units haven't experienced the event yet (censoring).

**Cost:** Cheap.

### 188. Comparing tail latencies (quantile confidence intervals and tests)

**Definition:** Correctly comparing high percentiles (p95, p99) of latency or other heavy-tailed metrics between versions.

**Cost:** Moderate (bootstrap).

### 189. Robust estimators (Huber M-estimators, trimmed means, median of means)

**Definition:** Estimators of central tendency and effects that are much less affected by outliers and heavy tails than plain means.

**Cost:** Cheap.

### 190. Jackknife variance estimation

**Definition:** Estimating the variance of a statistic by recomputing it with each unit (or group) left out.

**Cost:** n (or number of groups) recomputations.

### 191. Hierarchical models and partial pooling (empirical Bayes)

**Definition:** Estimating many related quantities (effects per segment, per country, per store) by sharing information across them, shrinking noisy estimates toward the group average.

**Cost:** Cheap (empirical Bayes) to moderate (full Bayes).

### 192. Cluster-robust (sandwich) standard errors

**Definition:** Standard errors that remain valid when observations are correlated within groups, or have unequal variances.

**Cost:** Cheap.

### 193. Exact tests and rare-event analysis (Poisson and exact binomial tests)

**Definition:** Statistical tests and intervals that stay valid when events are rare (incidents, failures, fraud cases), where normal approximations break down.

**Cost:** Cheap.

## D9. Experiment platforms and decision quality

### 194. Overlapping (layered) experiment infrastructure

**Definition:** Running many experiments simultaneously on the same users, by organizing them into independent layers so experiments don't interfere and traffic isn't wasted.

**Cost:** Platform complexity.

### 195. Staged rollouts with statistical guardrails

**Definition:** Releasing changes in increasing percentages of traffic, automatically checking guardrail metrics with valid sequential statistics at each stage, and rolling back on degradation.

**Cost:** Slower full rollout.

### 196. Metric change decomposition (root-causing KPI movements)

**Definition:** Explaining why a top-level metric changed, by attributing the change to segments, components or factors.

**Cost:** Grows with the number of dimensions and their combinations.

### 197. Meta-analysis across experiments (fixed and random effects)

**Definition:** Combining the results of several experiments (or several runs of similar experiments) into one overall estimate.

**Cost:** Cheap.

### 198. Winner's curse correction (shrinkage of experiment effects)

**Definition:** Correcting the systematic overestimation of effects for experiments that were selected because they looked successful.

**Cost:** Cheap with historical experiment data.

### 199. Simpson's paradox and regression-to-the-mean checks

**Definition:** Checks for two common statistical traps: an aggregate trend reversing within subgroups (Simpson's paradox), and extreme measurements naturally becoming less extreme on remeasurement (regression to the mean).

**Cost:** Analysis discipline.

### 200. Sensitivity analysis for unobserved confounding (E-values, Rosenbaum bounds)

**Definition:** Quantifying how strong an unmeasured confounder would have to be to explain away an observational effect estimate.

**Cost:** Cheap.

---
