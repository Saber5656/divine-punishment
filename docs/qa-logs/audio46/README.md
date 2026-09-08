# Layered audio and positional SE

AudioDirector preserves the existing aggregate alert tier and now drives real
streams. Unease and combat layers crossfade over 0.8 seconds without restarting
playback. Normal play has only restrained night ambience. Music uses BGM; ambient,
short effects and stingers use SE, following existing volume settings. The existing
assassination hooks duck the background, play one beat and restore ambience.

Positional effects use at most 24 reusable voices. Footsteps carry a separate
material cue before the original noise dispatch. Enemy hearing kind/radius and
filtering are unchanged. Successful tool uses request an audio cue separately
from impact noise. Door, landing, combat, bell and water cues are also available.

All source WAVs are original deterministic synthesis with metadata in the license
ledger. Flute-like/percussive tones are synthesized, not recorded instruments.
Loop endpoint tests caught discontinuities and now pass after correction.

TDD: all three playback/material/pool regressions initially failed; after adding
real playback they pass. Native mixer capture contains music, individual material
and tool cues, a 24-voice request burst, and assassination duck/beat/restore.
The separate effect-only segment has peak 0.03229; the complete capture has peak
0.15622 and RMS 0.02054 (11.505 seconds), with no clipping. This is an actual mixer
recording, not a claim of human listening-panel approval. The WAV and full logs
are preserved in the task Vault/evidence.

Self-review covers bus ownership, finite/known cue validation, bounded voices,
shared immutable streams, loop continuity, unchanged noise propagation and
private paths/secrets. Full-suite results and published commit are tracked by
the delivery record.
