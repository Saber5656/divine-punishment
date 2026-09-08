# Residence art pass (#44)

The residence now tiles the Blender architecture kit inside its authored surface
bounds. Tatami, fusuma with an original ink motif, cedar veranda boards, tiled
roofs, perimeter plaster walls, lanterns, pines and moss stones replace or dress
the graybox. Garden surfaces receive a subdued procedural grain. Four new
original modules are reproducible with `tools/art/build_residence_decor.py`;
the existing kit and upstream licenses are unchanged.

`ResidenceArt` owns presentation only. It batches repeated modules with
MultiMesh, preserves collision shapes/layers, authored marker transforms and
navigation vertices/polygons, and keeps the overhead and below-floor kill
openings. Low roof backing closes seams; slightly separated ground render layers
avoid overlapping coplanar surfaces. Props sit in selected beds outside paths.

The first native inspection exposed coplanar flicker and gaps under tiled roofs.
Both received failing regressions before correction. Final focused tests and
full GUT pass: 514/514, 4161 assertions, no script errors. The existing headless
null-mesh and shutdown orphan warnings remain recorded.

The images are diagnostic cameras under neutral fill light, not the final
lighting pass or human-playtest evidence. Six areas are covered: 171 tatami,
10 fusuma, 50 veranda, 405 roof, 209 wall placements, plus 26 garden surface/prop
placements. Gameplay areas remain larger than individual architectural modules;
module repetition preserves the level's established traversal dimensions.

Self-review checks: visual ownership, bounded placement, shared mesh lifetimes,
module provenance, immutable gameplay snapshots, rendering seams and personal
path/secret exclusion. Native input A/B/C results are recorded below after the
final route run. Final baked illumination belongs to #45.

Final real-input routes: A 165.001 s, B 69.405 s and C 125.508 s. All reached
Results, zero detections, zero tool use; C did not run out of breath and restored
its post-kill crawl checkpoint. The first C pass succeeded functionally but its
capture revealed the player rig covering the near camera. A failing close-camera
regression led to hiding only the local player's rig within 1.6 m of its own active
camera; ordinary third-person views and enemies remain visible. Final C images
show the target through the authored floor gap while solid boards still occlude.
The C route was rerun after that correction; A/B controller and art results are
reused. Final combined GUT: 515/515, 4163 assertions. Self-review checked this
camera rule against Hidden state and non-player cameras before commit.

These are known-route functional timings, not intermediate-player or performance
benchmarks. An earlier C run overlapped an independent editor bake probe; its
148.847-second timing is retained as a separate attempt, not the final figure.
