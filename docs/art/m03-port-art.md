# M3 port art direction (#61)

Target: a working Edo cargo port at night, with weathered plank quays, white
plaster storehouses, indigo tile roofs, a broad cargo sailing barge and warm
paper lamps. Keep the established low-saturation blue darkness / amber light
contrast. The ship silhouette and stacked cargo should make the water, pier,
roof and interior layers readable from the existing observation points.

Chosen approach: project-authored Blender 5.2 LTS modules, using metre units and
visual-only GLB meshes. Reuse the established production module import and
batching approach. No paid asset procurement, downloaded scripts or unrelated
scene edits are required. Collision, navigation, water volumes, marker transforms
and gameplay light radius/intensity remain owned by the validated graybox.

Alternatives considered: a uniform material recolor would leave the ship and
storehouse silhouettes as boxes; a wholesale scene rebuild would risk the three
verified routes. Named visual modules add plank joints, framing, roof relief,
rigging, cargo and lamp detail while preserving those physical contracts.

Planned kit: quay planks/piles, timber-framed plaster panels, tiled roof, shoji
panel/posts, cargo crate/barrel/rope, ship hull/deck and mast/sail/rigging. Place
decorative obstacles only within existing solid cargo or outside the verified
movement corridors. Geometry remains stylized; no photorealistic texture assets
are assumed.

Before acceptance: inspect the Blender/Godot renders; verify module geometry and
provenance; compare physical/marker/navigation contracts before and after art;
repeat exported A/B/C clears because new visual coverage may hide a gameplay
cue; measure frame rate and compare lit/dark visuals against the same V values.

Implemented kit: 14 modules, including a clothed dock worker and closed counting
cabinet. Worker mesh replaces the existing civilian Body, preserving death and
checkpoint poses. Movable opium cargo retains its rigid body and fitted bounds.
Original art-role metadata survives Godot's repeated sibling-name replacement.
All exported module transforms are baked to identity before runtime batching.

Lighting: the original eight gameplay light sources retain their positions,
radii/intensities and extinction rules. Their paper shades do not cast shadows
onto their enclosed light; emissive paper switches off/on with the real light.
Moon shadows and ambient energy 0.16 give the modular forms readable night depth.
Water ripples alter fragment shading only. Spatial mesh batches cover 16m cells.

Implementation and measured scope: [port61 QA](../qa-logs/port61/README.md).
