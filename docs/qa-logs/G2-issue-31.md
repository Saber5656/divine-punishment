# Issue #31 — Death, checkpoint and retry validation

Date: 2026-09-07. Godot: 4.3.stable.official.77dcf97d8.

## Results

| Check | Result |
|---|---|
| Focused snapshot, player integration and scene contract GUT | 28/28, 229 assertions |
| Repository full GUT | 407/407, 3,278 assertions |
| Production residence, headless | Two death/retry cycles, physical checkpoint overlap, position/count/alert restoration, transient scene reset, abandonment and fresh mission start passed |
| Production residence, rendered | Same sequence passed with Forward+ / Vulkan 1.2.283 on Apple M4; screenshots visually checked for death buttons, restored HUD and abandonment menu |
| Request-to-first-playable-frame, rendered | 20.303 ms and 26.757 ms (warm in-process scene retry, includes resource acquisition and scene initialization) |
| Malformed snapshot / incompatible tools / wrong scene | Rejected without partial player or alert mutation |
| SceneDirector retry failure / abandon | Failure retains menu and snapshot; abandon keeps SaveManager campaign/settings unchanged |
| Secrets / whitespace | No secret patterns in owned source; git diff --check passed |

The measurements are for this machine and the current production graybox, not a guarantee for future art-heavy levels or every target device. This automated rendered smoke is not a claim that a human completed the separate ten-minute free-play check. Existing GUT orphan/ObjectDB diagnostics are retained in the raw evidence; no new failing test or compile error was observed.

## Reproduce

Set `GODOT_BIN` to the verified Godot 4.3 executable, then run from repository root:

```sh
"$GODOT_BIN" --headless --path . --import
GODOT_BIN="$GODOT_BIN" bash ./scripts/run_tests.sh
"$GODOT_BIN" --headless --path . tests/smoke/retry_flow_smoke.tscn
"$GODOT_BIN" --path . tests/smoke/retry_flow_smoke.tscn -- --output-dir=/absolute/existing/evidence-directory
```

The rendered smoke saves `death-menu.png`, `retry-restored-0.png`, `retry-restored-1.png` and `abandon-menu.png`. Success is `RETRY_SMOKE_RESULT` with `failures: 0`, two positive `retry_ms` values below 3,000, and process exit 0. Its watchdog exits 2 after 25 seconds. Raw logs and images are retained in the TSK-1351 task evidence via the parent coordinator.

## Interactive confirmation

Launch `src/levels/samurai_residence/samurai_residence.tscn`, cross `CheckpointInsidePerimeter`, consume a tool and receive lethal damage. The scene freezes, 落命 fades in, and the focused retry button supports keyboard/controller navigation. Retry restores the saved position, tool count and area alert with full player health. Repeat and choose 任務を中止, then 任務を最初から開始. In the integrated Main UI, SceneDirector handles the mission child and returns abandonment to mission selection.
