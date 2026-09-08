# Issue #51

Complete existing text infrastructure with catalog-backed tool/mission names, remaining gym text and CI lint. Preserve Godot's key,ja importer header and exported Translation fallback. Add completed-result count snapshots, cumulative narrative counters and the documented shura formula; use SaveManager as the canonical source for GameState. Reuse and verify existing v2 migration rather than introducing a competing save schema.

TDD: aggregate and round-trip counters, cross-mission detection pairs, localized resources and missing lint. Verify nonzero v1 counts and immutable migration input, existing result-save-once behavior, full GUT regressions, Python lint and exported native HUD names. Self-review before commit; CI and unresolved-thread review before merge. No old harness requirement.
