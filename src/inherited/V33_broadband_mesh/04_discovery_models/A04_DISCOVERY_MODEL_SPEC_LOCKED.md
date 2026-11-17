# Broadband discovery model specification

This analysis uses only participants assigned to discovery. The validation
cohort is not used to choose broadband DCM nodes.

Primary outcome: support mean within-recording percentile-normalized log
broadband posterior source energy.

Model for each of 20 frozen resolution-compatible supports:

```text
outcome ~ diagnosis * condition + age + sex + retained_good_epochs
          + inverse_VE + (1 | participant)
```

The MDD coefficient and MDD-by-restEO interaction are the two discovery group
terms. Holm adjustment is reported across all 40 terms, but this remains a
discovery analysis.

For a DCM-oriented shortlist, supports must contain at least 50 vertices. They
are ranked by the larger absolute group-term t statistic, then pruned using the
previously frozen profile-cosine (at most 0.95), coordinate-distance (at least
30 mm), and six-node limits. Coordinates remain the resolution-support
representative vertices; group-effect peaks are not used as point locations.

Any subsequent diagnosis PEB test using these nodes must be performed only in
the locked validation participants.
