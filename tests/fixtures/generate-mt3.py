"""Generate MT3 test vectors (chord symbols, MusicXML kinds, transposition) with music21.

Run from the repo root:
    uv run --with music21==10.5.2 python -I tests/fixtures/generate-mt3.py

Writes tests/fixtures/mt3-symbols.sexp, mt3-kinds.sexp and mt3-transpose.sexp.
The values are computed facts (roots, basses, spelled chord tones); music21
(BSD-3-Clause) is only the oracle. See PROVENANCE.md.

music21's chord-symbol parser reads a different text convention from ours
("-" is a flat, no "b" flats after a letter, no Unicode accidentals, no
parentheses, no N.C.; see PROVENANCE.md). So every row below gives our text
and a *recipe* in music21's own terms that names the chord we mean: a music21
figure, or a root and a MusicXML kind plus ChordStepModifications. music21
realises the recipe. The last column records what music21's parser makes of
our text when only the root and bass accidentals are translated into its
notation: :same when it realises the same chord, else its reading or :error.
Those differences are listed in PROVENANCE.md; the tests use our convention.
"""
from pathlib import Path
from music21 import harmony, interval, pitch

OUT = Path(__file__).resolve().parent
ASCII = {-2: "bb", -1: "b", 0: "", 1: "#", 2: "##"}
# Our accidental tokens (PARSE-PITCH) → music21's.
TO_M21 = {"bb": "--", "b": "-", "#": "#", "##": "##", "x": "##",
          "♭": "-", "♯": "#", "𝄫": "--", "𝄪": "##", "♭♭": "--", "♯♯": "##"}


