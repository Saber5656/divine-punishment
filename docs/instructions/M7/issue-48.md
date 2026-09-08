# Issue #48 performance work

Measure the actual residence at 1920×1080 with 12 active enemies and 20 shadowed lights, after art and baked lighting. Main agent performs implementation, self-review and native measurement. No harness is required.

Use opt-in timing around enemy perception ticks, noise handling and anomaly event callbacks, with per-render-frame aggregation and a bounded recording buffer. Preserve normal gameplay behavior when disabled. The native fixture keeps the player alive solely to avoid an invalid declining-load measurement; enemy brains, navigation, rendering and perception continue.

TDD covers opt-in aggregation and scan fairness. A failing regression demonstrated that a 64-node scan budget inspected only 32 unique markers when alternating with a one-node group. Exhausted groups should be skipped after one pass, preserving round-robin offsets and the 64-node cap.

Record hardware, resolution, view positions, warm-up, frame samples, drawing load and maximum/p95 perception values. Do not present a dead-player run, headless result or unmeasured GPU as performance acceptance. Publish reproducible evidence and retain limitations if a target remains unmet.
