# DCM handoff revision audit

The first A11 handoff passed its written physiological replication and
redundancy criteria, but post-run inspection showed that three of its six nodes
were supports smaller than 50 vertices. This conflicted with the minimum size
rule already adopted and documented during candidate-family revision, before
the physiological analysis.

The first handoff is retained but marked rejected before DCM construction. V2
uses the unchanged discovery shortlist and validation estimates, applies the
existing 50-vertex minimum, and repeats the already frozen profile-cosine,
coordinate-distance and six-node limits. No p-value, effect direction,
coordinate, cross-talk threshold or model result was changed.

Only `A11b_DCM_node_handoff_V2_LOCKED.csv` should be used to construct DCMs.
