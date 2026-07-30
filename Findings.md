# Pro7Chords — Findings & Working Plan

Last updated: 2026-07-28
Purpose: This is the anchor document for the Pro7Chords project. Any new
Claude Code / Codex / agent session should read this FIRST before touching code.
It captures what we've confirmed about the ProPresenter file format, the
current status (what's fixed and what's open), and the working method.

---

## 1. What this project is

A macOS/Swift (Xcode) app that adds ChordPro-style chords to ProPresenter 7
`.pro` files without breaking the file. The app reads a `.pro`, lets the user
add/edit chords over the lyrics AND add chord charts to instrumental (lyric-less)
sections, and writes the chords back into the file's protobuf structure.

`.pro` files are protobuf. The project contains the full set of generated
`*.pb.swift` types for ProPresenter's proto definitions.

---

## 2. Confirmed facts about the ProPresenter file format

Verified by decoding real files with read-only diagnostics and comparing against
ProPresenter's own behavior. Treat these as ground truth.

### 2.1 Chords live on MASTERS, not arrangement repeats
- A `.pro` has a master/library layer (each section — Verse 1, Chorus, Bridge,
  Intro — defined ONCE) and an arrangement layer (playback order, which
  REFERENCES masters, possibly many times).
- Chord data attaches to the MASTER; all arrangement repeats inherit it.
- Edit chords on the master text element. Do NOT write onto flattened
  arrangement instances. (The old "Default" flat approach was wrong.)

### 2.2 Chord positions are PLAIN-TEXT character indices, NOT RTF offsets
- Each chord attribute has a `range` (start/end) indexing into the DECODED PLAIN
  TEXT, not the raw RTF string. Index counts ALL chars including spaces/newlines.
- Verified: "Alpha alpha alpha alpha", chord A start=0 lands on "A"; raw-RTF
  char at 0 is "{" (meaningless). Plain text wins.
- All old RTF-offset math (hardcoded ~490 base, "strokec3" anchoring) solved the
  wrong coordinate system. Deleted.

