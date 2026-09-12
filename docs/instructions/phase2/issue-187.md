# Issue #187: Festival layout and route implementation

- Parent #64, milestone M9 mission production first half. Base main `37213fb47893acd08fea98ffe401de848cde1e6b` (merged PR186).
- Existing work: M5 is a catalog placeholder with fixed title/inner/final words and 20-minute par. CrowdHideSpot and naruko are already implemented shared mechanics. No festival level exists. Temple art is isolated in another worktree and is not included in this branch.
- References: docs/07-campaign-missions.md M5; docs/maps/m05-festival.md (drawn before implementation); docs/04-level-design.md §4; docs/08-content-specs.md collision/FSM/traversal contracts.

## Purpose and acceptance

Create three physically traversable festival routes before enemy/timing systems are introduced: street/shrine, connected roofs/above-assassination beam, rear-alley well/shallow canal/crawlspace. Keep safe entry, observation/retreat points and ordinary ground escape. #188 owns population/routines, #189 owns fireworks/mission mechanics and #190 owns active-AI/exported undetected completion and checklists. #65 owns art.

## Owned paths and compatibility

`src/levels/festival_night/festival_night.gd` and `.tscn`, `tests/integration/test_festival_layout.gd`, `tests/smoke/festival_routes_smoke.*`, map and route evidence docs. Use existing PlayerController/ClimbEdge/BeamPath/CrawlEntrance/HideSpot, world collision1|16|32 and authored floor material metadata. No player speed/assassination reach/perception changes. Do not wire an empty level into the campaign before real mission objectives exist.

The generic floor helper subtracts the well and dais-undercroft rectangles before building physical floor pieces. The shallow canal floor is below ground; its rising section lies under the open dais footprint, not through the ground slab. Dais floor and roof have different real openings for C and B. Small waypoint/geometry adjustments are allowed when required by measured collision, and must be reflected in the map.

## Execution and verification

1. Add failing tests for the missing level, three route metadata paths, real floor openings, enough headroom and intact ground escape.
2. Implement graybox solids and traversal markers. The well is a controlled drop into a shallow-water walking canal, not a swim or climb-down feature extension.
3. Run actual PlayerController traversals under normal collision. Test roof beam within existing4m assassination range and crawl exit with clear crouch/standing space. Use input-led native smoke; disclose explicit setup used for isolated legs.
4. Review purpose, regression, test validity and privacy; run the focused suite and full combined suite once; commit the task-owned work. Push a reviewable PR with Closes187 only when its route acceptance is satisfied, leaving64open. Require CI and resolve adopted findings before expected-head merge; check merged-main tests/exports/smoke.
5. Record results and concrete remaining work in the canonical Vault task. No artifact from this stage is human timing, undetected active-AI proof, art completion or G3 acceptance.

No unrelated checkpoint/narrative/audio/lighting changes, paid service, release publication or original checkout cleanup. Main-agent self-review is appropriate; no authority/secret/data-loss change requiring independent review.

## Observed dependency: settled crawl exit

The native canal route and a physics-settled integration fixture exposed an inconsistent shared collision query: endpoint clearance lifts its capsule by the existing 5mm support tolerance, while the swept path starts directly against the supporting floor and rejects an otherwise clear exit. Before implementing the repair, add a standalone settled-floor regression. Align the sweep with the existing support tolerance, preserving capsule size, wall checks, range limits and movement tuning. Run existing blocked-crawl and swim-traversal regressions because both use this query, then replay the real festival hatch and full routes. This necessary route dependency belongs in a separate reviewed commit.

The branch now includes merged temple art from main `2d59c192a11c5c0daaa6a3f79fa627169d8d2b90`; the earlier baseline above records the original design start.

PR192 adopted review: the large dais ground cutout remains accessible from the exterior perimeter, and the undercroft floor edge allows escape beneath the land slab. Before correction add actual horizontal collision rays for all exterior sides, an underfloor escape attempt and the required canal opening. Enclose the foundation from its support floor to the deck underside, with a low northern canal opening and upper lintel. Verify ordinary stairs remain clear, replay affected B/C routes, and retain A evidence only if its shrine geometry is unchanged.
