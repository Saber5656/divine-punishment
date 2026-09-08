# Campaign selection and progress (#53)

CampaignCatalog exposes ordered m01–m10 definitions, exact-ID unlock queries and a completion-receipt check. SceneDirector's selection uses a horizontal chapter strip with best-rank seals and five achievement marks, a wanted-poster panel, Oko's three-line introduction and fixed inventory counts. Cleared nights stay selectable. First-clear-only narrative persistence was delivered and regression-tested in #51.

M1/M2 are playable; the other slots expose their canonical metadata and remain unavailable for departure until their own level issues supply level_scene. Unlocking a slot does not fabricate a level. Practice remains independent and available from the same menu.

Completing M10 replaces the title with an original spring teahouse illustration. This is keyed to the saved M10 result, not just unlocked_mission=11. The original SVG UI illustrations are separate from #78's narrative art delivery.

Validation and limitations: [QA record](../../qa-logs/campaign53/README.md).
