# Issue 50 — Cutscene Player

Implement docs/08 §2.5 and docs/09 §6 without changing campaign progression.
Provide `LineData` (speaker_key, text_key, NARRATION/DIALOGUE/INNER),
`SlideData` (image, typed lines, ambience, duration_auto), and `CutsceneData`
(id, typed slides, skippable). All displayed copy comes from data/text/ja.csv.

`CutscenePlayer` is a reusable full-rect Control, not an autoload. After adding
it to the scene, `play(data, reduced_mode=false)->bool` starts a valid resource.
Invalid/empty resources fail before touching pause or input ownership. Completion
emits `finished(id, skipped)` once, stops ambience, and restores previous tree
pause and mouse state. Removing an active player performs the same cleanup.
Expose advance(), set_auto(bool), request_skip(), confirm_skip(bool) for hosts.

Still images cover the viewport. Normal mode pans and zooms over the slide's
8–15 second authored duration; reduced mode keeps one background still, using
the same subtitle/dialogue renderer. Text occupies the bottom quarter, with
white narration, named dialogue and pale slanted inner speech. Scrolling keeps
long text readable at 640×360. Controls remain inside viewport bounds.
Accept advances one line; holding accept repeats after a delay. Auto divides
slide duration over its lines. Escape asks before skipping, including on first
view. Confirmation suspends progress and cancellation resumes the same line.
An unskippable resource does not offer skip. Ambient audio follows each slide.

Add an explicitly illustrative sample using existing registered temporary art
and CSV copy; no campaign script or production illustration is implied.
A standalone scene supports replay after completion and returning to Main.

Use behavior TDD: absent-resource red, schema/state/input/timing/ownership tests,
then focused/full Godot 4.3 validation. Capture native rendered narration,
dialogue, inner speech, skip confirmation and compact layout, exercise actual
input and completion/replay. Self-review before commit includes resource
validation, event ownership, ambient cleanup, layout, personal paths/secrets.
Keep raw available evidence outside tracked source. Parent publishes the PR.
