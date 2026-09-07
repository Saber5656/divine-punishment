# Screen flow integration — Issues #31 / #36 / #37

Godot 4.3.stable.official.77dcf97d8; verification on 2026-09-07 and 2026-09-08.

| Verification | Observed result |
|---|---|
| Integrated full GUT, final source | 457/457 tests, 3,662 assertions, 29.785 seconds; exit 0 |
| Earlier integrated full GUT | 455/455, 3,627 assertions; retained as earlier-stage evidence |
| Settings layout regression | Red: built-in editor actions exposed untranslated labels and oversized controls. Green: game actions only, bounded binding text, keyboard focus follows scrolling |
| Result persistence regression | Red: no result saved/displayed in selection. Green: completed result recorded once through the existing SaveManager, best rank displayed; test storage is injected |
| Minimum 640×360 rendered window | All title controls fit the visible margins; settings sliders remain inside their panel; long menus scroll |
| Exported Japanese text | Red: imported CSV source absent, key names shown. Green: imported Japanese Translation fallback resolves the Japanese title in the release runtime |
| Final exported macOS runtime + fresh PCK | Real WASD / crouch / F approach, target defeat, physical escape, results, selection, settings entry, pause/death retry and abandonment; 14.250 seconds, failures 0, exit 0 |
| Final exported retry measurements | 17.634 ms and 18.438 ms, request through first playable frame |
| Parent's independent sustained runtime | 51 cycles / 600.471 elapsed seconds / failures 0, retries 10.233 and 21.778 ms. Its snapshot predates final CSV/settings/result-save integration; it proves the shared movement/assassination/escape/retry loop only |

The release-runtime check launches a Godot 4.3 macOS release executable from the existing main CI artifact with this branch's newly exported PCK, outside the source checkout. It verifies packed resources and gameplay, not a new signed application bundle. Linux startup remains a CI check. Measurements are specific to this graybox, machine and warm process; they do not predict future art-heavy load times.

GUT's existing orphan/ObjectDB diagnostics and editor export-time addon/resource cleanup diagnostics are retained in raw logs. The final runtime had no script errors or missing Japanese text. Earlier exit-0 runs with parse errors or missing text were rejected rather than counted as success.

## Reproduce

From the repository root, point `GODOT_BIN` at the verified 4.3 executable:

```sh
GODOT_BIN="$GODOT_BIN" bash scripts/run_tests.sh
"$GODOT_BIN" --path . --resolution 640x360 tests/smoke/screen_flow_smoke.tscn -- --output-dir="$EVIDENCE_DIR/minimum"
"$GODOT_BIN" --path . tests/smoke/screen_flow_smoke.tscn -- --minimum-seconds=600 --output-dir="$EVIDENCE_DIR/runtime"
"$GODOT_BIN" --headless --path . --export-pack macOS "$EVIDENCE_DIR/ui.pck"
```

The smoke driver asserts Japanese text, visible title controls, physical objective completion, pause/death retry, result completion, abandonment, screenshot writes and retry latency. It emits `SCREEN_SMOKE_RESULT` with failures/cycles/elapsed/retry values and exits nonzero on a failed assertion. A watchdog ends stalled runs. Menu buttons are activated programmatically; movement and assassination use real input events. This is automated rendered runtime evidence, not a claim of ten minutes of human free play.

## Self-review

The implementation agent reviewed the complete changes before committing: scene ownership, checkpoint restoration order, settings input capture, CSV export behavior, result-save idempotence, body-space perception, scope, tests and personal-path/secret exposure. Findings about wrong player forward, detached enemy eye, body sampling, settings width, title clipping, exported translations and result persistence were corrected. The existing save format and safe-write implementation are unchanged; completed results use the reviewed SaveManager API. Generated import/translation metadata is excluded from commits.
