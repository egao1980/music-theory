"""Generate the 0.5.1 chromatic-line fixture (music-theory#14) with music21.

Run from the repo root:
    uv run --with music21==10.5.2 python -I tests/fixtures/generate-mt51.py
    uv run --with music21==10.5.2 python -I tests/fixtures/generate-mt51.py --search

Writes tests/fixtures/mt51-chromatic.sexp and prints music21's own speller on
the lines, for reference (PROVENANCE.md).

The lines below are chromatic passages from public-domain works, re-encoded by
us as plain lists of spelled pitches (MIT, like the rest of the repo). The
spelling is the notation: the composer's, as printed. A line is a short
excerpt of one voice; repeated notes are written once, rests and durations are
left out (they change no spelling). Each row names its source (PROVENANCE.md
has the details):
  - famous passages typed from the scores (Purcell, Bach, Beethoven, Wagner, Bizet);
  - excerpts of J. S. Bach's four-part chorale harmonisations (public domain),
    as pitch names retyped here in our own format. music21's corpus was used
    only to locate the passages (a search for chromatic semitone runs and
    neighbours, chosen by a fixed rule, below) and to cross-check their
    spellings; no music21 corpus file or encoding is copied. The key is the
    chorale's.
  - copies of some lines in remote keys (F# major, Eb minor), spelled by
    music21's exact transposition, as in mt4-transposed.sexp.
music21 (BSD-3-Clause) checks every spelling and gives the MIDI numbers.
"""
import sys
from itertools import pairwise
from pathlib import Path

from music21 import corpus, interval, key, pitch

OUT = Path(__file__).resolve().parent

