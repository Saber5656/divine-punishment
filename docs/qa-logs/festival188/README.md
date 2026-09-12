# M5 living population and routines (#188)

Eleven hostile actors: eight doshin, two escorts and Kurosawa Tatewaki. Twelve civilians: two five-person moving CrowdHideSpots and two individual visitors. Civilians stand on their feet atY-0.9; hostile capsules use centre coordinates. Crowd curves close continuously, and existing walking conceal/sprint-sword scream behavior remains active. This scene is separate from the campaign until189objectives exist.

A shared360second schedule includes actual travel: dais180seconds, shrine120seconds, stalls60seconds. At the shrine the target and escorts must actually arrive before escorts walk outside; a full30seconds counts only while the target remains inside and both escorts are calm at their exterior posts. Then they leave prayer and later return to the dais. Goals and facing markers change, never actor positions. Ordinary perception/combat and real collision/navigation continue.

## Evidence

Initial missing-scene tests failed4/4, expanded prayer/phase tests6/6. First implementation passed5/6 but prayer never started because the three single-stop paths were invalid under existing PatrolPath rules. New roster assertions caught those paths; valid preview curves through real stairs resolved them without changing shared validation. Final focused6tests108assertions passed16.643seconds, including all-eleven path validity, actual navigation, no-teleport phase change, combat preservation, crowd conceal/disruption, purephase bounds and continuous prayer.

The attached native result uses Godot4.3/macOS with8x physics time, live AI and an untouched player at entry. It covers the final5ebb70f enclosed foundation with population9b81c67. Wall time53.446seconds; isolated prayer228.9333–259.0667simulation seconds fits within the shrine phase. All eight patrols move3.5696–15.6631m, maximum hostile alert0; target returns to the dais by419.0667seconds. Three actual screenshots show dais, crowds and isolated prayer. Capsule crowd visuals and graybox buildings remain intentional pending65art. An earlier pre-foundation run also passed53.332seconds and is retained privately; the attached evidence supersedes it.

Run `godot --path . res://tests/smoke/festival_population_smoke.tscn -- --output-dir=<evidence-directory>`. This fixture changes simulation speed and inspection camera only; it does not disable AI, place actors, complete a mission or measure first-time player skill. Native acceptance does not claim exported full mission/G3/human-baseline completion. Final combined regression passes691tests/5694assertions in180.691seconds with the enclosed foundation; no Script/Parse errors. Known headless dummy mesh and shutdown orphan warnings remain in full private logs.

Remaining:189fireworks/mission/naruko/checkpoints,190active-AI exported clear/checklists,65festival art/music,79authored Post and49/84external timing. Parent64 stays open.
