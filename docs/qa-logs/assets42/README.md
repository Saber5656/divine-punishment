# Issue #42 asset verification

2026-09-08, Blender 5.2.1 LTS and Godot 4.3 stable.

- Missing-asset contract: deliberately failed before generation. Final GLB/rig/module/license checks: 4/4 pass.
- Actual native Godot import and instantiation: three models, each with one humanoid skeleton and the required pelvis/head/hand/foot bones; 10/14/12 meshes respectively. Architecture: 12 named meshes. Unmodified motion library: 43 clips. Contract failures: 0; native probe exit 0 with no errors.
- [Character contact sheet](characters.png) and [architecture contact sheet](architecture.png) were rendered from the delivered GLBs and visually reviewed. The first trial clothing had intersections and was rejected. Final clothing uses separate weighted meshes, corrected outward normals and an opaque face wrap.
- Fresh project startup initially encountered the GUT plugin before its font/class import finished. Completed import and subsequent startup resolved these errors. Godot's automatic LOD simplifier reports one ignored non-finite face; the delivered source triangles were checked and contain no zero-area triangles. Native loading succeeds. Animation-specific deformation and distance LOD appearance remain part of #43/#44 integration QA.
- Main-agent self-review covered scope, source provenance, skin binding, export paths, generated-file inventory, licensing, and machine-path/secret exclusion. CI now verifies the asset contract and includes the notices in all platform packages.

This is asset procurement. It does not claim finished AnimationTree integration, all gameplay poses, collision placement, or a release build. Those remain #43/#44 work.
