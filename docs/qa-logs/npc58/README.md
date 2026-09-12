# NPC roles acceptance (#58)

Godot 4.3, macOS Forward+ / Apple M4. Source runtime smoke passed on 2026-09-12.

- Fixed archer: 140-degree / 25 m perception, rear blind spot, 0.6-second locked aim, 12 m/s ray-swept arrow, bounded lifetime and count. Original bow and aim/release poses extend the existing licensed actor.
- T toggles nearby companion follow/wait. Escort restricts running and unsupported traversal; crouch/crawl and two-person HideSpots remain available. A navigation anchor matches the foot-origin NPC to the shared actor-center mesh.
- Protected NPC emits a threat once at 720 seconds, without hard failure; rescue cancels the timer. Enemy-caused protected death does not count as a player civilian kill. Unarmored civilians now correctly die from one point of sword damage.
- Procession moves a target and up to 12 guards, spreads formation and exposes the target at 25/50/75 percent of its route. The target physically walks out at rest and is protected while riding.

Validation: final GUT run passed 590 tests / 4,714 assertions (exit 0), with no script/parse errors. The real-floor regression failed before repair. Source and exported macOS runtime `tests/smoke/npc_roles_smoke.tscn` both reported zero failures: physical T input, follow, two-person hide, avoided arrow, three rests, target exit, and 12 guards. Export-only development GUT loader and headless dummy-renderer/shutdown warnings remain distinct from the clean release smoke. Full logs and rendered captures are retained in private task evidence and Agents Vault.

Self-review: checked transitions, collision/navigation coordinates, bounded arrows, death attribution, target vulnerability, privacy, and regression coverage. No independent reviewer was requested. TDD reproduced missing role behavior, invalid arrows, crawl shape, civilian health, missing bow, and the physical-floor follow defect before repair.

Authoring: instance `src/enemies/archer_lookout.tscn`, `src/npcs/protected_npc.tscn`, `src/npcs/escort_companion.tscn`, or `src/npcs/procession_controller.tscn`. Procession routes use local actor-center coordinates and require synchronized navigation plus traversable physical clearance. Connect the protection events to the mission's authored threat sequence. Civilian/companion meshes and the palanquin remain original graybox geometry pending the existing mission art Issues; this does not claim completed M3/M4/M6/M9 levels or human playtesting.


PR review remediation: reproduced and fixed escort damage immunity, melee auto-selection of an invulnerable riding target, and world-aligned guard offsets on turning routes. The affected suites pass 9 tests / 44 assertions. Escort damage retains the no-sword state; resting targets return to melee selection; route tangents rotate formation and the target exit side. Source smoke remains zero-failure after these changes. Original full/export evidence above applies before these follow-up repairs; current-head CI and main exports validate the final delivery.
