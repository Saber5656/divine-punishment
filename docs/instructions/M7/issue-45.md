# Residence lighting pass

Use the pinned Godot 4.3 pipeline. Bake static moonlight into real LightmapGI
textures, keep only gameplay lanterns dynamically shadowed, and use a subdued
high-contrast night environment. Verify rendered near/far/occluded lantern states
against the existing visibility overlay and light contribution; extinguishing a
light must also remove its rendered illumination. Keep actors and collision
contracts unchanged.

The editor-only bake is reproducible in an isolated minimal project so editor
serialization cannot rewrite game resources. Convert static visual batches to
UV2-unwrapped ArrayMeshes for baking. Preserve the tested art geometry; combine
surfaces by material rather than issuing one draw per tile. Runtime loads the
baked visual scene and the authored gameplay geometry remains authoritative.

A tiny fixture already verified GPU bake output. That is capability evidence,
not production lighting acceptance. TDD requires actual nonempty baked data,
static/dynamic light roles and visibility/render consistency. Native screenshots
and an exported runtime must load the real baked artifacts before completion.