def lisp_string(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def lisp(x):
    if x is None:
        return "nil"
    if isinstance(x, bool):
        return "t" if x else "nil"
    if isinstance(x, str):
        return x if x.startswith(":") else lisp_string(x)
    if isinstance(x, (list, tuple)):
        return "(" + " ".join(lisp(i) for i in x) + ")"
    return str(x)


def ours(p):
    """Our ASCII spelling of a music21 pitch's class, or None beyond two accidentals."""
    alter = int(p.alter)
    return p.step + ASCII[alter] if abs(alter) <= 2 else None


def name_of(p):
    """Our spelling, or the music21 name marked as out of range ("C###")."""
    return ours(p) or ("!" + p.name)


# --- Recipes ---------------------------------------------------------------

def F(figure):
    """A music21 figure (its own syntax: "B-7b9", "C/F#")."""
    return ("fig", figure)


def K(root, kind, *mods, bass=None):
    """A root (music21 spelling), a MusicXML kind and (type degree alter) steps."""
    return ("kind", root, kind, mods, bass)


NC = ("nc",)


def split_bass(figure):
    if "/" in figure:
        head, tail = figure.rsplit("/", 1)
        if tail and tail[0] in "ABCDEFG":
            return head, tail
    return figure, None


def chord_of(recipe):
    """(music21 ChordSymbol without the bass, bass Pitch or None), or (None, None) for N.C."""
    if recipe[0] == "nc":
        return None, None
    if recipe[0] == "fig":
        head, bass = split_bass(recipe[1])
        return harmony.ChordSymbol(head), (pitch.Pitch(bass) if bass else None)
    _, root, kind, mods, bass = recipe
    cs = harmony.ChordSymbol(root=root, kind=kind)
    for kind_of_step, degree, alter in mods:
        cs.addChordStepModification(harmony.ChordStepModification(kind_of_step, degree, alter))
    return cs, (pitch.Pitch(bass) if bass else None)


def unique(names):
    seen, out = set(), []
    for n in names:
        if n not in seen:
            seen.add(n)
            out.append(n)
    return out


def realise(recipe):
    """(root bass tones): our spellings; tones without the bass, music21's order."""
    cs, bass = chord_of(recipe)
    if cs is None:
        return None, None, []
    return (name_of(cs.root()), name_of(bass) if bass else None,
            unique(name_of(p) for p in cs.pitches))


def recipe_text(recipe):
    if recipe[0] == "nc":
        return "NoChord()"
    if recipe[0] == "fig":
        return recipe[1]
    _, root, kind, mods, bass = recipe
    steps = "".join(f" {t} {d} {a:+d}" for t, d, a in mods)
    return f"{root} {kind}{steps}" + (f" /{bass}" if bass else "")


def translate_spelling(text, start):
    """Our letter+accidental at START → (music21 spelling, end index)."""
    letter = text[start]
    best = ""
    for token in TO_M21:
        if text.startswith(token, start + 1) and len(token) > len(best):
            best = token
    return letter + TO_M21.get(best, ""), start + 1 + len(best)


def direct(text, expected):
    """What music21's own parser makes of TEXT (root and bass accidentals
    translated): :same when it matches EXPECTED (root bass tones), else its
    (root bass tones) reading, or :error."""
    t = text.strip()
    try:
        if not t or t[0] not in "ABCDEFG":
            raise ValueError("no root")
        root, end = translate_spelling(t, 0)
        body = t[end:]
        bass_part = None
        if "/" in body:
            head, tail = body.rsplit("/", 1)
            if tail and tail[0] in "ABCDEFG":
                b, bend = translate_spelling(tail, 0)
                if bend == len(tail):
                    body, bass_part = head, b
        cs = harmony.ChordSymbol(root + body + (f"/{bass_part}" if bass_part else ""))
        got_root = name_of(cs.root())
        got_bass = name_of(cs.bass()) if bass_part else None
        got = unique(name_of(p) for p in cs.pitches)
    except Exception:
        return ":error"
    exp_root, exp_bass, exp_tones = expected
    if (got_root == exp_root and got_bass == exp_bass
            and set(got) == set(exp_tones) | ({exp_bass} if exp_bass else set())):
        return ":same"
    return [got_root, got_bass, got]


# --- Symbols ----------------------------------------------------------------
# (our text, dialect or None for all three, recipe). Dialect rows exist only
# where the dialects read the text differently (dim, o, °).

ALT = (("add", 9, -1), ("add", 9, 1), ("add", 11, 1), ("add", 13, -1), ("subtract", 5, 0))
DIALECTS = (":classical", ":pop", ":jazz")


def dim_rows(text, triad, seventh):
    """TEXT read as a diminished triad (classical) and a diminished seventh (pop, jazz)."""
    return [(text, ":classical", triad), (text, ":pop", seventh), (text, ":jazz", seventh)]


SYMBOLS = [
    # Triads, sixths, power chords and their aliases
    ("C", None, F("C")), ("CM", None, F("C")), ("Cmaj", None, F("C")),
    ("CMaj", None, F("C")),
    ("Cm", None, F("Cm")), ("Cmin", None, F("Cm")), ("Cmi", None, F("Cm")),
    ("C-", None, F("Cm")), ("F#m", None, F("F#m")), ("Bbm", None, F("B-m")),
    ("Ebm", None, F("E-m")), ("G#m", None, F("G#m")), ("Dbm", None, F("D-m")),
    ("Caug", None, F("C+")), ("C+", None, F("C+")), ("Ab+", None, F("A-+")),
    ("E+", None, F("E+")),
    ("C6", None, F("C6")), ("CM6", None, F("C6")), ("Cmaj6", None, F("C6")),
    ("Bb6", None, F("B-6")), ("Cm6", None, F("Cm6")), ("Cmin6", None, F("Cm6")),
    ("Cmi6", None, F("Cm6")), ("C-6", None, F("Cm6")), ("F#m6", None, F("F#m6")),
    ("C5", None, K("C", "power")), ("F#5", None, K("F#", "power")),
    ("Bb5", None, K("B-", "power")), ("Eb5", None, K("E-", "power")),
    ("D5", None, K("D", "power")),
    ("C6/9", None, K("C", "major-sixth", ("add", 9, 0))),
    ("C69", None, K("C", "major-sixth", ("add", 9, 0))),
    ("F6/9", None, K("F", "major-sixth", ("add", 9, 0))),
    ("Eb69", None, K("E-", "major-sixth", ("add", 9, 0))),
    ("Cm6/9", None, K("C", "minor-sixth", ("add", 9, 0))),
    ("Cm69", None, K("C", "minor-sixth", ("add", 9, 0))),
    ("C-6/9", None, K("C", "minor-sixth", ("add", 9, 0))),
    ("C-69", None, K("C", "minor-sixth", ("add", 9, 0))),
    # Dialect-ambiguous: dim, o and ° name a triad (classical) or a dim7 (pop, jazz)
    *dim_rows("Cdim", F("Cdim"), F("Cdim7")),
    *dim_rows("Co", F("Cdim"), F("Cdim7")),
    *dim_rows("C°", F("Cdim"), F("Cdim7")),
    *dim_rows("Bdim", F("Bdim"), F("Bdim7")),
    *dim_rows("F#°", F("F#dim"), F("F#dim7")),
    *dim_rows("F♯°", F("F#dim"), F("F#dim7")),
    *dim_rows("Ebdim", F("E-dim"), F("E-dim7")),
    *dim_rows("C#o", F("C#dim"), F("C#dim7")),
    *dim_rows("Gdim/Bb", F("Gdim/B-"), F("Gdim7/B-")),
    *dim_rows("Abo", F("A-dim"), F("A-dim7")),
    ("Adim7", None, F("Adim7")), ("A#dim7", None, F("A#dim7")),
    ("Cdim7", None, F("Cdim7")), ("Co7", None, F("Co7")), ("C°7", None, F("Co7")),
    ("F#dim7", None, F("F#dim7")), ("Bbo7", None, F("B-o7")), ("G#°7", None, F("G#o7")),
    # Seventh chords and their aliases
    ("C7", None, F("C7")), ("G7", None, F("G7")), ("Bb7", None, F("B-7")),
    ("F#7", None, F("F#7")), ("Db7", None, F("D-7")), ("B7", None, F("B7")),
    ("E7", None, F("E7")), ("Ab7", None, F("A-7")),
    ("Cmaj7", None, F("Cmaj7")), ("CM7", None, F("Cmaj7")), ("CMaj7", None, F("Cmaj7")),
    ("CΔ7", None, F("Cmaj7")), ("CΔ", None, F("Cmaj7")),
    ("C△7", None, F("Cmaj7")), ("C^7", None, F("Cmaj7")), ("C^", None, F("Cmaj7")),
    ("Ebmaj7", None, F("E-maj7")), ("F#maj7", None, F("F#maj7")),
    ("AbΔ7", None, F("A-maj7")),
    ("Cm7", None, F("Cm7")), ("Cmin7", None, F("Cm7")), ("Cmi7", None, F("Cm7")),
    ("C-7", None, F("Cm7")), ("Dm7", None, F("Dm7")), ("Bbm7", None, F("B-m7")),
    ("F#m7", None, F("F#m7")), ("G#-7", None, F("G#m7")),
    ("CmM7", None, F("CmM7")), ("Cm(maj7)", None, F("CmM7")), ("Cmmaj7", None, F("CmM7")),
    ("CmMaj7", None, F("CmM7")), ("Cminmaj7", None, F("CmM7")), ("C-Δ7", None, F("CmM7")),
    ("C-maj7", None, F("CmM7")), ("CmΔ7", None, F("CmM7")), ("C-Δ", None, F("CmM7")),
    ("C-M7", None, F("CmM7")), ("Ebm(maj7)", None, F("E-mM7")),
    ("Cø7", None, F("Cø7")), ("Cø", None, F("Cø7")), ("CØ7", None, F("Cø7")),
    ("Cm7b5", None, F("Cø7")), ("C-7b5", None, F("Cø7")), ("Cm7(b5)", None, F("Cø7")),
    ("Cm7♭5", None, F("Cø7")), ("Cm7-5", None, F("Cø7")), ("C-7-5", None, F("Cø7")),
    ("Bm7b5", None, F("Bø7")), ("F#ø7", None, F("F#ø7")), ("Abø7", None, F("A-ø7")),
    ("C+7", None, F("C+7")), ("C7+", None, F("C+7")), ("Caug7", None, F("C+7")),
    ("C7#5", None, F("C+7")), ("C7+5", None, F("C+7")), ("C7(#5)", None, F("C+7")),
    ("Ab7#5", None, F("A-+7")),
    ("C+M7", None, F("C+M7")), ("C+maj7", None, F("C+M7")), ("Caugmaj7", None, F("C+M7")),
    ("C+Δ7", None, F("C+M7")), ("Cmaj7#5", None, F("C+M7")), ("Cmaj7(#5)", None, F("C+M7")),
    ("Fmaj7+5", None, F("F+M7")),
    # Ninths, elevenths, thirteenths
    ("C9", None, F("C9")), ("C11", None, F("C11")), ("C13", None, F("C13")),
    ("G9", None, F("G9")), ("Bb13", None, F("B-13")), ("F#11", None, F("F#11")),
    ("A13", None, F("A13")),
    ("Cmaj9", None, K("C", "major-ninth")), ("CM9", None, K("C", "major-ninth")),
    ("CΔ9", None, K("C", "major-ninth")), ("Dbmaj9", None, K("D-", "major-ninth")),
    ("Cmaj11", None, K("C", "major-11th")), ("CM13", None, K("C", "major-13th")),
    ("Cmaj13", None, K("C", "major-13th")), ("CΔ13", None, K("C", "major-13th")),
    ("Cm9", None, F("Cm9")), ("C-9", None, F("Cm9")), ("E-9", None, F("Em9")),
    ("Ebm9", None, F("E-m9")), ("Cm11", None, F("Cm11")), ("C-11", None, K("C", "minor-11th")),
    ("B-11", None, K("B", "minor-11th")), ("Cm13", None, F("Cm13")),
    ("CmM9", None, F("CmM9")), ("Cm(maj9)", None, F("CmM9")), ("C-Δ9", None, F("CmM9")),
    ("CmM11", None, F("CmM11")), ("CmM13", None, F("CmM13")),
    ("Cø9", None, F("Cø9")), ("Cø11", None, K("C", "half-diminished-seventh", ("add", 9, 0), ("add", 11, 0))),
    ("Cø13", None, F("Cø13")), ("Cm9b5", None, F("Cø9")),
    ("Cm11b5", None, K("C", "half-diminished-seventh", ("add", 9, 0), ("add", 11, 0))),
    ("Cdim9", None, F("Co9")), ("Co9", None, F("Co9")),
    ("C°11", None, K("C", "diminished-seventh", ("add", 9, 0), ("add", 11, 0))),
    ("C+9", None, F("C+9")), ("Caug9", None, F("C+9")), ("C9#5", None, F("C+9")),
    ("C+11", None, F("C+11")), ("C+13", None, F("C+13")),
    ("C+M9", None, F("C+M9")), ("C+maj9", None, F("C+M9")), ("Cmaj9#5", None, F("C+M9")),
    ("C+M11", None, F("C+M11")), ("C+M13", None, F("C+M13")),
    # Alterations
    ("C7b9", None, F("C7b9")), ("C7#9", None, F("C7#9")), ("C7b9#9", None, F("C7b9#9")),
    ("C7#11", None, F("C7#11")), ("C7b13", None, F("C7b13")), ("C7b5", None, F("C7b5")),
    ("C7(b9)", None, F("C7b9")), ("C7(#9)", None, F("C7#9")),
    ("C7(b9,#11)", None, F("C7b9#11")), ("C7(b9#11)", None, F("C7b9#11")),
    ("C7(♭9)", None, F("C7b9")), ("C7♯9", None, F("C7#9")),
    ("C7-9", None, F("C7b9")), ("C7+9", None, F("C7#9")), ("C7+11", None, F("C7#11")),
    ("C7-13", None, F("C7b13")), ("C7-5", None, F("C7b5")),
    ("C9b5", None, K("C", "dominant-ninth", ("alter", 5, -1))),
    ("C9#11", None, K("C", "dominant-ninth", ("add", 11, 1))),
    ("C13b9", None, K("C", "dominant-13th", ("alter", 9, -1))),
    ("C13#11", None, K("C", "dominant-13th", ("alter", 11, 1))),
    ("C13(#11)", None, K("C", "dominant-13th", ("alter", 11, 1))),
    ("Cmaj7#11", None, F("Cmaj7#11")), ("CΔ7#11", None, F("Cmaj7#11")),
    ("Cmaj9#11", None, K("C", "major-ninth", ("add", 11, 1))),
    ("C7alt", None, K("C", "dominant-seventh", *ALT)),
    ("G7alt", None, K("G", "dominant-seventh", *ALT)),
    ("Bb7alt", None, K("B-", "dominant-seventh", *ALT)),
    ("C7b5b9", None, K("C", "dominant-seventh", ("alter", 5, -1), ("add", 9, -1))),
    ("C7#5#9", None, K("C", "augmented-seventh", ("add", 9, 1))),
    ("C7#5b9", None, K("C", "augmented-seventh", ("add", 9, -1))),
    ("C7(b5,#5)", None, F("C+7b5")),
    ("C7(b9,b13)", None, F("C7b9b13")),
    ("E7#9", None, F("E7#9")), ("Bb7b9", None, F("B-7b9")), ("F#7#9", None, F("F#7#9")),
    ("Db7#11", None, F("D-7#11")), ("Ab13", None, F("A-13")), ("Eb7b9#11", None, F("E-7b9#11")),
    ("C7(13)", None, F("C7add13")), ("C7(9)", None, F("C7add9")), ("C7add13", None, F("C7add13")),
    ("C7(9,13)", None, K("C", "dominant-seventh", ("add", 9, 0), ("add", 13, 0))),
    ("C9(13)", None, K("C", "dominant-ninth", ("add", 13, 0))),
    ("Cm7(9)", None, F("Cm7add9")), ("Cm7(11)", None, F("Cm7add11")), ("Cm7add11", None, F("Cm7add11")),
    ("Cmaj7(9)", None, F("Cmaj7add9")),
    ("C(b5)", None, K("C", "major", ("alter", 5, -1))), ("C(#5)", None, F("C+")),
    ("Cm(b5)", None, F("Cdim")), ("Cmb5", None, F("Cdim")), ("C-(b5)", None, F("Cdim")),
    # Suspensions, added and omitted tones
    ("Csus", None, F("Csus")), ("Csus4", None, F("Csus4")), ("Csus2", None, F("Csus2")),
    ("C7sus4", None, F("C7sus4")), ("C7sus", None, F("C7sus4")),
    ("C7sus2", None, K("C", "suspended-second", ("add", 7, -1))),
    ("C9sus4", None, K("C", "suspended-fourth-seventh", ("add", 9, 0))),
    ("C13sus4", None, K("C", "dominant-13th", ("subtract", 3, 0), ("add", 4, 0))),
    ("Cmaj7sus4", None, K("C", "major-seventh", ("subtract", 3, 0), ("add", 4, 0))),
    ("C7sus4b9", None, F("C7sus4b9")), ("C7sus4(b9)", None, F("C7sus4b9")),
    ("Bbsus4", None, F("B-sus4")), ("F#sus2", None, F("F#sus2")),
    ("Cadd9", None, F("Cadd9")), ("Cadd2", None, F("Cadd2")),
    ("Cadd4", None, K("C", "major", ("add", 4, 0))),
    ("Cmadd9", None, F("Cmadd9")), ("C-add9", None, F("Cmadd9")),
    ("C(add9)", None, F("Cadd9")), ("C(9)", None, F("Cadd9")), ("Cm(add9)", None, F("Cmadd9")),
    ("Csus4add9", None, F("Csus4add9")),
    ("C6add9", None, K("C", "major-sixth", ("add", 9, 0))),
    ("Cadd#11", None, K("C", "major", ("add", 11, 1))),
    ("C(add#11)", None, K("C", "major", ("add", 11, 1))),
    ("Cadd13", None, K("C", "major", ("add", 13, 0))),
    ("C(omit3)", None, F("Comit3")), ("Comit3", None, F("Comit3")), ("Cno3", None, F("Comit3")),
    ("C(no3)", None, F("Comit3")),
    ("C7(omit3)", None, K("C", "dominant-seventh", ("subtract", 3, 0))),
    ("C7no3", None, K("C", "dominant-seventh", ("subtract", 3, 0))),
    ("C(omit5)", None, K("C", "major", ("subtract", 5, 0))),
    ("Cm7(omit5)", None, K("C", "minor-seventh", ("subtract", 5, 0))),
    ("C9(omit3)", None, K("C", "dominant-ninth", ("subtract", 3, 0))),
    ("C11(omit3)", None, K("C", "dominant-11th", ("subtract", 3, 0))),
    ("C13(omit11)", None, K("C", "dominant-13th", ("subtract", 11, 0))),
    ("C13(no9)", None, K("C", "dominant-13th", ("subtract", 9, 0))),
    ("C7(omit3,omit5)", None, K("C", "dominant-seventh", ("subtract", 3, 0), ("subtract", 5, 0))),
    ("C5(omit5)", None, K("C", "pedal")),
    ("C5(add9)", None, K("C", "power", ("add", 9, 0))),
    ("Cadd9(omit3)", None, K("C", "major", ("add", 9, 0), ("subtract", 3, 0))),
    ("C(add9,omit3)", None, K("C", "major", ("add", 9, 0), ("subtract", 3, 0))),
    ("C7(b9,omit3)", None, K("C", "dominant-seventh", ("add", 9, -1), ("subtract", 3, 0))),
    ("C7(#9,add13)", None, K("C", "dominant-seventh", ("add", 9, 1), ("add", 13, 0))),
    # Slash bass, inside and outside the chord
    ("C/E", None, F("C/E")), ("C/G", None, F("C/G")), ("C/Bb", None, F("C/B-")),
    ("C/D", None, F("C/D")), ("C/F#", None, F("C/F#")), ("C/F", None, F("C/F")),
    ("G7/B", None, F("G7/B")), ("G7/F", None, F("G7/F")), ("G7/D", None, F("G7/D")),
    ("Am/C", None, F("Am/C")), ("Am7/G", None, F("Am7/G")), ("D/F#", None, F("D/F#")),
    ("Bb/D", None, F("B-/D")), ("Eb/Bb", None, F("E-/B-")), ("F/G", None, F("F/G")),
    ("Fmaj7/G", None, F("Fmaj7/G")), ("Ab/Bb", None, F("A-/B-")), ("E/F", None, F("E/F")),
    ("D/C", None, F("D/C")), ("Cm7/Bb", None, F("Cm7/B-")), ("C7b9/E", None, F("C7b9/E")),
    ("F#m7b5/C", None, F("F#ø7/C")), ("Bbsus4/Eb", None, F("B-sus4/E-")),
    ("C/E♭", None, F("C/E-")), ("C♯m/G♯", None, F("C#m/G#")), ("Db/Cb", None, F("D-/C-")),
    ("G/B#", None, F("G/B#")),
    ("C6/9/E", None, K("C", "major-sixth", ("add", 9, 0), bass="E")),
    ("C+/G#", None, F("C+/G#")), ("Cø7/Gb", None, F("Cø7/G-")), ("D7/C", None, F("D7/C")),
    ("Csus4/F", None, F("Csus4/F")),
    # N.C.
    ("N.C.", None, NC), ("NC", None, NC), ("N.C", None, NC),
    # Unicode accidentals and symbols
    ("C♯m7", None, F("C#m7")), ("D♭maj7", None, F("D-maj7")), ("B♭7♭9", None, F("B-7b9")),
    ("F♯ø7", None, F("F#ø7")), ("E♭°7", None, F("E-o7")),
    ("A♭Δ9", None, K("A-", "major-ninth")),
    ("G♭6/9", None, K("G-", "major-sixth", ("add", 9, 0))),
    ("B𝄫", None, F("B--")), ("F𝄪m", None, F("F##m")), ("C𝄪7", None, F("C##7")),
    ("C♭maj7", None, F("C-maj7")), ("D♯m7♭5", None, F("D#ø7")),
    ("C7(♭9,♯11)", None, F("C7b9#11")), ("A♭+", None, F("A-+")),
    ("E♭m(maj7)", None, F("E-mM7")),
    # Spelling at the edges of the line of fifths
    ("Fb", None, F("F-")), ("Cb7", None, F("C-7")), ("B#", None, F("B#")),
    ("E#m7", None, F("E#m7")), ("Gbm7b5", None, F("G-ø7")), ("C#7#9", None, F("C#7#9")),
    ("Abbmaj7", None, F("A--maj7")), ("Cbm", None, F("C-m")), ("G##7", None, F("G##7")),
    ("Fbb", None, F("F--")), ("Cx", None, F("C##")), ("Gx7", None, F("G##7")),
]

# Rows where music21's own parser reads our text as a *different* chord (not
# merely an error). Each is a deliberate difference listed in PROVENANCE.md;
# the script stops if music21 disagrees anywhere else.
MINUS_IS_MINOR = {"C-", "C-6", "C-69", "C-7", "C-maj7", "C-M7", "C-7b5", "C-9", "E-9",
                  "C-11", "B-11", "C-add9"}        # music21: "-" is a flat (C- = Cb)
DIM_IS_SEVENTH = {(t, d) for t in ("Cdim", "Co", "Bdim", "Ebdim", "C#o", "Gdim/Bb", "Abo")
                  for d in (":pop", ":jazz")}     # music21: dim and o are the triad
M21_PARSER_BUGS = {"C69", "Eb69",                 # music21 drops the third and fifth
                   "C13b9", "C13#11"}             # music21 ignores an alteration of a kind's own degree

symbol_rows = []
seen = set()
for text, dialect, recipe in SYMBOLS:
    key = (text, dialect)
    assert key not in seen, key
    seen.add(key)
    root, bass, tones = realise(recipe)
    assert all(not t.startswith("!") for t in tones + [root or "", bass or ""]), (text, tones)
    reading = direct(text, (root, bass, tones)) if recipe != NC else ":error"
    known = text in MINUS_IS_MINOR or key in DIM_IS_SEVENTH or text in M21_PARSER_BUGS
    assert known == isinstance(reading, list), ("unlisted music21 difference", key, reading)
    symbol_rows.append(lisp([text, dialect, root, bass, tones, recipe_text(recipe), reading]))

(OUT / "mt3-symbols.sexp").write_text(
    ";; (text dialect root bass tones m21-recipe m21-direct), generated by generate-mt3.py\n"
    ";; with music21 10.5.2. DIALECT nil = the same reading in all three dialects.\n"
    ";; ROOT, BASS and TONES (spelled classes, bass excluded, music21's order) come from\n"
    ";; music21 realising M21-RECIPE: a music21 figure, or root + MusicXML kind + steps.\n"
    ";; M21-DIRECT is music21's own reading of TEXT (root and bass accidentals translated):\n"
    ";; :same, :error, or its (root bass tones-with-bass); for reference only.\n("
    + "\n ".join(symbol_rows) + ")\n")

# --- MusicXML kinds ---------------------------------------------------------
# (kind, our text on C or None, music21 kind for the oracle or None). The text
# is the canonical :pop spelling; other roots are reached by transposition.

KINDS = [
    ("major", "C", "major"), ("minor", "Cm", "minor"), ("augmented", "C+", "augmented"),
    ("diminished", "Cm(b5)", "diminished"), ("dominant", "C7", "dominant"),
    ("major-seventh", "Cmaj7", "major-seventh"), ("minor-seventh", "Cm7", "minor-seventh"),
    ("diminished-seventh", "Cdim7", "diminished-seventh"),
    ("augmented-seventh", "C+7", "augmented-seventh"),
    ("half-diminished", "Cm7(b5)", "half-diminished"), ("major-minor", "Cmmaj7", "major-minor"),
    ("major-sixth", "C6", "major-sixth"), ("minor-sixth", "Cm6", "minor-sixth"),
    ("dominant-ninth", "C9", "dominant-ninth"), ("major-ninth", "Cmaj9", "major-ninth"),
    ("minor-ninth", "Cm9", "minor-ninth"), ("dominant-11th", "C11", "dominant-11th"),
    ("major-11th", "Cmaj11", "major-11th"), ("minor-11th", "Cm11", "minor-11th"),
    ("dominant-13th", "C13", "dominant-13th"), ("major-13th", "Cmaj13", "major-13th"),
    ("minor-13th", "Cm13", "minor-13th"), ("suspended-second", "Csus2", "suspended-second"),
    ("suspended-fourth", "Csus4", "suspended-fourth"),
    ("Neapolitan", "C", "Neapolitan"),
    ("Italian", "C5(add#4,addb6,omit5)", "Italian"),
    ("French", "C5(add2,add#4,addb6,omit5)", "French"),
    ("German", "Cm(add#4,addb6,omit5)", "German"),
    ("pedal", "C5(omit5)", "pedal"), ("power", "C5", "power"),
    ("Tristan", "C5(#9,add#4,add#6,omit5)", "Tristan"),
    ("other", None, None), ("none", "N.C.", "none"),
]
assert len(KINDS) == 33
KIND_ROOTS = ["C", "F#", "B-", "E-", "B"]
# Deliberate differences: music21's Neapolitan type realises 1 b2 3 b5 (C Db E Gb),
# which is not a Neapolitan chord; ours is the major triad on its own root.
DIFFERS = {"Neapolitan"}

kind_rows = []
for kind, text, m21kind in KINDS:
    if text is None:
        kind_rows.append(lisp([kind, None, None, [], ":no-fixed-tones"]))
        continue
    if m21kind == "none":
        kind_rows.append(lisp([kind, text, None, [], ":same"]))
        continue
    for root in KIND_ROOTS:
        cs = harmony.ChordSymbol(root=root, kind=m21kind)
        tones = unique(name_of(p) for p in cs.pitches)
        kind_rows.append(lisp([kind, text, name_of(cs.root()), tones,
                               ":differs" if kind in DIFFERS else ":same"]))

(OUT / "mt3-kinds.sexp").write_text(
    ";; (kind text root tones status), generated by generate-mt3.py with music21 10.5.2.\n"
    ";; KIND is a MusicXML 4.0 <kind> value, TEXT our canonical :pop symbol on C\n"
    ";; (+MUSICXML-KINDS+), ROOT and TONES music21's ChordSymbol(root, kind) realisation.\n"
    ";; STATUS :same, :differs (a deliberate difference, see PROVENANCE.md) or\n"
    ";; :no-fixed-tones (\"other\": no chord of its own).\n("
    + "\n ".join(kind_rows) + ")\n")

# --- Transposition ----------------------------------------------------------
# By interval: music21 ChordSymbol.transpose. By keys: the interval from the
# first key's tonic to the second's (pitch classes, so its direction is moot).

TRANSPOSE_SYMBOLS = [
    ("C7", F("C7")), ("G7/B", F("G7/B")), ("F#m7b5", F("F#ø7")),
    ("Bbmaj7#11", F("B-maj7#11")), ("Ebsus4", F("E-sus4")),
    ("C7alt", K("C", "dominant-seventh", *ALT)), ("Dm9", F("Dm9")),
    ("Ab6/9", K("A-", "major-sixth", ("add", 9, 0))),
    ("B13b9", K("B", "dominant-13th", ("alter", 9, -1))), ("C/F#", F("C/F#")),
    ("E7#9", F("E7#9")), ("C5(omit5)", K("C", "pedal")), ("Gdim7", F("Gdim7")),
    ("Db+M7", F("D-+M7")), ("F#7#9", F("F#7#9")), ("Cb/Db", F("C-/D-")),
]
INTERVALS = ["M2", "m3", "A4", "d5", "m6", "-m2", "A1", "d2"]
KEY_PAIRS = [("C major", "Db major"), ("C major", "C# major"), ("C major", "Cb major"),
             ("A minor", "Bb minor"), ("E minor", "Eb minor"), ("G major", "F# major"),
             ("F major", "E major"), ("C minor", "A minor")]


def key_tonic(name):
    t = name.split()[0]
    return pitch.Pitch(t[0] + TO_M21.get(t[1:], "") + "4")


def status(root, bass, tones):
    if root.startswith("!") or (bass or "").startswith("!"):
        return ":root-out-of-range"
    if any(t.startswith("!") for t in tones):
        return ":tones-out-of-range"
    return ":ok"


transpose_rows = []
for text, recipe in TRANSPOSE_SYMBOLS:
    cs, bass = chord_of(recipe)
    for by in INTERVALS + KEY_PAIRS:
        iv = interval.Interval(by) if isinstance(by, str) else \
            interval.Interval(key_tonic(by[0]), key_tonic(by[1]))
        t = cs.transpose(iv)
        root = name_of(t.root())
        tbass = name_of(bass.transpose(iv)) if bass else None
        tones = unique(name_of(p) for p in t.pitches)
        transpose_rows.append(lisp([text, by if isinstance(by, str) else list(by),
                                    root, tbass, tones, status(root, tbass, tones)]))

(OUT / "mt3-transpose.sexp").write_text(
    ";; (text by root bass tones status), generated by generate-mt3.py with music21 10.5.2.\n"
    ";; BY is an interval name, or (from-key to-key): the interval between their tonics.\n"
    ";; ROOT, BASS, TONES from music21's ChordSymbol.transpose (bass excluded from TONES).\n"
    ";; A name marked \"!\" (music21 spelling) needs more than two accidentals; STATUS says\n"
    ";; whether the root or bass (:root-out-of-range) or only a tone (:tones-out-of-range) does.\n("
    + "\n ".join(transpose_rows) + ")\n")

print(f"{len(symbol_rows)} symbol rows, {len(kind_rows)} kind rows, {len(transpose_rows)} transposition rows")
