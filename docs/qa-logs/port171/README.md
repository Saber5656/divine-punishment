# M3 port population (#171)

The development scene `src/levels/port_storehouse/port_mission.tscn` combines
#170's geometry with six civilians (four workers, clerk, courtesan), six guards,
two opposing roof archers and Tokubei. Campaign entry remains disabled until
objectives and the remaining mission acceptance are ready.

## Schedule and response

The target uses the existing `PatrolPath` / `RoutineStop` clock: counting room
0–180 s, storehouse inspection 180–240 s, pier meeting 240–300 s, then repeat.
These are 300-second schedule windows. Physical travel consumes part of each
window; they are not 300 seconds of stationary dwell plus instantaneous travel.
This interpretation preserves the specified five-minute schedule without warps.

A synchronized navigation mesh follows the actual floors, cargo gaps, doors and
house staircase. No navigation edge connects roof sentries through open air.
The ordinary escort follows the target; the house reserve joins on area alert.
The merchant then retreats to the counting room rather than investigating or
chasing the player. Damage and assassination remain active, and knockout timers
continue while retreat movement is suspended. The rear crawl route stays open.

An original synthesized wooden-bead sound plays through a 3D SE source at the
counting room, only while the live target is counting there. It stops immediately
on alarm. The deterministic synthesis uses no recording, external sample or
additional dependency. The final sound/art pass remains #82/#61.

## Validation

- Missing population implementation failed before construction.
- The real target capsule navigated counting room → inspection → pier → counting
  room without changing collision or teleporting between route points.
- Role counts, schedule data, escort activation and positional abacus start/stop
  passed. Both existing 25 m / 140° archer fields cover the middle roof crossing;
  no range change was needed. That added coverage test passed on its first run
  and is not reported as a red/green repair.
- Native simulation at time scale 4 (physics delta remains below the controller's
  cap) observed inspection arrival at schedule 213.533 s and pier arrival at
  258.667 s. The initial counting room was occupied at clock 0. Alert from the
  pier at 278 s returned the merchant to the house in 20.8 simulation seconds,
  and the reserve joined. Maximum per-step displacement was 0.166714 m; failures 0.
- This accelerated developer simulation is not human timing or an undetected
  mission clear. Objectives, checkpoints, civilian penalties in a completed M3
  run and the mission-wide checklist remain #172/#173/#60.

Final validation: 614 GUT tests / 4,823 assertions passed, with no script or
parse errors. The exported macOS full-cycle run confirmed the 300-second clock
wrap, all three arrivals, and return to the counting room by simulation time
342 s, with zero failures. Its alarm check starts after that natural return;
the separate source run above proves retreat from the pier. These two scenarios
are recorded separately rather than treating an already-home target as retreat
proof. Exported overview was visually inspected.

Pre-commit self-review covered physical route support, clock/travel semantics,
merchant retreat and incapacitation handling, civilian-free water approach,
archer sight overlap, audio lifecycle, scope and private paths/secrets. No
additional in-scope defect was found. Existing dummy-renderer/shutdown warnings
remain outside this change; they are not script/parse failures.
