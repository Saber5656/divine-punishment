# M3 full-route validation and tuning (#173)

The development mission runs through Main/SceneDirector with normal movement,
turning, mapped E/F/C/Q and mouse input, live enemy/civilian perception, physics
and the normal clock. No actor placement, direct kill, disabled AI, invincibility
or changed perception thresholds are used in the clear replay. The original export replay used a local definition copy to expose the development
scene. After all three clears, the actual M3 definition was connected to its
unlocked campaign slot and checked separately through the real board. The replay
uses a volatile campaign store and an isolated save filename.

## Repairs and evidence

- The first roof approach ended in Ground and had no above-assassination prompt.
  A short climb and beam over the counting-room opening now enable the production
  above prompt/F kill. A unit test exercises that posture transition; ordinary
  capsule clearance tests stop at the climb entry because linear standing-capsule
  interpolation is not the climb/beam movement contract.
- The exposed roof kill was witnessed by a guard. Two normally selected/thrown
  smoke bombs cover the kill, ledger pickup and retreat without changing AI.
- Earlier exit scripts hit the staircase underside, an adjacent storehouse wall
  and the side of the rear ramp. The measured return now steps off the staircase
  halfway down, circles the north perimeter and enters open water. Those failed
  attempts remain in the private evidence and are not counted as clears.
- Eight authored lights have real rendering and gameplay sources: outdoor 4
  extinguishable lamps + 2 permanent braziers, indoor 2 extinguishable lamps.
  Twelve searchable points cover the pier, three storehouses, house and rear
  dock. World checkpoints atomically validate/restore all eight light states.

## Checklist audit

| Requirement | Evidence / current boundary |
|---|---|
| Three undetected development clears | Final export replay results recorded below |
| Observation and recovery | Six observation points, cover in each major area, roofs/water/crawl recovery; original route evidence in port170 |
| Light ratio | Outdoor 4/6 extinguishable, indoor 2; source/render validation and checkpoint tests |
| Search/routine/checkpoint placement | Six search zones × 2 points; physical target routine in port171; pier/house/post-kill checkpoints in port172 |
| Measured swift baseline | Authored 16 minutes retained; automated known-route elapsed time is reported separately; human/intermediate timing remains pending |
| Fair perception/debug visualization | Live perception retained, observed roof detection has a smoke solution; source overlay shows 8 light radii and 9 live cones/meters at V=0.156; archer cones use 140°/25m, guards 110°/15m |
| Safe introduction | Starting observation area outside all civilian reporting and guard vision ranges, asserted against actual configured ranges |
| Civilian-free bypass | Export C: zero civilian kills and zero screams through the whole route |
| Inner text / last words | Read from the actual player overlay after mapped F; Japanese text captured in replay result |
| Post scene | Unavailable dependency #79; not marked complete |
| Civilian/shura/scoring | CIVILIAN_HEAVY, civilian −10/+3; existing mission scoring and restoration tests reused; result/save flags captured by the clear replay |

## Scope remaining

The verified graybox can now launch from the unlocked third-night campaign slot.
#60/#173 remain open for the Post transition and actual human baseline evidence.
These are graybox game assets; final port artwork/lighting polish is #61. Export
validation is not a release publication. Existing dummy-renderer/shutdown warnings
are distinguished from script/parse errors.

The first debug capture exposed another real integration gap: only test providers
exported a vision cone, so production guards rendered zero cones/meters. A small
read-only adapter on EnemyBase now supplies the live eye position, weather-aware
range, FOV and meter. Its regression failed with zero samples, then the nine-test
overlay suite passed (31 assertions); a native capture confirmed all nine NPCs.
This does not change detection or AI behavior.

## Exported full clears

Godot 4.3 macOS release-template executable, sequential runs at normal game time:

| Route | End-to-end seconds | Enemy detections | Civilian screams | Result |
|---|---:|---:|---:|---|
| A, pier/crouch/back attack | 108.591 | 0 | 3 | 75, shadow walker |
| B, roofs/above attack/two smoke bombs | 85.788 | 0 | 1 | 75, shadow walker |
| C, water/crawl/below attack | 292.658 | 0 | 0 | 75, shadow walker |

All three: process exit 0, empty failures, result screen reached, zero non-target
or civilian kills, completed/one-strike/swift/shadow-walker save flags. C's minimum
breath was 3.233 seconds; it surfaced between the ship passage and rear approach.
The corpse can be discovered, so these runs do not claim the no-traces award.
Optional opium disposal was verified separately in port172, not part of these
route scores. Save output here is the production result write to a volatile store;
disk persistence and world retry use their separate existing regressions.

Both narrative strings were read from the actual overlay after F: the authored
M3 inner monologue and Tokubei's last words. The images and full JSON/log evidence
are retained in the private task archive. Automated times are 9–31% of the
authored 960-second baseline and cannot substitute for a human first-play study.

Full suite before the last small additions: 626 tests / 4,944 assertions passed,
no script/parse errors. Focused geometry: 9/53; environment/safe introduction:
3/63; debug overlay: 9/31. Initial safe-area test iterations referenced a wrong
method/node and produced script errors despite GUT's passing summary; those
iterations were rejected and replaced with the verified run.

Final pre-commit suite after campaign connection and the read-only debug repair:
**629 tests / 4,973 assertions passed**, no script/parse errors. Campaign board
checks: 3 tests / 16 assertions, including launching unlocked M3 through its
actual start button. Native board launch then reached the overhead approach
with 8 light radii / 9 live cones and zero detections (39.083 s).

Main-agent self-review covered route/body clearance, marker contracts, live
lighting checkpoint validation, campaign initialization, unchanged perception
thresholds, result/save limitations and private-path/secret hygiene.

![Above assassination and authored text](roof-assassination.png)
![Water route result](water-route-result.png)
![Live perception debug](live-perception.png)
