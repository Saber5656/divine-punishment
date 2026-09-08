# Character animation integration (#43)

`ActorAnimation` lives under each actor's `Visual/Model`. It instantiates the
licensed shinobi, ashigaru or magistrate rig and shares one retargeted library
per role. Gameplay remains responsible for position, collision, damage and
assassination timing. The mesh faces gameplay -Z; the imported rig faces +Z.

## AnimationTree

Each named `AnimationNodeAnimation` feeds one input of the `state`
`AnimationNodeTransition`, which feeds `output` in an `AnimationNodeBlendTree`.
Transitions blend for 0.1 seconds. The adapter advances the tree manually while
unpaused, including when corpse ownership disables the actor's AI. A hidden
player hides the model. Combat and assassination signals temporarily select
one-shot clips; an assassination retains its context until the FSM leaves it.

| Presentation | Licensed base / authored adjustment |
|---|---|
| Idle, walk, sprint | Idle, Walk, Sprint |
| Crouch idle / movement | Crouch_Idle, Crouch_Fwd |
| Swim idle / movement | Swim_Idle, Swim_Fwd |
| Wall cling / climb | Idle with braced arms / Walk with raised arms |
| Beam / crawl | Walk_Formal with balance arms / Swim_Fwd with prone spine adjustment |
| Suspicious / search | Idle_Talking at rest; Walk or Walk_Formal while moving |
| Combat / attack / dodge / death | Sword_Idle / Sword_Attack / Roll / Death01 |
| Back / above / corner assassination | Sword_Attack; above bends the pelvis, corner turns the spine |
| Below assassination | Prone Swim_Fwd with raised striking arm |

Four assassination tracks are distinct, non-looping 1.25-second resources.
Retargeting reconciles local source/target bone rests, preserves target bone
lengths and removes root displacement. A project-authored short blade is bound
to `hand_r` during sword actions. All original asset license notices remain in
`assets/characters` and `assets/animations`.

## Verification (Godot 4.3)

- TDD failures covered the missing adapter, crawl clearance, climb reach,
  lost assassination context, disabled corpse animation, overlapping proxy
  meshes, moving combat/stationary search mapping, blade binding and prone
  below-floor assassination. The corresponding regressions pass.
- Final GUT command executed 500/500 tests, 3917 assertions. This includes the
  nine animation tests twice because the explicit file and configured directory
  were both selected: 491 distinct tests. No script errors. Existing headless
  dummy-renderer null-mesh and shutdown orphan warnings remain recorded.
- Native renderer: twelve controlled pose captures, zero failures. These are
  visual inspection scenes, not gameplay or first-player timing evidence.
- Native production Main: real input through backstab, escape, Results and
  retry; one cycle in 15.766 seconds, zero failures; retry 17.541/11.442 ms.
- Self-review checked gameplay ownership, signal paths, root motion, paused and
  disabled actors, old proxy cleanup, all stance/context mappings and private
  paths/secrets. No unresolved findings in this scope.

Screenshots show the actual imported rig and skeletal poses. They do not claim
final lighting, cinematic choreography or human playtest acceptance. Detailed
red/green and native logs are retained in the shared task Vault.
