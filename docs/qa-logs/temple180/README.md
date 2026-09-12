# M4 unique mechanics validation (#180)

Godot 4.3, macOS Apple M4, 1440×900. The playable M4 scene now composes the existing temple population with its boss, bell, two retainable rescue actors and mission objectives. Environment/character art remains #63.

## Behavior and automated checks

- The one-use E interaction at the bell raises area alert by one, clamped to five, and directs living, available enemies to ten distinct hall positions for 60 seconds. Normal chanting remains a separate cue. An integration replay confirms all ten actors physically reach their gathering points within the window.
- At 720 seconds, CourtWest and CourtEast begin travelling to the cell. Each must arrive alive, conscious and out of combat before killing its still-captive retainer. Ringing the bell temporarily diverts the party. This is a soft deadline: retainer loss fails only the side objective, and target assassination plus entry escape remain possible.
- E frees each reachable retainer through an unobstructed interaction ray. Freed retainers walk the actual cell–courtyard–front steps–entry route; both must arrive alive for the one-time +5 bonus. Freed actors are excluded from scripted execution; ordinary damage still applies until they escape.
- Tetsusenbo has eight health and attacks for two damage. Ordinary player sword damage is blocked until a successful parry opens a 1.2-second counter window. Existing assassination remains lethal and one-shot. Tests exercise the actual PlayerCombat source component and an unrelated attacker that must not open the window.
- Entry, courtyard, cell and post-assassination checkpoints store the clock, bell, stable ten-NPC physical/AI state, two retainers, counter window and mission counters. Restore validates identities, route counts, finite bounds and objective/retainer consistency before world mutation. Tests exercise actual scene replacement, revival, partial rescue, escaped visibility/collision, departed execution routes, corrupt payload rejection and scoring deduplication.
- Campaign result rows preserve `first_clear_flags` independently from best-score flags. Both rescue outcomes survive disk reload and a better later run. H3 appends the appropriate outcome to either existing Shura variant, preserving its six original lines and seen-scene IDs. Legacy saves fall back to their available result flags; unavailable historic first-clear outcomes cannot be reconstructed.

TDD evidence: boss 3 tests/20 assertions, duties 3/27, retainers 3/17, composed objectives 4/33, checkpoints 5/85, story persistence 4/35, hideout integration 3/56. New behavior first failed for its missing contract. Fixture errors involving a not-yet-imported class and inspecting results before final words ended were corrected and are not counted as accepted red runs.

The complete local regression passed **672 tests / 5,386 assertions** in 163.007 seconds with no Script/Parse errors. The known headless dummy-renderer null-mesh diagnostics and shutdown orphan warnings remain. Text catalog lint: zero findings. All production changes received main-agent self-review before commit; CI covers the combined branch.

## Native exported game

`tests/smoke/temple_mechanics_smoke.tscn` runs through the real SceneDirector, mapped R/E and mouse input, production retry, result screen and H3. Use `--output-dir=OUTPUT`; it also runs from the exported macOS PCK with the release executable. The fixture uses a volatile save store, explicit player placement, a timed enemy attack and final target assassination setup. AI and collision remain enabled. Retainer walking alone runs at 4× simulation time. This is **not a normal stealth-route completion or human timing baseline**.

The exported run exited 0 after **27.700 wall seconds**, with `failures: []`. A blocked sword hit leaves boss HP8, successful mapped parry leaves player HP3, and the counter reduces boss to HP7. Real scene replacement restores it to HP8. Combat retry took **211.959 ms**; partial-rescue retry took **191.826 ms** and retained the used bell and only the first freed retainer. Both actors physically escaped in **72.467 simulated seconds**. Result UI shows **80 points**, including the **+5 side objective**, and H3 displays the saved rescue outcome. The result rank animation is allowed to finish before capture.

No Script/Parse or engine ERROR occurred in the final exported run; the existing shutdown ObjectDB warning remains. An earlier source-fixture teardown produced `can_process` errors after its successful result; allowing scene cleanup to finish eliminated them in the final export.

![Two freed retainers in the cell, with existing placeholder bodies](rescue.png)

![Actual result screen with rescue bonus](result.png)

![H3 saved rescue outcome](h3.png)

## Remaining scope

Normal-time exported A/B/C infiltration, campaign unlock progression, light/visibility readability and the combined level checklist remain #181. Bespoke temple, monk/umbrella/naginata and retainer presentation remains #63; the authored campaign Post cutscene remains #79; complete hideout art/content remains #81. The 20-minute par remains an authored tuning value. No release was published.
