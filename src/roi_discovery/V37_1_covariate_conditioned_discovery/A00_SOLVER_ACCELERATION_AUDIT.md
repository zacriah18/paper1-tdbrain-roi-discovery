# V37.1 solver acceleration audit

Date: 5 August 2026

The original sequential process was stopped after three fully checkpointed
permutations. The incomplete fourth permutation was discarded. V36 was not
stopped or modified.

No scientific operation changed. The accelerated implementation preserves:

- diagnosis permutations and conditional exchangeability blocks;
- locked outer and inner folds;
- training-only imputation and scaling;
- sparse-group objective and penalty grid;
- convergence tolerance and maximum iterations;
- unpenalized nuisance coefficients;
- primary and secondary statistics.

Computational changes only:

- group proximal updates are vectorized rather than looped over 452 patches;
- fold-specific standardized matrices, lambda bases and Lipschitz steps are
  cached across hyperparameter candidates;
- completed permutations use independent atomic shard files.

Verification:

- 23 MATLAB files initially passed parse checks before the parallel runner;
- original versus optimized solver maximum coefficient error: `1.02e-14`;
- identical iteration counts across tested alpha/lambda combinations;
- interrupted real-data permutation-4 folds reproduced at logged precision;
- complete permutation 4 ran in 298.8 seconds and committed successfully;
- validation participants read: zero.
