# Candidate-family revision audit

V1 was computed and locked before any validation outcome was opened. It failed
a structural review because all eight candidate slots consisted of four bands
from each of only two supports, and both supports were smaller than 50 mesh
vertices. Reliability and posterior precision were also near ceiling across
the discovery family, so their raw values did not contribute the intended
discrimination.

V1 is retained unchanged as `A09_confirmatory_family_LOCKED.csv` and is marked
rejected. It must not be used for validation inference.

V2 was frozen while validation remained unopened. It:

1. excludes supports with fewer than 50 assigned vertices;
2. converts each evidence component to an empirical percentile within the
   eligible discovery family so the predefined weights remain meaningful;
3. permits at most one frequency band per support;
4. retains the original 35/25/20/20 reliability, prevalence, precision and
   separability weights; and
5. freezes eight support-band candidates.

This revision is discovery-stage method development, not a confirmatory
result. Both versions are preserved for provenance.
