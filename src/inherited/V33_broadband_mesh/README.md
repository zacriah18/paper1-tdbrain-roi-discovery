# V33 broadband mesh analysis

This branch replaces frequency-specific maps as the primary exploratory bridge
to broadband/cross-spectral DCM. It preserves V32 as a spectral sensitivity
analysis.

The V33 estimand is mean single-epoch posterior source energy reconstructed in
the complete temporal subspace of each fitted MSP inverse. It produces one
8,196-vertex map per recording. It is not `inverse.J`, a trial-average signed
amplitude, and it is not a sum of conventional frequency bands.

The coefficient-domain calculation is divided by the number of time samples
and numerically validated against explicit reconstructed source time series.

## Completed results

- Explicit source-time equivalence passed with maximum relative error 5.95e-8
  and correlation effectively 1.0.
- 610 unique recording meshes were extracted without failure.
- Discovery group cells contained 107 HC-EC, 97 HC-EO, 115 MDD-EC and 105
  MDD-EO recordings.
- Zero of 40 diagnosis or diagnosis-by-condition support terms survived Holm
  correction. The smallest adjusted p-value was 0.0842.
- Six discovery-ranked supports were retained for a DCM-compatibility audit;
  they are exploratory and are not validated MDD regions.

## DCM compatibility result

Only one of the six broadband-shortlisted supports had at least 50% of its
vertices covered by a single 16 mm geodesic patch around its representative
coordinate. Single-patch coverage ranged from 1.5% to 50.8%. The two largest
supports had median geodesic radii of 51.0 and 103.4 mm and received only 5.7%
and 1.5% coverage, respectively.

Therefore the six-support list must not be passed to ordinary point-centred
DCM as if each coordinate represented its full mesh support. A subsequent DCM
analysis must either use local-patch-sized candidates from the outset, develop
custom distributed spatial modes spanning each support, or use independently
defined DCM coordinates and treat this mesh analysis as contextual evidence.
