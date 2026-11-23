# Test fixture provenance

| File | Source | Version | SPDX | How |
|------|--------|---------|------|-----|
| `mt0-pitches.sexp` | computed with music21 (MIDI numbers) | music21 10.5.2 | MIT (generated facts; music21 itself is BSD-3-Clause) | `uv run --with music21==10.5.2 python -I tests/fixtures/generate-mt0.py` |
| `mt0-intervals.sexp` | computed with music21 (`interval.Interval`: generic, semitones, name) | music21 10.5.2 | MIT (generated facts) | same script |
| `mt0-intervals-out-of-range.sexp` | as above; rows music21 names beyond AA/dd, or can't name (`nil`) | music21 10.5.2 | MIT (generated facts) | same script |

| `mt2-keys.sexp` | computed with music21 (`Key.sharps`; `MajorScale`, `MinorScale`, `HarmonicMinorScale`, `MelodicMinorScale` ascending, `pitchFromDegree`) | music21 10.5.2 | MIT (generated facts) | `uv run --with music21==10.5.2 python -I tests/fixtures/generate-mt2.py` |
| `mt2-degrees.sexp` | computed with music21 (`Scale.getScaleDegreeAndAccidentalFromPitch`), 35 pitch classes per key and variant | music21 10.5.2 | MIT (generated facts) | same script |
| `mt2-roman.sexp` | computed with music21 (`roman.RomanNumeral(figure, key)`: root, bass, inversion, pitches; the chord's `commonName` for the quality; `isMixture`; `romanNumeralFromChord` for reference) | music21 10.5.2 | MIT (generated facts) | same script |

The generator lives next to the fixtures. Regenerate rather than hand-edit. Line-of-fifths positions are computed from their definition (F -1 … B 5, ±7 per accidental), not taken from music21.

## MT2: where our conventions differ from music21

Each `mt2-roman.sexp` row gives our text, the music21 figure that names the same chord, and our literal reading (what `roman-for` returns without `:applied-to`). The generator stops if music21's chord doesn't have the quality the row expects, or if the literal figure names different pitches.

- **Sevenths name their quality.** music21 reads a bare `7` as the key's diatonic seventh, so its `I7` is C E G B in C major and its `VI7` is F A C E in A minor, and it ignores an `M` (its `IM7` in A minor is A C♯ E G). In our text the figure is explicit and key-independent: `I7` and `V7` are dominant sevenths in every key, `IM7`, `IVM7`, `VIM7` are major sevenths. A dominant seventh on I needs `Ib7` or `I42[b7]` in music21.
- **`romanNumeralFromChord` is not our `roman-for`.** It never returns an applied numeral; our `roman-for` is literal too, and gives an applied reading only when asked (`:applied-to`). In minor keys it labels A♭ C E♭ in C minor `bVI` and B♭ D F `bVII`, figures that music21's own `RomanNumeral` reads as A𝄫 and B𝄫; we write `VI` and `VII`. For chromatic sevenths it writes interval figures (`II75#3`, `V75#3` for V7 in minor, `Ib753`, `viio#653`); we write `II7`, `V7`, `I7`, `viio65`. For D♯ F♯ A C in A minor it writes `#ivø7` (a diminished seventh, which its parser reads as half-diminished); we write `#ivo7`. The `m21-from-chord` column records its output for reference only.
- **Minor-key 6th and 7th degrees follow music21's `RomanNumeral`.** A lowercase numeral on degree 6 or 7 sits on the raised degree (vi, vi°, vii°, vii°7: A and B in C minor); an uppercase one on the natural degree (VI, VII: A♭, B♭). A prefix accidental applies after that, so `#vii°7` in C minor is B♯ and `bVI` is A𝄫 (music21 agrees).
- **Mixture compares whole chords.** music21's `isMixture` enumerates triad cases (a scale degree plus a triad quality) and ignores the seventh. Our `roman-mixture-p` asks whether the chord, seventh included, is diatonic in the parallel key but not in the key. The two agree on every triad and on every non-applied fixture row. They differ on sevenths whose seventh is chromatic in both modes: A♭ C E♭ G♭ in C major and C E G B♭ in C minor are mixture for music21, not for us (`mixture` test, last two rows). music21 judges an applied numeral as if it stood in the home key; we judge it in the tonicized key, so the fixture compares only non-applied rows.
- **Major keys have no minor-scale variants.** `scale-degrees` with `:harmonic` or `:melodic` in a major key returns the major scale; `mt2-keys.sexp` repeats it in those columns.
- **Text.** Key names print an uppercase tonic (`F# minor`, where music21 prints `f# minor`). ASCII Roman numerals print `o` and `/o` (RomanText style), Unicode `°` and `ø`; music21 prints `o` and `ø`.

Hand-written rows in `tests/mt2-test.lisp` were cross-checked against an independent reference implementation of the rules in `src/key.lisp` and `src/roman.lisp`, and, where music21 can express them (theoretical-key scales, applied chords, literal readings, mixture), against music21.
