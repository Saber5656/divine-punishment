# Issue #43 — humanoid animation integration

Build on the reviewed #42 assets. Add a visual-only actor adapter under `Visual/Model`, preserving all gameplay collision, navigation, damage and assassination timing. Use a shared retargeted AnimationLibrary and an AnimationTree with named presentation states. Retarget rotations against source/target bone rests; preserve target bone lengths and strip locomotion root displacement.

Cover all player stances, four separate assassination clips, enemy unaware/suspicious/search/combat/return/dead presentation, and combat action hooks. Missing traversal motions will be authored as skeletal animation resources, not actor-position tweens. The body stays attached during corpse carry/storage through the existing actor hierarchy. Hidden state hides the visual model.

TDD: absent adapter → contract failure; verify the complete state/context mapping, real mesh/skeleton animation changes, preserved actor collision/position, and unknown-state fallback. Then render stance/contact sequences and a real gameplay cycle. Validate current animation bones/positions, not only clip names. Record AnimationTree graph and source-motion mapping. Self-review before commit, required CI and post-merge exports. Parent owns this implementation; no new delegation.