# (id, key, category, source, notes). Categories: lament (a descending chromatic
# fourth in minor), minor-ascending / minor-descending (chromatic lines through
# the 6th and 7th degrees of a minor key), major-ascending / major-descending
# (chromatic lines in a major key), neighbour (a chromatic neighbour note).
LINES = [
    # --- Famous passages ---------------------------------------------------------
    ("purcell-laid-in-earth", "G minor", "lament",
     "Purcell, Dido and Aeneas (1689), 'When I am laid in earth', ground bass",
     "G3 F#3 F3 E3 Eb3 D3 Bb2 C3 D3 G2"),
    ("bach-crucifixus", "E minor", "lament",
     "Bach, Mass in B minor BWV 232, Crucifixus, ground bass (chromatic fourth)",
     "E3 D#3 D3 C#3 C3 B2"),
    ("bach-weinen-klagen", "F minor", "lament",
     "Bach, Cantata BWV 12 (1714), 'Weinen, Klagen, Sorgen, Zagen', ground bass (chromatic fourth)",
     "F3 E3 Eb3 D3 Db3 C3"),
    ("beethoven-woo80", "C minor", "lament",
     "Beethoven, 32 Variations in C minor WoO 80 (1806), theme, bass",
     "C3 B2 Bb2 A2 Ab2 G2"),
    ("bach-royal-theme", "C minor", "minor-descending",
     "Bach, Musical Offering BWV 1079 (1747), the royal theme, opening",
     "C4 Eb4 G4 Ab4 B3 G4 F#4 F4 E4 Eb4 D4"),
    ("bizet-habanera", "D minor", "minor-descending",
     "Bizet, Carmen (1875), Habanera, 'L'amour est un oiseau rebelle', opening",
     "D5 C#5 C5 B4 Bb4 A4"),
    ("wagner-tristan-cello-1", "A minor", "minor-descending",
     "Wagner, Tristan und Isolde (1865), Prelude, bars 1-2, cellos",
     "A3 F4 E4 D#4"),
    ("wagner-tristan-oboe-1", "A minor", "minor-ascending",
     "Wagner, Tristan und Isolde, Prelude, bars 2-3, oboe",
     "G#4 A4 A#4 B4"),
    ("wagner-tristan-cello-2", "A minor", "minor-descending",
     "Wagner, Tristan und Isolde, Prelude, bars 5-6, cellos",
     "C4 Ab4 G4 F#4"),
    ("wagner-tristan-oboe-2", "A minor", "minor-ascending",
     "Wagner, Tristan und Isolde, Prelude, bars 6-7, oboe",
     "B4 C5 C#5 D5"),
    # --- Bach chorales ---------------------------------------------------------
    # Excerpts around a run of two or more semitone steps in one direction in one
    # voice, three notes either side; by BWV number, the first five per major
    # pattern (^4 #4 ^5 ascending, ^1 ^7 b7 descending), the first six minor
    # ascending lines through ^6 and ^7, every minor descending line through ^6
    # and ^7, and every other descending run of three or more semitones in minor
    # (lament). An excerpt that doubles one already taken (BWV 8.6's continuo) is
    # left out. Neighbours: the first three chorales in major and in minor with a
    # note a semitone from its neighbours and outside the key's natural, harmonic
    # and melodic scales, four notes either side (--search lists the candidates).
    ("bwv8.6-bass-m15", "E major", "major-ascending", "Bach, chorale BWV 8.6, bass, m. 15",
     "G#3 D#3 E3 A2 A#2 B2 E3"),
    ("bwv12.7-bass-m9", "Bb major", "major-ascending", "Bach, chorale BWV 12.7, bass, m. 9",
     "F3 Bb2 Bb3 Eb3 E3 F3 Eb3 D3 Eb3"),
    ("bwv17.7-bass-m31", "A major", "major-ascending", "Bach, chorale BWV 17.7, bass, m. 31",
     "F#3 E3 B2 C#3 D3 D#3 E3 E#3 F#3 G#3 A3 E3"),
    ("bwv24.6-bass-m13", "F major", "major-ascending", "Bach, chorale BWV 24.6, bass, m. 13",
     "E3 D3 C3 Bb2 B2 C3 F3"),
    ("bwv25.6-bass-m9", "C major", "major-ascending", "Bach, chorale BWV 25.6, bass, m. 9",
     "C4 C3 D3 E3 F3 F#3 G3 G#3 A3 G3 C3 D3"),
    ("bwv20.11-bass-m6", "F major", "major-descending", "Bach, chorale BWV 20.11, bass, m. 6",
     "Bb2 C3 F2 F3 E3 Eb3 D3 C#3 D3 G2 A2"),
    ("bwv41.6-continuo-m1", "C major", "major-descending", "Bach, chorale BWV 41.6, continuo, m. 1",
     "C3 C4 B3 Bb3 A3 G3 F3 Bb3"),
    ("bwv60.5-bass-m6", "A major", "major-descending", "Bach, chorale BWV 60.5, bass, m. 6",
     "B3 B2 E3 A3 G#3 G3 F#3 B2 E3 F#3"),
    ("bwv60.5-bass-m15", "A major", "major-descending", "Bach, chorale BWV 60.5, bass, m. 15",
     "A3 A2 E3 A3 G#3 G3 F#3 F3 E3 D#3 E3 G#3 A3"),
    ("bwv127.5-alto-m10", "F major", "major-descending", "Bach, chorale BWV 127.5, alto, m. 10",
     "Eb4 D4 E4 F4 E4 Eb4 D4 Eb4 F4 Eb4"),
    ("bwv40.6-bass-m13", "D minor", "minor-ascending", "Bach, chorale BWV 40.6, bass, m. 13",
     "A2 Bb2 A2 B2 C3 C#3 D3 G2 G3 F3"),
    ("bwv108.6-bass-m12", "B minor", "minor-ascending", "Bach, chorale BWV 108.6, bass, m. 12",
     "D3 D#3 E3 F#3 G3 G#3 A3 A#3 B3 G3 E3 C#3"),
    ("bwv153.1-bass-m9", "E minor", "minor-ascending", "Bach, chorale BWV 153.1, bass, m. 9",
     "F3 E3 D3 C#3 D3 D#3 E3"),
    ("bwv153.5-bass-m11", "A minor", "minor-ascending", "Bach, chorale BWV 153.5, bass, m. 11",
     "C3 D3 E3 F#3 G3 G#3 A3 E3"),
    ("bwv161.6-alto-m9", "A minor", "minor-ascending", "Bach, chorale BWV 161.6, alto, m. 9",
     "E4 D4 E4 F#4 G4 G#4 A4 A3 E4 C#4"),
    ("bwv161.6-bass-m11", "A minor", "minor-ascending", "Bach, chorale BWV 161.6, bass, m. 11",
     "D3 A2 G2 F2 F#2 G2 G#2 A2 E2"),
    ("bwv120.6-tenor-m2", "B minor", "lament", "Bach, chorale BWV 120.6, tenor, m. 2",
     "F#4 C#4 D#4 E4 D#4 D4 C#4 B3 A3 D4"),
    ("bwv245.15-alto-m7", "A minor", "lament", "Bach, chorale BWV 245.15, alto, m. 7",
     "D4 C#4 D4 E4 Eb4 D4 C#4 D4 E4 F#4"),
    ("bwv245.17-tenor-m7", "A minor", "lament", "Bach, chorale BWV 245.17, tenor, m. 7",
     "E4 F#4 E4 C4 B3 Bb3 A3 C4 B3 A3"),
    ("bwv278-alto-m7", "E minor", "lament", "Bach, chorale BWV 278, alto, m. 7",
     "A4 B4 G#4 C#5 C5 B4 A#4 F#4 G4 F#4"),
    ("bwv289-bass-m5", "E minor", "lament", "Bach, chorale BWV 289, bass, m. 5",
     "E2 E3 A2 A3 G#3 G3 F#3 E3 F#3 B2"),
    ("bwv295-alto-m4", "D minor", "lament", "Bach, chorale BWV 295, alto, m. 4",
     "G4 F#4 G4 F4 E4 Eb4 D4 E4 F4 G4"),
    ("bwv311-tenor-m5", "B minor", "lament", "Bach, chorale BWV 311, tenor, m. 5",
     "E4 A3 B3 C4 B3 A#3 A3 B3 A3 G3"),
    ("bwv328-alto-m33", "A minor", "lament", "Bach, chorale BWV 328, alto, m. 33",
     "E4 F4 E4 D4 C#4 C4 B3 C4 D4 E4"),
    ("bwv421-tenor-m1", "A minor", "lament", "Bach, chorale BWV 421, tenor, m. 1",
     "D4 E4 A3 B3 Bb3 A3 G#3 A3 C4 B3"),
    ("bwv144.6-bass-m8", "B minor", "minor-descending", "Bach, chorale BWV 144.6, bass, m. 8",
     "B2 E3 A2 A3 G#3 G3 F#3 E3 D3 C#3"),
    ("bwv168.6-alto-m4", "B minor", "minor-descending", "Bach, chorale BWV 168.6, alto, m. 4",
     "F#4 C#5 A#4 B4 A#4 A4 G#4 A4 B4 A4"),
    ("bwv244.25-bass-m11", "B minor", "minor-descending", "Bach, chorale BWV 244.25, bass, m. 11",
     "D3 F#3 G#3 A3 G#3 G3 F#3 E#3 F#3 B2"),
    ("bwv288-bass-m5", "A minor", "minor-descending", "Bach, chorale BWV 288, bass, m. 5",
     "A2 D3 D4 G#3 G3 F#3 F3 E3 D3 E3 A2"),
    ("bwv312-alto-m9", "A minor", "minor-descending", "Bach, chorale BWV 312, alto, m. 9",
     "D4 C4 E4 A4 G#4 G4 F#4 G4 F4 E4"),
    ("bwv331-bass-m1", "A minor", "minor-descending", "Bach, chorale BWV 331, bass, m. 1",
     "A2 A3 G3 F#3 F3 E3 F3 D3 E3"),
    ("bwv337-alto-m4", "A minor", "minor-descending", "Bach, chorale BWV 337, alto, m. 4",
     "E4 F#4 G#4 A4 G#4 G4 F#4 G4 A4 G4"),
    ("bwv434-bass-m3", "A minor", "minor-descending", "Bach, chorale BWV 434, bass, m. 3",
     "E3 A3 B3 A3 G#3 G3 F#3 F3 E3 D#3 E3 A2 E3"),
    ("bwv3.6-alto-m2", "A major", "neighbour", "Bach, chorale BWV 3.6, alto, m. 2",
     "D4 C#4 B3 E4 D#4 E4 F#4 D#4"),
    ("bwv8.6-soprano-m5", "E major", "neighbour", "Bach, chorale BWV 8.6, soprano, m. 5",
     "B4 A#4 F#4 B4 A#4 B4 A#4 B4"),
    ("bwv9.7-soprano-m1", "E major", "neighbour", "Bach, chorale BWV 9.7, soprano, m. 1",
     "B4 C#5 D5 C#5 B4 A4"),
    ("bwv2.6-soprano-m8", "D minor", "neighbour", "Bach, chorale BWV 2.6, soprano, m. 8",
     "Bb4 A4 Bb4 G4 F#4 G4 D5 Bb4"),
    ("bwv4.8-soprano-m1", "E minor", "neighbour", "Bach, chorale BWV 4.8, soprano, m. 1",
     "A4 G#4 A4 B4 C5"),
    ("bwv7.7-alto-m3", "B minor", "neighbour", "Bach, chorale BWV 7.7, alto, m. 3",
     "F#4 G4 F#4 E4 D#4 E4 D#4 B3"),
]