### 2.3 Two distinct chord modes exist
- Lyric mode: chords at plain-text indices over syllables.
- Instrumental/measure mode: sections with no lyrics (Intro, Interlude, Vamp).
  Chord attribute holds a measure/beat CHART, notation `|` = measure boundary,
  `\` = a beat. e.g. `| A \ \ \ | B \ \ \ |` = one measure of A (4 beats), then B.
- See §4 (Instrumental handling) — this case is now automated.

### 2.4 A file built with these conventions renders correctly
- The golden test file (`Test Chord Song_chords.pro`), written by the app with
  masters + plain-text positions, displays LYRIC chords correctly in ProPresenter,
  including multi-chord lines. This is the reference for correct lyric output.
- NOTE: the golden file's INSTRUMENTAL elements use empty-text/range 0-0 and do
  NOT display (see §4 — instrumental needs a text anchor). Only the lyric lines
  are the "known-good render" reference.

### 2.5 Protobuf type map (real names, verified against generated .pb.swift)
| Old code expected | Real type / member |
|---|---|
| `RVData_Action.SlideType.elements` | `...presentation.baseSlide.elements` (`[RVData_Slide.Element]`) |
| `RVData_UUID.uuidString` | `RVData_UUID.string` |
| `RVData_Graphics.TextElement` | `RVData_Graphics.Text` |
| `...TextElement.Attributes.CustomAttribute` | `...Text.Attributes.CustomAttribute` |
| `...TextElement.ChordProConfig` | `RVData_Graphics.Text.ChordPro` |
| `textElement.chordProConfig` | `textElement.chordPro` |

Full action→slide path: `action.actionTypeData` .slide → `slideType.slide`
.presentation → `presentationSlide.baseSlide.elements`. Section names live at
`cueGroup.group.name`; id at `cueGroup.group.uuid.string`. Swift: use
`CharacterSet.whitespacesAndNewlines` (must be qualified).
Note: ProPresenter has a native `RVData_Graphics.Text.ChordPro` type. Also a
slide-level `chord_chart` field exists but is an `RVData_URL` (reference), NOT
chord storage — ruled out (see §4).

### 2.6 (RESOLVED — describes OLD behavior, fixed in §2.12; kept for history)
The original ROOT bug: load walked `arrangements.first.groupIdentifiers`
(playback order) and decoded RTF→plain-text ONLY, never reading chord
attributes; the editor's chords came from regex on [C] bracket text, not real
customAttributes; and master section names were read then DISCARDED in favor of
SongSectionAnalyzer "Slide N" fallback labels. FIXED: load is now master-first
(loops `presentation.cueGroups`), reads real chord attributes, uses real section
names. See §2.12.

### 2.7 (CONFIRMED, then FIXED in §2.12) Whitespace trim desynced positions
FileManagerService trimmed leading whitespace from decoded text before applying
`range.start`, shifting every chord on a whitespace-leading line. (Charlie /
Verse 1 Slide 3: 3 leading spaces trimmed → chord landed on wrong char.) Second
trim in ChordEditorView affected save mapping. HARD REQUIREMENT (now enforced):
never trim leading/internal whitespace; all position math (read AND write) runs
against exact untrimmed decoded plain text. Whitespace carries chord timing.

### 2.8 (BASELINE — measured BEFORE the fix; now LOSSLESS YES per §2.12)
Round-trip harness: `Diagnostics/RoundTripHarness.swift`, run via
`bash Diagnostics/run_roundtrip_harness.sh "<file>"`. Loads → saves (no edits) →
diffs decoded protobuf. Never touches input (byte-for-byte confirmed). Output to
/tmp/pro7chords-roundtrip/.
Pre-fix baseline result was LOSSLESS: NO — section names SAME, arrangement SAME,
but plain-text/whitespace, chord positions, and RTF all DIFFERENT. Root cause:
load was master-aware but SAVE was still flat/arrangement-index, so text landed
on WRONG elements (Verse 2 got Chorus text, etc.). Fixed by writing back by
identity (master ID + element ID), not flat index. SAVE-CORRECT DEFINITION:
unedited round trip reports all five categories SAME — now achieved (§2.12).

### 2.9 Chord range has start AND end — do not recompute greedily
The pre-fix save WIDENED ranges (A 0-5 became A 0-12, stretched to next chord).
ProPresenter's ranges are TIGHT (tied to word/syllable). Greedy/overlapping
ranges are a likely cause of the original "only last chord displays" bug.
RULE: preserve original range.start/end read on load; don't recompute from
brackets. New-chord convention RESOLVED in §2.11 (start = bracket position,
end = short local span).

### 2.10 (RESOLVED) Structural "corruption" was a FALSE ALARM
A controlled harness run on native unedited Battle Belongs.pro round-tripped with
ZERO structural change (10 groups, 25 cues, 25 elements, all IDs preserved,
SHA-256 identical). The God Is Love restructuring seen earlier was Adam's manual
EDITS, not a save bug. Save does NOT restructure. Also established: bug #11 is
precisely "adding a chord regenerates that element's RTF instead of preserving
original bytes" — a no-edit round trip of a native file is fully lossless.
chord_chart safe (unchanged).

### 2.11 Chord ranges are SYLLABLE-PRECISE (ChordPro model)
ChordPro (verified chordpro.org / Wikipedia / spec) places a chord immediately
before the SYLLABLE it belongs to — chords deliberately fall mid-word
("be[E]longs" on "-longs"). Single-syllable words sit on the word. So ranges
that look "mid-word" are EXACT, not imprecise.
Range rule (Adam's call): the range marks the syllable the chord displays above —
short and local; end does NOT stretch to the next chord.
- New chords: start = exact bracket char index in UNTRIMMED text; end = short
  local span. Never snap to word boundaries; never shift.
- Existing chords: preserve original start/end as read.
Confirmed by shipping competitor ChordProEditor.com (same model; "cannot create
new slides").

### 2.12 SAVE FIX LANDED — round-trip lossless (2026-07-28)
The save fix (preserve original RTF byte-for-byte; untrimmed §2.2 positions;
short anchored ranges per §2.11, no widening; write by identity; no
restructuring) is implemented and validated. Harness on BOTH native Battle
Belongs and golden Test Chord Song: all 5 categories SAME, LOSSLESS YES, inputs
untouched.
RESOLVED by this fix: #11 (RTF regeneration), §2.7 (whitespace desync), §2.9
(range widening), and the original "only last chord displays" bug (all one root
cause: rebuild-instead-of-preserve). Save is no longer a corruption risk.
VERIFIED in ProPresenter (lyric lines and full instrumental workflow both
confirmed on-screen, 2026-07-28).

### 2.13 (RESOLVED) End-of-line degenerate range — fixed with clamp
An end-of-line chord after trailing spaces produced G 58-56 (start past end,
end < start, out of bounds) → ProPresenter dropped chords ("only last shows").
Fix in ProFileParser.swift (clampedRange / clampedRangeStart / shortLocalRange):
start clamped to last non-space char; end in [start+1, textLength]; end > start
always. Applied to new and (defensively) preserved ranges without altering valid
ones. Verified G 58-56 → G 55-56; both regression files stayed lossless; visually
confirmed all chords on the line now display in ProPresenter.

---

## 3. Status & backlog

### COMPLETED (this session, 2026-07-28)
- TIER 0: Build repaired — de-duplicated doubled ProFileParser.swift, fixed
  protobuf API drift in ProFileParser + FileManagerService, cleared CodeSign
  (.cstemp) phantom. Builds clean.
- [11] Save removes formatting — FIXED (RTF preserved byte-for-byte, §2.12).
- [1] Chord display issues in some files — RESOLVED (root causes were range
  widening §2.12 and end-of-line degenerate range §2.13).
- [ROOT] App read DEFAULT not MASTER layer — FIXED (master-first read; real
  names, real chord attributes, repeats collapsed — §2.12).
- End-of-line-after-whitespace chord overwrite (was "3.x") — FIXED (clamp §2.13).
- Instrumental chord automation — DONE (§4): auto-anchor, strip-on-open/
  add-on-save, verified end to end in ProPresenter.
- Blank instrumental slides now surface in editor (were completely missing) —
  FIXED (display path; untouched blanks still round-trip lossless).

### REMAINING OPEN BACKLOG

TIER 2 — Quick usability wins (small, self-contained)
- [10] File menu has no "Save" / "Save As".
- [5] Save success popup says "error" even when save succeeded (false failure).
- [6] Recent files do not open — causes an error.

TIER 3 — The "key" cluster (one coherent feature, do together)
- [3] File often on wrong key (app auto-guesses).
- [4] Cannot manually set the key.
- [2] Transpose button doesn't work (transposition is key-math; needs a correct
  key model — depends on 3 & 4).
- [9] On save, filename auto-appends "_chords". Preferred: put KEY in parens,
  e.g. `Song Name (G).pro`.

TIER 4 — Scope decisions (choices, not bugs)
- [8] "Analyze Progression" is unneeded — remove it.
- [7] "Library" button doesn't access a ProPresenter library. Decide: build real
  integration (significant) or remove for now.

STRUCTURAL — Folder consolidation (STILL OPEN, real liability)
- 3 nested project copies still exist; git repo is one folder too deep; no
  .gitignore. Pick the canonical (building) copy, move to ONE clean folder, put
  git at the correct level (wrapping .xcodeproj + source + tests), add a Swift/
  Xcode .gitignore. Deferred this session in favor of save/instrumental work.
  Safe junk removal (_trash move) and ProFileParser de-dup were DONE; this
  structural step was NOT. Worth doing before the project grows further.
- Snapshot safety net exists: `~/Desktop/Pro7Chords_SNAPSHOT_2026-07-24`.

---

## 4. Instrumental chord handling

### 4.z STATUS: CLOSED — verified end to end (2026-07-28)
Full workflow confirmed on native chordless Battle Belongs: instrumental
sections appear and are editable; user types `[| A \ \ \ | B \ \ \ |]` with no
manual anchor; app auto-adds the "." anchor on save; displays correctly on the
ProPresenter STAGE display; NOT on the audience screen; no effect on lyric lines;
"." not shown in editor on reopen. Detection + auto-anchor + strip-on-open/
add-on-save + boundary all working.

Mechanism (facts, verified in ProPresenter):
- chord_chart is a URL field, NOT chord storage — ruled out. Instrumental chords
  live in text-element customAttributes, same as lyric chords (chart is one
  attribute string, e.g. "| A \ \ \ | B \ \ \ |").
- Instrumental chords REQUIRE a text anchor: empty text ("") does NOT display;
  deleting the anchor char deletes the chords.
- The anchor is a "." at 12pt (\fs24), visible on STAGE display (fine), NOT on
  AUDIENCE display. Color/transparency does not hide it on stage (irrelevant —
  hiding on stage was never a requirement).
- Detection: a slide is instrumental when lyric text is blank ("") OR exactly ".".
- Entry: user types the whole chart as ONE bracketed token `[| ... |]`; app does
  NOT parse/subdivide measures.
- On OPEN: strip the "." anchor; show user only the bracketed chart.
- On SAVE: author the "." anchor into rtf_data using the exact captured 12pt
  template (byte-matching working files so instrumental lines round-trip
  lossless); store chart string as one chord attribute at range 0-1.
- BOUNDARY: this RTF-authoring path applies ONLY to instrumental lines; lyric
  lines keep §2.12 preserve-RTF-untouched.
Note: the golden Test Chord Song's instrumental elements use the OLD empty-text/
range 0-0 form and won't display until edited through the new path — not a bug,
just legacy state of that test file.

### 4.x Instrumental entry UX — core DONE, polish optional
The placeholder problem is SOLVED (§4.z): user types one bracketed token, app
manages the anchor. No "chord1 chord2" dummies (which is how competitor
ChordProEditor does it — worse). REMAINING (optional, future polish): an even
cleaner entry UX for measure charts if desired. Not urgent — current
bracketed-token entry works.

### 4.y Design note — chord placement past end of lyrics
After the §2.13 clamp, an end-of-line chord snaps to the last non-space char
(correct — can't anchor to empty trailing space). Adam noted he'd sometimes
prefer the chord further right, in the space after the word. That = placing a
chord where there's no lyric = an instrumental beat, which belongs to the
measure-chart mechanism (§4.z), NOT the chord-over-syllable path. Do not solve by
floating chords in trailing whitespace — wrong mechanism.

### 4.w UI design (LATER — for the eventual UI pass)
Editor should move from ONE flat text field (section markers, slide markers,
lyrics all editable together) to a STRUCTURED per-section layout: each section
name is a NON-EDITABLE header LABEL above a text-entry box containing only that
section's content. (Ref: Adam's screenshot — "Chorus" as a header above a
lyrics box.) This makes chord-in-header insertion structurally impossible
(replaces any need for a header guardrail) and likely simplifies cursor
tracking (each block its own field). Deferred to the UI update; cursor-insert
fix in the meantime has no guardrail.

---

## 5. Working method (lessons learned)

- Establish ground truth before writing code. Months were lost guessing at the
  coordinate system. Verify every format assumption against a real file with a
  read-only diagnostic before code depends on it. (This session it repeatedly
  paid off: the structural-corruption false alarm, the chord_chart dead end, the
  syllable-precision correction, the "does empty-text display" check.)
- The round-trip harness turns "is save correct?" from a guess into a
  measurement. Run it after every save-path change until all 5 categories are
  SAME. It caught the element-scramble and proved every subsequent fix.
- Prefer agent edits over copy-paste. The doubled ProFileParser.swift came from
  pasting a new version onto the end instead of replacing. Let the agent edit in
  place.
- Validate against the golden file. After any save change, diff output against
  `Test Chord Song_chords.pro` (lyric lines) via the harness.

---

## 6. User documentation / explainer-video notes (not code)
Things purchasers need to know, to cover in the explainer video / FAQ:
- Instrumental sections = BLANK slides (no lyrics). In a song file a blank slide
  means instrumental, not silence. If a stray blank exists, clean it up in the
  presentation. The app surfaces all blank slides for editing.
- Enabling CHORDS on the ProPresenter stage display (stage display layout setup;
  same mechanism MultiTracks/ChordProEditor use).
- Enabling the VERTICAL SECTION LABEL on the stage display (Verse 1 / Chorus /
  Interlude shown alongside chords, so musicians track position through repeats).
  Driven by ProPresenter from master/cueGroup section names — which this app
  preserves. Likely no app code needed; it's a stage-display config the user
  enables.
