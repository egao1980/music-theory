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
| `mt51-chromatic.sexp` | 57 chromatic lines from public-domain works, re-encoded by us (the note lists live in `generate-mt51.py`), 8 of them copies in remote keys; music21 checks every spelling, gives the MIDI numbers and transposes the copies | music21 10.5.2 | MIT (our encodings of public-domain works; generated facts) | `uv run --with music21==10.5.2 python -I tests/fixtures/generate-mt51.py` |

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

## 0.5.1: chromatic lines (music-theory#14)

In 0.5.0 a chromatic semitone step was spelled as a diatonic semitone even when that put a letter far outside the key: G minor 55 54 53 52 gave G3 F#3 F3 Fb3, D major 62 61 60 gave D4 C#4 B#3. The 50 melodies have no line of that kind. `mt51-chromatic.sexp` is a corpus of such lines, with the composer's spelling as the ground truth.

**Sources.** Three kinds, all public domain:

- *Famous passages*, typed from the scores: the lament grounds of Purcell (*Dido and Aeneas*, "When I am laid in earth"), Bach (Crucifixus of the B minor Mass, Cantata BWV 12) and Beethoven (32 Variations WoO 80), the opening of Bach's royal theme (*Musical Offering*), the opening of Bizet's Habanera, and the first two phrases of the *Tristan* Prelude (cellos and oboe separately). Of the Crucifixus, BWV 12 and WoO 80 grounds only the chromatic fourth is encoded.
- *Bach chorale excerpts*, chosen by a fixed rule so that the corpus is not picked by the result. A search of the Bach chorales in music21's corpus (one voice at a time, repeated notes merged) listed every run of two or more semitone steps in one direction, three notes either side, and every chromatic neighbour (a note a semitone from the notes either side of it and outside the key's natural, harmonic and melodic scales), four notes either side. By BWV number, the lines are: the first five runs in major through ^4 ♯4 ^5 and the first five through ^1 ^7 ♭7; the first six minor-key runs ascending through both the 6th and the 7th degree; every descending one (eight); every other descending run of three or more semitones in minor (nine, "lament"); and the first three neighbours in major and in minor. Score variants (`-sc`, `-inst`) and an excerpt that doubles one already taken (BWV 8.6's continuo) are left out. The key is the chorale's. `generate-mt51.py --search` prints what the search finds. Only the pitch names of a few notes of Bach's score are used, typed into `generate-mt51.py`; nothing of an encoding is copied (see MT4: the melodies, on why music21's corpus cannot be a source of encodings).
- *Remote keys*: four minor lines moved to E♭ minor and four major lines to F♯ major by music21's exact transposition (the interval from tonic to tonic, the letter moving at most three steps, as for `mt4-transposed.sexp`).

Each line, its source and its notated spelling (the last column lists the notes the amended rules spell otherwise, notated → spelled):

