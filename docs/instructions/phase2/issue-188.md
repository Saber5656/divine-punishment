# Issue188: festival population and real routines

Prospective instruction. Current merged main2d59c192a11c5c0daaa6a3f79fa627169d8d2b90. This isolated branch temporarily stacks on layout187 commitfbd5953; rebase onto merged187 before publication. Existing Player/EnemyBrain/TargetNpc/CrowdHideSpot/CivilianNPC remain the runtime contracts. References: docs/07-campaign-missions.md M5, docs/maps/m05-festival.md, docs/08-content-specs.md.

## Acceptance and owned scope

Create a separate festival_population.tscn inheriting the NPC-free layout, eight doshin, two escorts, Kurosawa target, and twelve living civilian actors (two existing five-person moving crowds plus two individuals). Bake real collision navigation for Land/ShrineDeck/DaisDeck/ordinary stairs, exclude canal and roof shortcuts. Real NPC routes must cross both stairs, with no schedule teleportation and unchanged combat/perception. Safe southern entry must remain outside hostile vision.

Own src/levels/festival_night/festival_population.gd/.tscn, festival_navigation.gd, festival_tuning.gd, data/tuning/festival.tres, targeted integration/unit/native tests, map roster and QA. Necessary local geometry corrections require measured path evidence and regression. No campaign wiring before189objectives; no fireworks/art/audio/checkpoint mutation in188. No shared AI weakening, new dependencies, release publication or unrelated cleanup.

## Routine design

Tuning resource owns phase durations180/120/60seconds and prayer30seconds. A shared six-minute clock selects dais, shrine or stalls; phase includes real travel. Each important NPC keeps an ordinary live Brain with one dynamic RoutineStop goal, while the scheduler changes only its goal/action/facing. Eight doshin use existing bounded authored patrol paths. Clock changes cannot assign actor transforms.

Dais target(84,3.02,32), escorts(82,3.02,30)/(86,3.02,30). Shrine target(51,3.02,17), escorts(48,3.02,19)/(54,3.02,19). Once all three actually arrive, escorts walk outside to(47,0.02,31)/(55,0.02,31). Only after both reach those exterior points, start a full30seconds of prayer. Then target walks toward shrine front(51,3.02,24), escorts return to flanks. The phase clock still ends at300seconds, so native verification must show actual travel leaves room for the full prayer window; if not, fix authored routes based on evidence. Alert/combat interrupts ordinary arrival eligibility without being cancelled by schedule updates. Track cycle/prayer stage and elapsed explicitly for later189checkpoint capture.

Stalls: first half target(48,0.02,56), second half(58,0.02,42); escorts offset by2m inX. Doshin patrol pairs: west-south(39,70)-(39,60); east-south(58,76)-(58,60); west-middle(40,52)-(40,42); east-middle(58,50)-(58,40); shrine-west(42,31)-(46,31); shrine-east(58,30)-(58,35); dais-east(96,34)-(96,44); rear(72,23)-(64,23), allY0.02. Adjust only for measured physical path/entry safety.

Civilian origin is feetY-0.9, unlike player/enemy capsule centres. Closed continuous crowd curves avoid wrap teleportation; first loop leads from(24,80) to central street, second loops northern stalls. Use existing automatic conceal and sprint/sword disruption, not locked Hide state or disabled perception. Keep stable ids for actors and checkpoint preparation.

## Verification and delivery

TDD: missing scene/roster; actual navigable shrine/dais/ground paths and no roof shortcut; clock transition without actor placement; genuine arrival-gated30second prayer with guards outside; combat state preserved; closed crowd curves and conceal/disruption event; fresh reload. Native accelerated schedule fixture is explicitly timing-system evidence, not normal-time mission/human completion. Focused tests then one combined full suite, main-agent self-review, meaningful commits, privacy scan, PRCloses188onlyafteracceptance, CI/findings/expected-head merge and merged-main exports/Linux boot. Keep64/190open. Record evidence in canonical Vault; no retired harness or unnecessary subagents.
