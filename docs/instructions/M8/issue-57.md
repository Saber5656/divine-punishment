# Issue57 — Enemy ninja

Instance `src/enemies/enemy_ninja.tscn`. It preserves EnemyBase child APIs and collision layers, uses perception_shinobi,4HP/1damage and the shinobi rig. Add roof/beam NavigationRegion3D and connecting NavigationLink3D on navigation layer2; ninja agents use1|2, ordinary guards1. Author sufficient capsule clearance at vertical exits; ninja waypoint proximity is1mm so links do not cut roof corners.

Brain `knockout_immune` rejects sleep/knockout; `relight_delay_seconds` defaults60 for existing guards and0 for ninja. Existing dart_immune also blocks blow darts. EnemyNinja search tactics drop CaltropTrap (single1damage,30s life,10s cooldown,max3 per ninja/12 world). The existing V formula remains authoritative. Shared movement retains unchanged paths and permits bounded collision separation; animation reads actual displacement because navigation clears velocity after each move.

Validation: [QA](../../qa-logs/elite57/README.md). Behavior uses TDD; documentation/provenance use consistency review.