| id | key | source | notated spelling | misses (0.5.1 rules) |
|----|-----|--------|------------------|------------------|
| `purcell-laid-in-earth` | G minor | Purcell, Dido and Aeneas (1689), 'When I am laid in earth', ground bass | G3 F#3 F3 E3 Eb3 D3 Bb2 C3 D3 G2 |  |
| `bach-crucifixus` | E minor | Bach, Mass in B minor BWV 232, Crucifixus, ground bass (chromatic fourth) | E3 D#3 D3 C#3 C3 B2 |  |
| `bach-weinen-klagen` | F minor | Bach, Cantata BWV 12 (1714), 'Weinen, Klagen, Sorgen, Zagen', ground bass (chromatic fourth) | F3 E3 Eb3 D3 Db3 C3 |  |
| `beethoven-woo80` | C minor | Beethoven, 32 Variations in C minor WoO 80 (1806), theme, bass | C3 B2 Bb2 A2 Ab2 G2 |  |
| `bach-royal-theme` | C minor | Bach, Musical Offering BWV 1079 (1747), the royal theme, opening | C4 Eb4 G4 Ab4 B3 G4 F#4 F4 E4 Eb4 D4 | F#4 → Gb4, E4 → Fb4 |
| `bizet-habanera` | D minor | Bizet, Carmen (1875), Habanera, 'L'amour est un oiseau rebelle', opening | D5 C#5 C5 B4 Bb4 A4 |  |
| `wagner-tristan-cello-1` | A minor | Wagner, Tristan und Isolde (1865), Prelude, bars 1-2, cellos | A3 F4 E4 D#4 |  |
| `wagner-tristan-oboe-1` | A minor | Wagner, Tristan und Isolde, Prelude, bars 2-3, oboe | G#4 A4 A#4 B4 |  |
| `wagner-tristan-cello-2` | A minor | Wagner, Tristan und Isolde, Prelude, bars 5-6, cellos | C4 Ab4 G4 F#4 | Ab4 → G#4 |
| `wagner-tristan-oboe-2` | A minor | Wagner, Tristan und Isolde, Prelude, bars 6-7, oboe | B4 C5 C#5 D5 |  |
| `bwv8.6-bass-m15` | E major | Bach, chorale BWV 8.6, bass, m. 15 | G#3 D#3 E3 A2 A#2 B2 E3 |  |
| `bwv12.7-bass-m9` | Bb major | Bach, chorale BWV 12.7, bass, m. 9 | F3 Bb2 Bb3 Eb3 E3 F3 Eb3 D3 Eb3 |  |
| `bwv17.7-bass-m31` | A major | Bach, chorale BWV 17.7, bass, m. 31 | F#3 E3 B2 C#3 D3 D#3 E3 E#3 F#3 G#3 A3 E3 |  |
| `bwv24.6-bass-m13` | F major | Bach, chorale BWV 24.6, bass, m. 13 | E3 D3 C3 Bb2 B2 C3 F3 |  |
| `bwv25.6-bass-m9` | C major | Bach, chorale BWV 25.6, bass, m. 9 | C4 C3 D3 E3 F3 F#3 G3 G#3 A3 G3 C3 D3 |  |
| `bwv20.11-bass-m6` | F major | Bach, chorale BWV 20.11, bass, m. 6 | Bb2 C3 F2 F3 E3 Eb3 D3 C#3 D3 G2 A2 |  |
| `bwv41.6-continuo-m1` | C major | Bach, chorale BWV 41.6, continuo, m. 1 | C3 C4 B3 Bb3 A3 G3 F3 Bb3 |  |
| `bwv60.5-bass-m6` | A major | Bach, chorale BWV 60.5, bass, m. 6 | B3 B2 E3 A3 G#3 G3 F#3 B2 E3 F#3 |  |
| `bwv60.5-bass-m15` | A major | Bach, chorale BWV 60.5, bass, m. 15 | A3 A2 E3 A3 G#3 G3 F#3 F3 E3 D#3 E3 G#3 A3 |  |
| `bwv127.5-alto-m10` | F major | Bach, chorale BWV 127.5, alto, m. 10 | Eb4 D4 E4 F4 E4 Eb4 D4 Eb4 F4 Eb4 |  |
| `bwv40.6-bass-m13` | D minor | Bach, chorale BWV 40.6, bass, m. 13 | A2 Bb2 A2 B2 C3 C#3 D3 G2 G3 F3 |  |
| `bwv108.6-bass-m12` | B minor | Bach, chorale BWV 108.6, bass, m. 12 | D3 D#3 E3 F#3 G3 G#3 A3 A#3 B3 G3 E3 C#3 |  |
| `bwv153.1-bass-m9` | E minor | Bach, chorale BWV 153.1, bass, m. 9 | F3 E3 D3 C#3 D3 D#3 E3 |  |
| `bwv153.5-bass-m11` | A minor | Bach, chorale BWV 153.5, bass, m. 11 | C3 D3 E3 F#3 G3 G#3 A3 E3 |  |
| `bwv161.6-alto-m9` | A minor | Bach, chorale BWV 161.6, alto, m. 9 | E4 D4 E4 F#4 G4 G#4 A4 A3 E4 C#4 |  |
| `bwv161.6-bass-m11` | A minor | Bach, chorale BWV 161.6, bass, m. 11 | D3 A2 G2 F2 F#2 G2 G#2 A2 E2 |  |
| `bwv120.6-tenor-m2` | B minor | Bach, chorale BWV 120.6, tenor, m. 2 | F#4 C#4 D#4 E4 D#4 D4 C#4 B3 A3 D4 |  |
| `bwv245.15-alto-m7` | A minor | Bach, chorale BWV 245.15, alto, m. 7 | D4 C#4 D4 E4 Eb4 D4 C#4 D4 E4 F#4 |  |
| `bwv245.17-tenor-m7` | A minor | Bach, chorale BWV 245.17, tenor, m. 7 | E4 F#4 E4 C4 B3 Bb3 A3 C4 B3 A3 |  |
| `bwv278-alto-m7` | E minor | Bach, chorale BWV 278, alto, m. 7 | A4 B4 G#4 C#5 C5 B4 A#4 F#4 G4 F#4 |  |
| `bwv289-bass-m5` | E minor | Bach, chorale BWV 289, bass, m. 5 | E2 E3 A2 A3 G#3 G3 F#3 E3 F#3 B2 | G#3 → Ab3 |
| `bwv295-alto-m4` | D minor | Bach, chorale BWV 295, alto, m. 4 | G4 F#4 G4 F4 E4 Eb4 D4 E4 F4 G4 |  |
| `bwv311-tenor-m5` | B minor | Bach, chorale BWV 311, tenor, m. 5 | E4 A3 B3 C4 B3 A#3 A3 B3 A3 G3 |  |
| `bwv328-alto-m33` | A minor | Bach, chorale BWV 328, alto, m. 33 | E4 F4 E4 D4 C#4 C4 B3 C4 D4 E4 | C#4 → Db4 |
| `bwv421-tenor-m1` | A minor | Bach, chorale BWV 421, tenor, m. 1 | D4 E4 A3 B3 Bb3 A3 G#3 A3 C4 B3 |  |
| `bwv144.6-bass-m8` | B minor | Bach, chorale BWV 144.6, bass, m. 8 | B2 E3 A2 A3 G#3 G3 F#3 E3 D3 C#3 |  |
| `bwv168.6-alto-m4` | B minor | Bach, chorale BWV 168.6, alto, m. 4 | F#4 C#5 A#4 B4 A#4 A4 G#4 A4 B4 A4 |  |
| `bwv244.25-bass-m11` | B minor | Bach, chorale BWV 244.25, bass, m. 11 | D3 F#3 G#3 A3 G#3 G3 F#3 E#3 F#3 B2 |  |
| `bwv288-bass-m5` | A minor | Bach, chorale BWV 288, bass, m. 5 | A2 D3 D4 G#3 G3 F#3 F3 E3 D3 E3 A2 |  |
| `bwv312-alto-m9` | A minor | Bach, chorale BWV 312, alto, m. 9 | D4 C4 E4 A4 G#4 G4 F#4 G4 F4 E4 |  |
| `bwv331-bass-m1` | A minor | Bach, chorale BWV 331, bass, m. 1 | A2 A3 G3 F#3 F3 E3 F3 D3 E3 |  |
| `bwv337-alto-m4` | A minor | Bach, chorale BWV 337, alto, m. 4 | E4 F#4 G#4 A4 G#4 G4 F#4 G4 A4 G4 |  |
| `bwv434-bass-m3` | A minor | Bach, chorale BWV 434, bass, m. 3 | E3 A3 B3 A3 G#3 G3 F#3 F3 E3 D#3 E3 A2 E3 |  |
| `bwv3.6-alto-m2` | A major | Bach, chorale BWV 3.6, alto, m. 2 | D4 C#4 B3 E4 D#4 E4 F#4 D#4 |  |
| `bwv8.6-soprano-m5` | E major | Bach, chorale BWV 8.6, soprano, m. 5 | B4 A#4 F#4 B4 A#4 B4 A#4 B4 |  |
| `bwv9.7-soprano-m1` | E major | Bach, chorale BWV 9.7, soprano, m. 1 | B4 C#5 D5 C#5 B4 A4 |  |
| `bwv2.6-soprano-m8` | D minor | Bach, chorale BWV 2.6, soprano, m. 8 | Bb4 A4 Bb4 G4 F#4 G4 D5 Bb4 |  |
| `bwv4.8-soprano-m1` | E minor | Bach, chorale BWV 4.8, soprano, m. 1 | A4 G#4 A4 B4 C5 |  |
| `bwv7.7-alto-m3` | B minor | Bach, chorale BWV 7.7, alto, m. 3 | F#4 G4 F#4 E4 D#4 E4 D#4 B3 |  |
| `purcell-laid-in-earth-in-eb-minor` | Eb minor | `purcell-laid` moved to Eb minor (music21 transposition) | Eb3 D3 Db3 C3 Cb3 Bb2 Gb2 Ab2 Bb2 Eb2 |  |
| `bach-crucifixus-in-eb-minor` | Eb minor | `bach-crucifixus` moved to Eb minor (music21 transposition) | Eb3 D3 Db3 C3 Cb3 Bb2 |  |
| `bach-royal-theme-in-eb-minor` | Eb minor | `bach-royal-theme` moved to Eb minor (music21 transposition) | Eb4 Gb4 Bb4 Cb5 D4 Bb4 A4 Ab4 G4 Gb4 F4 | A4 → Bbb4, G4 → Abb4 |
| `bizet-habanera-in-eb-minor` | Eb minor | `bizet-habanera` moved to Eb minor (music21 transposition) | Eb5 D5 Db5 C5 Cb5 Bb4 |  |
| `bwv20.11-bass-m6-in-fsharp-major` | F# major | `bwv20.11-bass-m6` moved to F# major (music21 transposition) | B2 C#3 F#2 F#3 E#3 E3 D#3 C##3 D#3 G#2 A#2 |  |
| `bwv24.6-bass-m13-in-fsharp-major` | F# major | `bwv24.6-bass-m13` moved to F# major (music21 transposition) | E#3 D#3 C#3 B2 B#2 C#3 F#3 |  |
| `bwv41.6-continuo-m1-in-fsharp-major` | F# major | `bwv41.6-continuo-m1` moved to F# major (music21 transposition) | F#3 F#4 E#4 E4 D#4 C#4 B3 E4 |  |
| `bwv127.5-alto-m10-in-fsharp-major` | F# major | `bwv127.5-alto-m10` moved to F# major (music21 transposition) | E4 D#4 E#4 F#4 E#4 E4 D#4 E4 F#4 E4 |  |