# (id of a line above, key to move it to): remote-key copies.
REMOTE = [
    ("purcell-laid-in-earth", "Eb minor"),
    ("bach-crucifixus", "Eb minor"),
    ("bach-royal-theme", "Eb minor"),
    ("bizet-habanera", "Eb minor"),
    ("bwv20.11-bass-m6", "F# major"),
    ("bwv24.6-bass-m13", "F# major"),
    ("bwv41.6-continuo-m1", "F# major"),
    ("bwv127.5-alto-m10", "F# major"),
]


def m21_pitch(name):
    """Our pitch name ("Bb4", "F#4", "E#4") as a music21 Pitch."""
    letter, rest = name[0], name[1:]
    accidental = rest.rstrip("-0123456789")
    octave = rest[len(accidental):]
    return pitch.Pitch(letter + accidental.replace("b", "-") + octave)


def spelling_of(p):
    """A music21 pitch in our ASCII spelling, with octave."""
    return p.step + {-2: "bb", -1: "b", 0: "", 1: "#", 2: "##"}[int(p.alter)] + str(p.octave)


def tonic_interval(from_key, to_key):
    """From FROM's tonic in octave 4 to TO's tonic, the letter moving at most three
    steps (TRANSPOSE-TO-KEY's interval, as in generate-mt4.py)."""
    a = m21_pitch(from_key.split()[0] + "4")
    best = None
    for octave in (3, 4, 5):
        b = m21_pitch(to_key.split()[0] + str(octave))
        if -3 <= b.diatonicNoteNum - a.diatonicNoteNum <= 3:
            best = b
    return interval.Interval(noteStart=a, noteEnd=best)


