# Test fixture provenance

| File | Source | Version | SPDX | How |
|------|--------|---------|------|-----|
| `mt0-pitches.sexp` | computed with music21 (MIDI numbers) | music21 10.5.2 | MIT (generated facts; music21 itself is BSD-3-Clause) | `uv run --with music21==10.5.2 python -I tests/fixtures/generate-mt0.py` |
| `mt0-intervals.sexp` | computed with music21 (`interval.Interval`: generic, semitones, name) | music21 10.5.2 | MIT (generated facts) | same script |
| `mt0-intervals-out-of-range.sexp` | as above; rows music21 names beyond AA/dd, or can't name (`nil`) | music21 10.5.2 | MIT (generated facts) | same script |

The generator lives next to the fixtures. Regenerate rather than hand-edit. Line-of-fifths positions are computed from their definition (F -1 … B 5, ±7 per accidental), not taken from music21.
