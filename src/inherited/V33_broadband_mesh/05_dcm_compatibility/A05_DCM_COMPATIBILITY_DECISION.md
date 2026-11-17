# Broadband support-to-DCM compatibility decision

The discovery-only broadband analysis produced six ranked supports, but no
group term survived Holm correction. These are exploratory spatial patterns,
not demonstrated MDD regions.

More importantly, a standard 16 mm local DCM basis does not represent five of
the six supports adequately. One-patch support coverage was:

- Support 7: 17.6%;
- Support 19: 50.8%;
- Support 15: 45.1%;
- Support 20: 41.3%;
- Support 6: 5.7%;
- Support 8: 1.5%.

The current broadband support shortlist is therefore marked
`NOT_APPROVED_FOR_POINT_CENTRED_DCM`. No representative coordinate from this
list should be described as carrying the full regional effect.

The recommended next design is a diagnosis-blind tiling of the canonical mesh
with connected 16 mm local patches, followed by broadband group metrics at the
same spatial scale as the prospective DCM inputs. Alternatively, custom
distributed spatial modes would need to be implemented and validated inside
the DCM observation model.
