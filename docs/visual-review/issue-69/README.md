# Issue #69 — Potager diorama, Pass 2 review

**Decision: pending external visual review.** Do not start Pass 3.

Pass 1 remains approved. Pass 2 adds:

- four low two-contact cultivation surrounds;
- a dedicated permanent cultivated-earth layer;
- five transparent broad path pieces;
- the authored entrance → center → trellis route;
- a short utility branch;
- no gameplay contact changes;
- no production Potager map changes.

The two diagonal surrounds use a negative Tiled `zBias` so the complete
surround remains behind both dynamic crops while its visual placement stays
unchanged.

Review saturated first against `test.png`, then intermediate and initial.

Judge:

- whether the four surrounds read as one cultivated heart rather than four boxes;
- whether crop crowns dominate the low timber rims;
- whether the route reads as a path rather than a dotted chain;
- whether the initial state suggests a prepared garden without implying ownership;
- whether the permanent earth treatment is broad enough but leaves readable
  circulation space.

The known geometric right-flank debt remains deferred to #70 / Pass 3.

Generated review helpers:

- `pass2_blockout_390x450.png`
- `path_tiles_1x.png`

Deterministic Flutter captures, when available, are stored beside this file.