def lisp_string(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


# --- The chorale search (--search) ------------------------------------------------
#
# Lists the candidates the chorale lines above were chosen from (the rule is in
# the LINES comment): per chorale voice, repeated notes merged, every run of two
# or more semitone steps in one direction (three notes either side) and every
# chromatic neighbour (four notes either side). Prints, does not write.

LETTER_FIFTHS = {"F": -1, "C": 0, "G": 1, "D": 2, "A": 3, "E": 4, "B": 5}
KEY_NOTES = {"major": {-1, 0, 1, 2, 3, 4, 5}, "minor": {-4, -3, -2, -1, 0, 1, 2, 3, 5}}


def fifths(p):
    return LETTER_FIFTHS[p.step] + 7 * int(p.alter)


def search():
    for path in corpus.getComposer("bach"):
        s = corpus.parse(path)
        keys = s.recurse().getElementsByClass(key.Key)
        k = keys[0] if keys else s.analyze("key")
        key_text = f"{k.tonic.name.replace('-', 'b')} {k.mode}"
        for part in s.parts:
            seq = []
            for n in part.recurse().notes:
                if n.isNote and not (seq and seq[-1].pitch.midi == n.pitch.midi):
                    seq.append(n)
            midis = [n.pitch.midi for n in seq]
            names = [spelling_of(n.pitch) for n in seq]
            where = f"{Path(str(path)).name} | {key_text} | {part.partName}"
            i = 0
            while i < len(seq) - 2:
                step, j = midis[i + 1] - midis[i], i
                while abs(step) == 1 and j + 1 < len(seq) and midis[j + 1] - midis[j] == step:
                    j += 1
                if j - i >= 2:
                    print(f"run | {where} | m. {seq[i].measureNumber} | "
                          f"{' '.join(names[i:j + 1])} | {' '.join(names[max(0, i - 3):j + 4])}")
                    i = j
                else:
                    i += 1
            for i in range(1, len(seq) - 1):
                if (midis[i - 1] == midis[i + 1] and abs(midis[i] - midis[i - 1]) == 1
                        and fifths(seq[i].pitch) - fifths(k.tonic) not in KEY_NOTES[k.mode]):
                    print(f"neighbour | {where} | m. {seq[i].measureNumber} | {names[i]} | "
                          f"{' '.join(names[max(0, i - 4):i + 4])}")


if "--search" in sys.argv[1:]:
    search()
    sys.exit(0)


rows = []
by_id = {}
for ident, key_text, category, source, text in LINES:
    names = text.split()
    pitches = [m21_pitch(n) for n in names]
    assert [spelling_of(p) for p in pitches] == names, ident
    assert all(a.midi != b.midi for a, b in pairwise(pitches)), ident  # no repeats
    key.Key(*key_text.replace("b ", "- ").split())  # a key music21 knows
    assert ident not in by_id, ident
    by_id[ident] = (key_text, category, names)
    rows.append((ident, key_text, category, names, [p.midi for p in pitches]))

for ident, to_key in REMOTE:
    from_key, category, names = by_id[ident]
    iv = tonic_interval(from_key, to_key)
    moved = [m21_pitch(n).transpose(iv) for n in names]
    assert all(abs(p.alter) <= 2 for p in moved), ident
    rows.append((f"{ident}-in-{to_key.replace(' ', '-').replace('#', 'sharp').lower()}",
                 to_key, category, [spelling_of(p) for p in moved], [p.midi for p in moved]))

(OUT / "mt51-chromatic.sexp").write_text(
    ";; Generated by generate-mt51.py with music21 10.5.2. Do not edit.\n"
    ";; (id key category names midis): a chromatic line from a public-domain work,\n"
    ";; re-encoded by us (or its copy in a remote key), its key (KEY-NAME text), its\n"
    ";; category, the notated spelled pitches and music21's MIDI number of each.\n(\n"
    + "\n".join(f"({lisp_string(i)} {lisp_string(k)} {lisp_string(c)}\n"
                f"  ({' '.join(lisp_string(n) for n in names)})\n"
                f"  ({' '.join(str(m) for m in midis)}))"
                for i, k, c, names, midis in rows)
    + "\n)\n", encoding="utf-8")

# --- music21's own speller, for reference (PROVENANCE.md) -------------------------

total = sum(len(r[3]) for r in rows)
print(f"{len(rows)} lines, {total} notes")
for label, with_key in (("with the key", True), ("without a key", False)):
    right = 0
    for ident, key_text, category, names, midis in rows:
        context = key.Key(*key_text.replace("b ", "- ").split()) if with_key else None
        got = []
        for i in range(0, len(midis), 8):
            got += pitch.simplifyMultipleEnharmonics(midis[i:i + 8], keyContext=context)
        right += sum(m21_pitch(n).name == p.name for n, p in zip(names, got))
    print(f"music21 simplifyMultipleEnharmonics (windows of 8), {label}: "
          f"{right}/{total} = {right / total:.2%}")
