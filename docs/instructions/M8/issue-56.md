# Issue 56 — Civilians and crowd cover

Instance `src/npcs/civilian_npc.tscn` for individual civilians or `src/npcs/crowd_hide_spot.tscn` for a group of five. Crowd `route` is a Curve3D in its parent space; default speed is0.4m/s. Author a closed loop to avoid a route-end jump. A crowd is automatic cover within2m while walking/crouching, provided no world/door partition separates the player. Running or drawing a permitted sword reports a scream immediately.

Civilian sight samples at2Hz, with an8m view distance/120-degree forward cone and world/door occlusion. A scream emits radius15m SCREAM through the existing noise dispatcher, leading guards to search, plus a `civilian_scream` mission event for M5 objectives. Each civilian limits screams to once per5 seconds. Death emits civilian_killed once and uses existing score/shura handling. Sword targeting includes civilians, and the R-bound sword action can draw/sheathe from Ground/Crouch; mission action restrictions still apply.

Validation: [QA](../../qa-logs/civilian56/README.md). Code uses TDD; documentation/provenance were reviewed for consistency rather than executable TDD.
