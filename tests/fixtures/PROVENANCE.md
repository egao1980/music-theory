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

| `mt3-symbols.sexp` | computed with music21 (`harmony.ChordSymbol` from a per-row recipe: a music21 figure, or `ChordSymbol(root=, kind=)` plus `ChordStepModification`s; `NoChord` for N.C.): root, bass, spelled tones without the bass; and music21's own reading of our text, for reference | music21 10.5.2 | MIT (generated facts) | `uv run --with music21==10.5.2 python -I tests/fixtures/generate-mt3.py` |
| `mt3-kinds.sexp` | computed with music21 (`ChordSymbol(root=, kind=)` for every MusicXML 4.0 `<kind>` on five roots) | music21 10.5.2 | MIT (generated facts) | same script |
| `mt3-transpose.sexp` | computed with music21 (`ChordSymbol.transpose` by eight intervals and by the interval between two keys' tonics) | music21 10.5.2 | MIT (generated facts) | same script |

## MT3: where our conventions differ from music21

music21's chord-symbol parser reads another text convention, so each `mt3-symbols.sexp` row names its chord with a recipe in music21's own terms, and music21 realises the recipe. The last column, `m21-direct`, is what music21's parser makes of our text when only the root and bass accidentals are translated into its notation. The generator stops when that reading is a different chord on a row not listed below. Rows where it is an error are expected: music21 has no reading for the notation.

- **`-` is minor, never a flat** (as in `parse-pitch`). music21 reads `-` as a flat, so its `C-` is C♭ major, `C-7` C♭7, `E-9` E♭9, `C-add9` C♭(add9).
- **Flats and Unicode.** We read `b`, `bb`, `x` and `♭ ♯ 𝄫 𝄪` in the root, bass and alterations. music21 reads only `-` and `#` in a root (`Bb7` is an error for it), and no Unicode accidental anywhere.
- **`dim`, `o`, `°` depend on the dialect.** music21 reads `dim` and `o` as the diminished triad, our `:classical` reading; in `:pop` and `:jazz` they are the diminished seventh, so `Cdim` is C E♭ G♭ B𝄫 there. music21 does not read `°` at all.
- **Words music21 lacks.** We read `Δ △ ^` (major seventh), a bare `ø` or `Ø` (half-diminished seventh), `-Δ`, `mΔ`, `m(maj7)`, `mmaj7`, `+maj7`, `+Δ7`, `maj9`, `maj11`, `maj13`, `Maj`, `mi`, `M6`, `maj6`, `6/9`, `m6/9`, `9sus4`, `13sus4`, `7sus2`, `no3`, `7alt`, `+5`/`-9`-style alterations, parenthesised modifier groups, and `N.C.`/`NC`/`N.C`. music21 signals an error for each.
- **`7alt`** is our convention: the dominant seventh with ♭9 ♯9 ♯11 ♭13 and no fifth (C E B♭ D♭ D♯ F♯ A♭).
- **`C69`**: music21 reads it but realises C A D, dropping the third and fifth. Ours is the 6/9 chord C E G A D.
- **`C13b9`, `C13#11`**: music21 keeps the natural ninth or eleventh, because it ignores an alteration of a degree the kind already has. We alter it: C13♯11 has F♯ and no F.
- **The fifth folds into the quality.** music21 keeps `Cm7b5` as a minor seventh with an altered fifth, and `C7#5` as a dominant seventh with ♯5. We read them as the half-diminished and augmented sevenths (same pitches). `C7(b5)` and `C7(b5,#5)` do not fold.
- **Neapolitan.** music21's `Neapolitan` kind realises 1 ♭2 3 ♭5 (C D♭ E G♭), which is not a Neapolitan chord. Our row in `+musicxml-kinds+` is the major triad on its own root; `mt3-kinds.sexp` marks the row `:differs`.
- **The functional sixths and Tristan follow music21's root convention.** MusicXML gives these kinds no intervals. Like music21, we put the root on the key's tonic, so the Italian sixth of C minor (C F♯ A♭) has the root C.
- **The slash bass is not a chord tone.** music21's pitches include the bass (`C/F#` is F♯ C E G). Our `chord-tones` gives C E G, and the F♯ is the `bass` slot. The fixture's tones leave the bass out.
- **`C13` keeps its eleventh** (C E G B♭ D F A), as in music21 and MusicXML's `dominant-13th`. Leaving the eleventh out is a choice of `chord-essential-tones`, from the priority rows.

Hand-written rows in `tests/mt3-test.lisp` were cross-checked against an independent reference implementation of the rules in `src/chord-symbol.lisp` and `src/chord-tones.lisp`. That implementation also realised every fixture row and agreed with music21 on each.

| `mt4-melodies.sexp` | 50 public-domain melodies re-encoded by us (the note lists live in `generate-mt4.py`); music21 checks that each spelling survives its `Pitch` and gives the MIDI numbers | music21 10.5.2 | MIT (our encodings of public-domain tunes) | `uv run --with music21==10.5.2 python -I tests/fixtures/generate-mt4.py` |
| `mt4-key-detection.sexp` | computed with music21 (`analysis.discrete.KrumhanslKessler`, `TemperleyKostkaPayne`, `AardenEssen`: `getSolution` and its `alternateInterpretations`) on each melody's duration-weighted stream | music21 10.5.2 | MIT (generated facts) | same script |
| `mt4-histograms.sexp` | the same three analyses on nine synthetic pitch-class histograms | music21 10.5.2 | MIT (generated facts) | same script |
| `mt4-profiles.sexp` | music21's `getWeights` for the three profiles, as exact rationals of its decimals | music21 10.5.2 | MIT (published numbers, see below) | same script |
| `mt4-transposed.sexp` | computed with music21 (`Stream.transpose`) for every melody, to the keys five fifths above and below its own | music21 10.5.2 | MIT (generated facts) | same script |

## MT4: the melodies

The brief asks for public-domain melodies re-encoded by us. music21's bundled corpus could not be the source: its `corpus/license.txt` says the encodings are distributed with the encoders' permission and some carry non-commercial or other terms, `essenFolksong/license.txt` grants non-commercial use only, and the O'Neill and Ryan's Mammoth ABC files name individual transcribers without a license. None of that can be relicensed under MIT. So the 50 melodies were typed from memory as plain note lists: folk tunes, hymns, carols and themes by composers who died long ago (Bach, Mozart, Beethoven, Chopin, Tchaikovsky, Joplin, Satie and others; each row in `generate-mt4.py` names its source). An encoding may differ from a printed edition in a note or a rhythm. What the tests rely on is our spelling and key, which are the notation we chose. Modal tunes carry the key of their usual signature and final (Scarborough Fair and Drunken Sailor are Dorian, written as E minor with C♯ and D minor with B♮). Several tunes are written in other keys than the familiar one (Amazing Grace in E♭, Oh! Susanna in G♭, Good Morning to All in E) so that remote keys are represented. Durations only weight the histograms.

## MT4: key profiles (published numbers)

`+key-profiles+` stores each published weight as an integer times a power of ten (correlation does not change under scaling); `key-profiles-match-music21` checks that every one equals music21's decimal exactly.

- **Krumhansl–Kessler.** Krumhansl, C. L. and Kessler, E. J. (1982), "Tracing the dynamic changes in perceived tonal organization in a spatial representation of musical keys", *Psychological Review* 89(4), 334–368; also Krumhansl (1990), *Cognitive Foundations of Musical Pitch*, Oxford University Press. music21 `KrumhanslKessler` (= `KrumhanslSchmuckler`).
- **Temperley.** Temperley, D. (2007), *Music and Probability*, MIT Press: the profiles of the Kostka–Payne corpus. music21 `TemperleyKostkaPayne`.
- **Aarden.** Aarden, B. (2003), *Dynamic Melodic Expectancy*, PhD dissertation, Ohio State University: the Essen folksong profiles. music21 `AardenEssen`, whose documentation notes that the origin of the minor weights is uncertain.

music21 takes all three tables from Craig Sapp's Humdrum `keycor` documentation.

## MT4: where our conventions differ from music21

- **Key spelling.** music21 names a detected key after its default pitch spelling, so it can return C♯ major or G♯ major (eight sharps, flipped to A♭). `detect-key` ranks the 24 keys of `+detect-key-candidates+` (fewest accidentals; F♯ major and E♭ minor at six). The generator maps music21's keys onto those by tonic pitch class and mode, and the accuracy tests compare keys the same way (Oh! Susanna is notated in G♭ major; detection names F♯ major).
- **No evidence.** For a histogram whose 12 cells are equal music21 reports a correlation of 0.0 for every key; `detect-key` returns NIL.
- **Ties.** music21 sorts the floating-point correlations. `detect-key` ranks exactly (rational arithmetic) and keeps the candidate order on an exact tie. The generator ranks every row exactly too and stops unless music21's order agrees everywhere outside exact ties. The only exact ties are in the `c-only` histogram with the Aarden profile, whose weights 0.145624 and 0.702494 each appear twice.
- **Spelling.** music21's `pitch.simplifyMultipleEnharmonics` spells a set of pitches to maximise consonance, greedily from the left. It is used below only as a baseline. The fixtures' spellings are our notation, and, for `mt4-transposed.sexp`, music21's transposition of it.

## MT4: calibration

Spelling accuracy, notes spelled as notated (1699 notes in the 50 melodies; 3398 in the 100 transposed copies):

| Speller | melodies, with the key | melodies, without | transposed, with the key |
|---------|-----------------------:|------------------:|-------------------------:|
| music21 `simplifyMultipleEnharmonics`, windows of 8 notes, `keyContext` the key | 98.35% | 94.23% | 97.85% |
| music-spelling `pitch-spell`, default penalties, the key signature as its starting parsimony table | 97.94% | 96.35% | 92.05% |
| the same with `:parsimony 3` (its best setting here) | 99.76% | — | 97.26% |
| the rules of `src/spell.lisp` (independent reference implementation) | 100% | 100% | 100% |

The music21 figures are printed by `generate-mt4.py`. The music-spelling figures come from a scratch run of its unmodified `package.lisp` and `pitch-spelling.lisp` (see below). The brief's thresholds, 98% with a key and 95% without, are kept: they are the level the two existing spellers reach. The rules were developed with these melodies in view, so their 100% is in-sample. Without a key the transposed copies score 90.41%, because F♯ major and G♭ major (and the like) sound alike and detection picks one spelling; that set is tested with the key only.

Key detection, top-1 and top-2 over the 50 melodies (a key counts when tonic pitch class and mode match):

| Profile | top-1 | top-2 |
|---------|------:|------:|
| Krumhansl–Kessler | 39 (78%) | 47 (94%) |
| Temperley | 45 (90%) | 49 (98%) |
| Aarden | 41 (82%) | 48 (96%) |

`detect-key` reproduces music21's rankings exactly, so it scores exactly these figures, and the thresholds in `detect-key-accuracy` are these counts. The brief asked for 85% and 95%; on short monophonic melodies only the Temperley profile reaches that. Krumhansl–Kessler's misses are the relative minor (Jingle Bells, Canon in D), the dominant or subdominant key (Take Me Out, Promenade, Bach's Fugue in G minor), the parallel mode (the D minor Toccata opening) and a Dorian tune read as major (Drunken Sailor).

## MT4: music-spelling, evaluated for an unmodified import

[music-spelling](https://github.com/ntrocado/music-spelling) at commit `c158400` (Apache-2.0). Its `package.lisp` and `pitch-spelling.lisp` were loaded unmodified with alexandria (its `text-notation.lisp` also needs parse-float and cl-ppcre) and run on the MT4 melodies. Findings:

- **Key awareness only at the start.** The one way to pass a key is the starting parsimony table (letter → accidental). `pitch-spell` spells blocks of `:split` notes (9) by exhaustive search, and each later block takes its table from the previous block's notes, so a key letter missing from the first block is forgotten. In remote keys it scores 92.05% with the default penalties and 97.26% at best (`:parsimony 3`).
- **A single note ignores everything.** A one-note block returns the first candidate whatever the penalties and table: `(pitch-spell '(61) :parsimony <D♭ major>)` is C♯4. `spell-midi midi :key` cannot be a wrapper.
- **No per-note score.** It returns the spellings and one total penalty; the brief's per-note ambiguity and the `ambiguous-spelling` hook would have to be rebuilt from its internals.
- **It fails on a whole class of inputs.** When the last block holds one note (length ≡ 1 mod 9, above 9), `%pitch-spell` returns no score and `pitch-spell` adds NIL to a float: a TYPE-ERROR. 6 of the 50 melodies and 12 of the 100 transposed copies hit it; the figures above rerun those with `:split 8`.
- **Global state.** Parsimony lives in a closure over one hash table, and `interval-quality` memoizes into a global hash table keyed by fresh `note` instances, which grows with every call. Neither is reentrant or thread-safe, and the library uses single floats and CLOS objects, where this repo uses immutable structs and exact numbers.

Its tunable penalties therefore cannot express key-aware spelling unmodified, so MT4 specifies its own line-of-fifths rules and imports nothing. Its ideas remain as rules S3 (parsimony: a chromatic note keeps its accidental), S4 (direction: a semitone resolution is diatonic) and S5 (no augmented or diminished interval with the note before).