**Choosing the amendment.** Every direction of music-theory#14 was measured with a throwaway reference implementation of the rules (exact rationals, outside `src/`), which reproduces every MT4 row (33 `spell-midi` rows and 24 `spell-sequence` rows, ambiguities included), the S7 assertions and the 1699/1699, 1699/1699 and 3398/3398 of the 50 melodies before any change. Against the constraints (all of those kept, and the header's examples), with the seven rows of the issue and this corpus with the key:

| Rules | MT4 rows and corpus | issue rows | chromatic lines, with the key |
|-------|---------------------|-----------:|------------------------------:|
| 0.5.0 | kept | 0/7 | 477/501 = 95.21% |
| S5 accepts the augmented unison | breaks `(61 "C major" "C4")` (Db4 → C#4) and the Hall of the Mountain King (E♯ after F♯, 1697/1699 and 3394/3398) | 2/7 | 475/501 = 94.81% |
| S1 keeps N (natural, harmonic and melodic minor) | kept | 5/7 | 494/501 = 98.60% |
| N, and S5 accepts the augmented unison | the same two breaks | 7/7 | 493/501 = 98.40% |
| N, and the center over N too | 8 rows change their ambiguity | 7/7 | 494/501 |
| no N; S4 and S5 only for ambiguity ≥ 11/16 | kept, but only at exactly 11/16: three S4 rows sit at 11/16, the D major row at 37/54 | 7/7 | 494/501 |
| **N, and S5 only for ambiguity ≥ 3/4 (0.5.1)** | **kept** | **7/7** | **494/501 = 98.60%** |

The minor rows of the issue need the melodic and natural forms in S1; the two major rows end on the chromatic note, so no S4 applies, and S5 chose the note five fifths outside the key. Bounding S5 by the ambiguity it already measures keeps every row: S5's own rows lie at 37/48 and above (E♭4 then 66 in C major is the lowest), the major rows at 37/54, and `spell-midi`'s version of them (C♯4 then 60 in D major) at 35/48; 3/4 lies between. The center stays the mean of K, so no ambiguity of 0.5.0 changes.

**Figures** for the 0.5.1 rules (reference implementation):

| Set | 0.5.1 | 0.5.0 | music21 `simplifyMultipleEnharmonics`, windows of 8 |
|-----|------:|------:|------:|
| chromatic lines, with the key | 494/501 = 98.60% (52 of 57 lines exact) | 477/501 = 95.21% (35 lines) | 474/501 = 94.61% |
| chromatic lines, without a key | 468/501 = 93.41% (36 lines) | 457/501 = 91.22% (32 lines) | 471/501 = 94.01% |
| the 50 melodies, with the key | 1699/1699 | 1699/1699 | 98.35% |
| the 50 melodies, without a key | 1699/1699 | 1699/1699 | 94.23% |
| the 100 transposed melodies, with the key | 3398/3398 | 3398/3398 | 97.85% |
| every Bach chorale excerpt the search found (483 lines, 4482 notes), with the key | 4404/4482 = 98.26% (414 lines) | 4297/4482 = 95.87% (329 lines) | — |

`spell-sequence-chromatic-accuracy` asserts the first two rows rounded down: 98% and 93%. The seven misses with the key are chromatic notes of descending lines that Bach spells as the leading tone of the note before (the royal theme's F♯ and E, BWV 289's G♯, BWV 328's C♯), where S4 writes the step as a diatonic semitone; the royal theme's two repeat in its E♭ minor copy; and the A♭ of the second Tristan phrase, which S1 spells G♯ in A minor. They are left for a later change of S4. The rows of `spell-sequence-chromatic-rows` and `spell-midi-amended-rows` are the issue's table and more of the same, computed with the reference implementation.

## 0.5.1: octaves in text (music-theory#15) and MusicXML kinds (music-theory#16)

No new fixture. The rows in `tests/mt51-test.lisp` were computed with independent reference implementations of the amended rules. For music-theory#16 that implementation turned every well-formed chord of an enumeration (each quality with each allowed EXTENSIONS, SUSPENSION, set of ALTERATIONS, up to two ADDED pairs and set of OMITTED degrees: 336,176 chords) into a kind and degrees and back, unchanged; the test does the same for the 981 chords of `mt3-symbols.sexp` on five roots. MusicXML's own `<degree-alter>` convention (an added degree relative to a dominant chord, an altered one relative to the kind) is followed.
