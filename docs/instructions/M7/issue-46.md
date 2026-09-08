# Audio implementation

Keep the existing aggregate alert semantics. Add bounded real playback: near-silent
night ambience, unease flute layer, combat percussion layer and short positional
SE. Crossfade layers without restarting them, route music to BGM and effects to
SE, respect settings and pause, and duck ambience during the existing short
assassination sequence. Add material identity to audio metadata without changing
AI noise radius or dispatch. Successful tool actions request an audible cue
without inventing an enemy-hearing event.

Use reproducible project-authored synthesis with no external samples. Record the
source, generator and limitations in the license ledger. TDD checks real streams,
crossfade endpoints, buses, material cues and bounded voices. Listen to/render a
native mix and inspect clipping. Main agent owns implementation and review.
