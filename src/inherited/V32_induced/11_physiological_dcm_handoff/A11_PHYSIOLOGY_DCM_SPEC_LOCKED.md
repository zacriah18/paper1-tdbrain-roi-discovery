# Diagnosis-blind physiological DCM-node specification

This specification was written before pooled EC-minus-EO effects were
calculated for DCM node selection.

1. The primary physiological metric is the within-participant difference in
   mean support log induced energy: restEC minus restEO.
2. Diagnosis is not used in discovery scoring or physiological replication.
3. Discovery scoring uses percentile-scaled evidence dimensions with fixed
   weights: absolute paired effect size 35%, effect-direction consistency 20%,
   bootstrap sign stability 20%, epoch split-half reliability 15%, and
   resolution separability 10%.
4. The discovery shortlist contains 12 support-band pairs with at most one
   band per support.
5. The frozen shortlist is tested in validation participants using one-sample
   paired effects. Direction must match discovery and Holm-adjusted p must be
   at most 0.05 across all 12 tests.
6. Replicated supports are considered in discovery-score order. Nodes are
   retained only when their resolution-profile cosine with every selected node
   is at most 0.95 and representative coordinates are at least 30 mm apart.
7. The final DCM handoff contains four to six nodes. Failure to retain at least
   four nodes stops the handoff rather than relaxing criteria post hoc.
8. The evidence band motivates node selection but does not restrict the later
   DCM source time series to that band unless the DCM protocol separately
   specifies this.

Representative coordinates are centres for SPM's local DCM spatial basis, not
claims of point-source localization.
