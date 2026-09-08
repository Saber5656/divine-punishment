# Issue #41 developer playtest and tuning

Main-agent developer testing, Godot 4.3 native Forward+, 2026-09-08. This does not substitute for the new-player acceptance required by #49.

Reproducible residence inputs are now in `tests/smoke/residence_route_{a,b,c}.gd`, sharing `residence_route_replay.gd`. Launch each with `--path . -s tests/smoke/residence_route_a.gd -- --output-dir=OUTPUT_DIR`. Saves/checkpoints go to that output directory; the script does not overwrite the normal campaign save. The driver uses production mission-selection buttons, movement actions and interaction input, without repositioning actors or disabling AI. Route C deliberately exercises checkpoint restoration as part of its previously documented path; it is not presented as a fresh no-retry run.

Prior known-route evidence: tutorial ground105.094s / roof103.272s; residence A165.001s / B69.405s / C125.508s, zero detections. Those were recorded before final lighting/presentation, so current verification follows below.

## Tuning

Measured known-route limits are M1=120s, M2=180s in `scoring.tres`, with corresponding mission metadata. These replace unmeasured 10/18-minute placeholders. The margin above the developer route allows small execution variation; this is an upper-rank replay challenge, not a first-time learning-time estimate. Other missions keep their authored limits. Nonpositive authored time still disables Swift. Boundary TDD failed at180.001s before the change and passed afterward; custom-mission fallback is covered too.

Perception remains 110°/15m, gain2.0, decay0.5, thresholds1/2/3, hearing1.0, return vigilance1.5 for120s. Changing these without a demonstrated detection defect would invalidate established route balance. Scoring remains40/25/20/15, rank thresholds90/75/55 and the documented penalties.

## Current run evidence

A:166.795s, B:70.687s, C:126.071s. All reached results with zero detections, zero failures and time_scale1. C retained at least12.85s breath and never forced surfacing. Tutorial ground:105.326408s, all eight learning records, results, passed=true, debug_checkpoint=false and time_scale1. Actual hiding lasted10.0667s while the patrol moved9.1002m; two lanterns were extinguished, stone noise moved the sentry, and assassination/body storage/document/escape completed.

No open bug-labeled issue is used as proof of absence: the final claim is limited to reproduced routes and regression cases for light occlusion, noise delivery, detection thresholds, body/anomaly discovery and re-stealth. Human first-play acceptance remains #49; performance spikes remain #48.

Visual review of current A/B approach captures confirms production characters and lighting; dark-route readability remains a human playtest topic. Repository issue audit found no open bug-labeled reports. This is not proof that undiscovered detection bugs cannot exist.

Final full suite:528 tests /4332 assertions passed. This includes detection/occlusion/noise/anomaly and production re-stealth regressions. No script errors; pre-existing headless dummy-renderer/ObjectDB shutdown warnings are retained in raw logs. Self-review checked timing authority/fallback, disabled limits, save isolation, input-only route claims and documentation consistency. No reproduced unfair-detection or missed-detection defect remains in this tested set.
