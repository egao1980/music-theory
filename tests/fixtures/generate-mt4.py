"""Generate MT4 test vectors (melodies, key detection, key profiles) with music21.

Run from the repo root:
    uv run --with music21==10.5.2 python -I tests/fixtures/generate-mt4.py

Writes tests/fixtures/mt4-melodies.sexp, mt4-key-detection.sexp,
mt4-histograms.sexp and mt4-profiles.sexp, and prints the calibration figures
quoted in PROVENANCE.md.

The melodies below are public-domain tunes re-encoded by us, from memory, as
plain note lists (MIT, like the rest of the repo). They are not copied from any
edition or from music21's corpus, whose encodings carry their own terms. An
encoding may differ from a printed edition in detail; what the tests use is
the spelling and key written here, which are ours. music21 (BSD-3-Clause) is
the oracle: it checks every MIDI number, builds the duration-weighted pitch-class
distribution, and ranks the 24 keys with its Krumhansl-Kessler,
Temperley-Kostka-Payne and Aarden-Essen analyses.

Melody syntax: space-separated notes, "|" bar lines (ignored). A note is our
pitch name (letter, accidental "#" "##" "b" "bb", octave) and an optional
duration: "/n" is 1/n of a whole note, a trailing "." dots it. A note without a
duration repeats the previous one; the first defaults to a quarter. Rests are
left out (they do not change a pitch-class distribution or a spelling).
"""
from fractions import Fraction
from pathlib import Path

from music21 import analysis, interval, key, note, pitch, stream

OUT = Path(__file__).resolve().parent

# (id, key, source, notes). The key is our KEY-NAME text. Modal tunes carry the
# major or minor key their usual key signature and final name (Scarborough Fair
# is E Dorian, written as E minor with C#).
MELODIES = [
    ("ode-to-joy", "D major", "Beethoven, Symphony No. 9 (1824)",
     "F#4/4 F#4 G4 A4 | A4 G4 F#4 E4 | D4 D4 E4 F#4 | F#4/4. E4/8 E4/2 |"
     " F#4/4 F#4 G4 A4 | A4 G4 F#4 E4 | D4 D4 E4 F#4 | E4/4. D4/8 D4/2 |"
     " E4/4 E4 F#4 D4 | E4 F#4/8 G4 F#4/4 D4 | E4 F#4/8 G4 F#4/4 E4 | D4 E4 A3/2 |"
     " F#4/4 F#4 G4 A4 | A4 G4 F#4 E4 | D4 D4 E4 F#4 | E4/4. D4/8 D4/2"),
    ("twinkle", "C major", "French tune 'Ah! vous dirai-je, maman' (1761)",
     "C4/4 C4 G4 G4 | A4 A4 G4/2 | F4/4 F4 E4 E4 | D4 D4 C4/2 | G4/4 G4 F4 F4 |"
     " E4 E4 D4/2 | G4/4 G4 F4 F4 | E4 E4 D4/2 | C4/4 C4 G4 G4 | A4 A4 G4/2 |"
     " F4/4 F4 E4 E4 | D4 D4 C4/2"),
    ("frere-jacques", "F major", "French round (18th century)",
     "F4/4 G4 A4 F4 | F4 G4 A4 F4 | A4 Bb4 C5/2 | A4/4 Bb4 C5/2 |"
     " C5/8 D5 C5 Bb4 A4/4 F4 | C5/8 D5 C5 Bb4 A4/4 F4 | F4 C4 F4/2 | F4/4 C4 F4/2"),
    ("amazing-grace", "Eb major", "Hymn tune 'New Britain' (1829), in E-flat",
     "Bb3/4 | Eb4/2 G4/8 Eb4/8 | G4/2 F4/4 | Eb4/2 C4/4 | Bb3/2 Bb3/4 |"
     " Eb4/2 G4/8 Eb4/8 | G4/2 F4/4 | Bb4/2. | G4/4 Bb4/4. G4/8 | Bb4/8 G4/8 Eb4/2 |"
     " Bb3/4 C4/4. Eb4/8 | Eb4/8 C4/8 Bb3/2 | Bb3/4 Eb4/2 G4/8 Eb4/8 | G4/2 F4/4 | Eb4/2."),
    ("greensleeves", "A minor", "English tune (16th century)",
     "A4/8 | C5/4 D5/8 E5/8. F#5/16 E5/8 | D5/4 B4/8 G4/8. A4/16 B4/8 |"
     " C5/4 A4/8 A4/8. G#4/16 A4/8 | B4/4 G#4/8 E4/4 A4/8 |"
     " C5/4 D5/8 E5/8. F#5/16 E5/8 | D5/4 B4/8 G4/8. A4/16 B4/8 |"
     " C5/8. B4/16 A4/8 G#4/8. F#4/16 G#4/8 | A4/4. A4/4. |"
     " G5/4. G5/8. F#5/16 E5/8 | D5/4 B4/8 G4/8. A4/16 B4/8 |"
     " C5/4 A4/8 A4/8. G#4/16 A4/8 | B4/4 G#4/8 E4/4. |"
     " G5/4. G5/8. F#5/16 E5/8 | D5/4 B4/8 G4/8. A4/16 B4/8 |"
     " C5/8. B4/16 A4/8 G#4/8. F#4/16 G#4/8 | A4/4. A4/4."),
    ("fur-elise", "A minor", "Beethoven, 'Fur Elise', WoO 59 (1810)",
     "E5/16 D#5 E5 D#5 E5 B4 D5 C5 | A4/8 C4/16 E4 A4 | B4/8 E4/16 G#4 B4 |"
     " C5/8 E4/16 E5 D#5 | E5 D#5 E5 B4 D5 C5 | A4/8 C4/16 E4 A4 | B4/8 E4/16 C5 B4 | A4/4"),
    ("rondo-alla-turca", "A minor", "Mozart, Sonata K. 331, finale (1783)",
     "B4/16 A4 G#4 A4 C5/4 | D5/16 C5 B4 C5 E5/4 |"
     " F5/16 E5 D#5 E5 B5 A5 G#5 A5 B5 A5 G#5 A5 C6/4"),
    ("funeral-march", "Bb minor", "Chopin, Sonata No. 2, Op. 35, third movement (1839)",
     "Bb3/4 Bb3/8. Bb3/16 Bb3/4 | Db4/8. C4/16 C4/8. Bb3/16 Bb3/8. A3/16 Bb3/4 |"
     " Bb3/4 Bb3/8. Bb3/16 Bb3/4 | Db4/8. C4/16 C4/8. Bb3/16 Bb3/8. A3/16 Bb3/2"),
    ("entertainer", "C major", "Joplin, 'The Entertainer' (1902)",
     "D5/16 D#5 E5 C6/8 E5/16 C6/8 E5/16 C6/4. | C6/16 D6 D#6 E6 C6 D6 E6/8 B5/16 D6/8 C6/4. |"
     " D5/16 D#5 E5 C6/8 E5/16 C6/8 E5/16 C6/4. | A5/16 G5 F#5 A5 C6 E6/8 D6/16 C6 A5 D6/4."),
    ("minuet-in-g", "G major", "Petzold, Minuet in G, BWV Anh. 114 (c. 1725)",
     "D5/4 G4/8 A4 B4 C5 | D5/4 G4 G4 | E5/4 C5/8 D5 E5 F#5 | G5/4 G4 G4 |"
     " C5/4 D5/8 C5 B4 A4 | B4/4 C5/8 B4 A4 G4 | F#4/4 G4/8 A4 B4 G4 | A4/2. |"
     " D5/4 G4/8 A4 B4 C5 | D5/4 G4 G4 | E5/4 C5/8 D5 E5 F#5 | G5/4 G4 G4 |"
     " C5/4 D5/8 C5 B4 A4 | B4/4 C5/8 B4 A4 G4 | A4/4 B4/8 A4 G4 F#4 | G4/2. |"
     " B5/4 G5/8 A5 B5 G5 | A5/4 D5/8 E5 F#5 D5 | G5/4 E5/8 F#5 G5 D5 |"
     " C#5/4 B4/8 C#5 A4/4 | A4/8 B4 C#5 D5 E5 F#5 | G5/4 F#5 E5 | F#5/4 A4 C#5 | D5/2."),
    ("jingle-bells", "F major", "Pierpont, 'Jingle Bells', refrain (1857)",
     "A4/4 A4 A4/2 | A4/4 A4 A4/2 | A4/4 C5 F4/4. G4/8 | A4/1 | Bb4/4 Bb4 Bb4/4. Bb4/8 |"
     " Bb4/4 A4 A4 A4/8 A4 | A4/4 G4 G4 A4 | G4/2 C5/2 | A4/4 A4 A4/2 | A4/4 A4 A4/2 |"
     " A4/4 C5 F4/4. G4/8 | A4/1 | Bb4/4 Bb4 Bb4 Bb4 | Bb4 A4 A4 A4/8 A4 | C5/4 C5 Bb4 G4 | F4/1"),
    ("silent-night", "Bb major", "Gruber, 'Stille Nacht' (1818), in B-flat",
     "F4/4. G4/8 F4/4 D4/2. | F4/4. G4/8 F4/4 D4/2. | C5/2 C5/4 A4/2. | Bb4/2 Bb4/4 F4/2. |"
     " G4/2 G4/4 Bb4/4. A4/8 G4/4 | F4/4. G4/8 F4/4 D4/2. | G4/2 G4/4 Bb4/4. A4/8 G4/4 |"
     " F4/4. G4/8 F4/4 D4/2. | C5/2 C5/4 Eb5/4. C5/8 A4/4 | Bb4/2. D5/2. |"
     " Bb4/4 F4/4 D4/4 F4/4. Eb4/8 C4/4 | Bb3/2."),
    ("auld-lang-syne", "Ab major", "Scottish tune (18th century), in A-flat",
     "Eb4/4 | Ab4/4. Ab4/8 Ab4/4 C5 | Bb4/4. Ab4/8 Bb4/4 C5/8 Bb4/8 | Ab4/4. Ab4/8 C5/4 Eb5 |"
     " F5/2. F5/4 | Eb5/4. C5/8 C5/4 Ab4 | Bb4/4. Ab4/8 Bb4/4 C5/8 Bb4/8 |"
     " Ab4/4. F4/8 F4/4 Eb4 | Ab4/2."),
    ("scarborough-fair", "E minor", "English ballad (E Dorian)",
     "E4/2 E4/4 | B4/2 B4/4 | F#4/4. G4/8 F#4/4 | E4/2. | B4/4 D5/2 | E5/2 D5/4 |"
     " B4/4 C#5/4 A4/4 | B4/2. | E5/2 E5/4 | E5/2 D5/4 | B4/2 B4/4 | A4/4 G4/4 F#4/4 |"
     " E4/4 D4/2 | E4/2 B4/4 | A4/4 G4/4 F#4/4 | E4/2."),
    ("drunken-sailor", "D minor", "Sea shanty (D Dorian)",
     "A4/8 A4 A4 A4 A4 A4 A4/4 | D4/4 F4 A4 | G4/8 G4 G4 G4 G4 G4 G4/4 | C4/4 E4 G4 |"
     " A4/8 A4 A4 A4 A4 A4 A4/4 | B4/4 C5 D5 | C5/4 A4 G4 E4 | D4/2 D4/2"),
    ("korobeiniki", "A minor", "Russian song 'Korobeiniki' (1861)",
     "E5/4 B4/8 C5 D5/4 C5/8 B4 | A4/4 A4/8 C5 E5/4 D5/8 C5 | B4/4. C5/8 D5/4 E5 |"
     " C5/4 A4 A4/2 | D5/4. F5/8 A5/4 G5/8 F5 | E5/4. C5/8 E5/4 D5/8 C5 |"
     " B4/4 B4/8 C5 D5/4 E5 | C5/4 A4 A4/2"),
    ("canon-in-d", "D major", "Pachelbel, Canon in D, first violin entry (c. 1690)",
     "F#5/2 E5 | D5 C#5 | B4 A4 | B4 C#5 | D5 C#5 | B4 A4 | G4 F#4 | G4 E4"),
    ("brahms-lullaby", "F major", "Brahms, 'Wiegenlied', Op. 49 No. 4 (1868)",
     "A4/8 A4 | C5/4. A4/8 A4/4 | C5/2 A4/8 C5/8 | F5/4 E5/4. D5/8 | D5/4 C5/4 G4/8 A4/8 |"
     " Bb4/4 G4/4 G4/8 A4/8 | Bb4/2 G4/8 Bb4/8 | E5/8 D5/8 C5/4 E5/4 | F5/2."),
    ("eine-kleine", "G major", "Mozart, Serenade K. 525, opening (1787)",
     "G4/4 D4/8 G4/4 D4/8 | G4/8 D4/8 G4/8 B4/8 D5/4 | C5/4 A4/8 C5/4 A4/8 |"
     " C5/8 A4/8 F#4/8 A4/8 D4/4"),
    ("yankee-doodle", "A major", "American song (18th century), in A",
     "A4/8 A4 B4 C#5 A4 C#5 B4 E4 | A4/8 A4 B4 C#5 A4/4 G#4/4 |"
     " A4/8 A4 B4 C#5 D5 C#5 B4 A4 | G#4/8 E4 F#4 G#4 A4/4 A4/4"),
    ("good-morning", "E major", "Hill, 'Good Morning to All' (1893), in E",
     "B3/8. B3/16 C#4/4 B3/4 E4/4 D#4/2 | B3/8. B3/16 C#4/4 B3/4 F#4/4 E4/2 |"
     " B3/8. B3/16 B4/4 G#4/4 E4/4 D#4/4 C#4/4 | A4/8. A4/16 G#4/4 E4/4 F#4/4 E4/2"),
    ("saints", "F major", "Spiritual 'When the Saints Go Marching In'",
     "F4/4 A4 Bb4 C5/1 | F4/4 A4 Bb4 C5/1 | F4/4 A4 Bb4 C5/2 A4/2 | F4/2 A4/2 G4/1 |"
     " A4/4 A4 G4 F4/2. | F4/4 A4/2 C5/2 | C5/4 Bb4/2. | A4/4 Bb4 C5/2 A4/2 | F4/2 G4/2 F4/1"),
    ("oh-susanna", "Gb major", "Foster, 'Oh! Susanna' (1848), in G-flat",
     "Gb4/8 Ab4 | Bb4/4 Db5 Db5/4. Eb5/8 | Db5/4 Bb4 Gb4/4. Ab4/8 | Bb4/4 Bb4 Ab4 Gb4 |"
     " Ab4/2. Gb4/8 Ab4 | Bb4/4 Db5 Db5/4. Eb5/8 | Db5/4 Bb4 Gb4/4. Ab4/8 |"
     " Bb4/4 Bb4 Ab4 Ab4 | Gb4/2."),
    ("toccata", "D minor", "Bach, Toccata in D minor, BWV 565, opening",
     "A5/16 G5 A5/4 G5/32 F5 E5 D5 C#5/8 D5/4"),
    ("swan-lake", "B minor", "Tchaikovsky, 'Swan Lake', scene (1876)",
     "F#5/2. | B4/8 C#5 D5 E5 | F#5/4. D5/8 F#5/4. D5/8 | F#5/4. B4/8 D5 B4 G4 D5 | B4/2. |"
     " F#5/2. | B4/8 C#5 D5 E5 | F#5/4. D5/8 F#5/4. D5/8 | F#5/4. B4/8 D5 B4 G4 D5 | B4/2."),
    ("beethoven-5", "C minor", "Beethoven, Symphony No. 5, opening (1808)",
     "G4/8 G4 G4 Eb4/2 | F4/8 F4 F4 D4/2 | G4/8 G4 G4 Eb4/8 Ab4 Ab4 Ab4 G4/8 Eb5 Eb5 Eb5 C5/2"),
    ("mozart-40", "G minor", "Mozart, Symphony No. 40, K. 550, opening (1788)",
     "Eb5/8 D5 D5/4 Eb5/8 D5 D5/4 Eb5/8 D5 D5/4 Bb5/4 | Bb5/8 A5 G5/4 G5/8 F5 Eb5/4"
     " Eb5/8 D5 C5/4 C5/4 | D5/8 C5 C5/4 D5/8 C5 C5/4 D5/8 C5 C5/4 A5/4 |"
     " A5/8 G5 F#5/4 F#5/8 Eb5 D5/4 D5/8 C5 Bb4/4 Bb4/4"),
    ("little-fugue", "G minor", "Bach, Fugue in G minor, BWV 578, subject",
     "G4/4 D5 Bb4/4. A4/8 G4/8 Bb4 A4 G4 F#4 A4 D4/4 |"
     " G4/8 D4 A4 D4 Bb4 A4/16 G4 A4/8 D4 | G4/8 D4 A4 D4 Bb4 A4/16 G4 A4/8 D4"),
    ("badinerie", "B minor", "Bach, Orchestral Suite No. 2, Badinerie",
     "B5/8 D6/16 B5 F#5/8 B5/16 F#5 D5/8 F#5/16 D5 B4/4 |"
     " F#4/16 B4 D5 B4 C#5 B4 C#5 B4 A#4 C#5 E5 C#5 D5/8 B4/8"),
    ("spring", "E major", "Vivaldi, 'Spring', RV 269, opening (1725)",
     "E5/8 | G#5 G#5 G#5 F#5/16 E5 B5/4. B5/16 A5 | G#5/8 G#5 G#5 F#5/16 E5 B5/4. B5/16 A5 |"
     " G#5/8 A5/16 B5 A5/8 G#5/8 F#5/4"),
    ("promenade", "Bb major", "Mussorgsky, 'Pictures at an Exhibition', Promenade (1874)",
     "G4/4 F4 Bb4 C5/8 F5 D5/4 C5/8 F5 D5/4 Bb4 C5 G4 F4"),
    ("bourree", "E minor", "Bach, Lute Suite in E minor, BWV 996, Bourree",
     "E4/8 F#4 | G4/4 F#4/8 E4 | D#4/4 E4/8 F#4 | B3/4 C#4/8 D#4 | E4/4 D4/8 C4 |"
     " B3/4 A3/8 G3 | F#3/4 G3/8 A3 | B3/8 A3 G3 F#3 | E3/2"),
    ("take-me-out", "C major", "Von Tilzer, 'Take Me Out to the Ball Game' (1908), in C",
     "C4/2 C5/4 | A4/4 G4 E4 | G4/2. | D4/2. | C4/2 C5/4 | A4/4 G4 E4 | G4/2. | G4/2 A4/4 |"
     " G#4/4 A4 E4 | F4/4 G4 A4 | F4/2 D4/4 | A4/2. | A4/4 A4 B4 | C5/4 D5 B4 | A4/4 G4 E4 | D4/2."),
    ("mountain-king", "B minor", "Grieg, 'In the Hall of the Mountain King' (1875)",
     "B3/8 C#4 D4 E4 | F#4 D4 F#4/4 | E#4/8 C#4 E#4/4 | E4/8 C4 E4/4 | B3/8 C#4 D4 E4 |"
     " F#4 D4 F#4 B4 | A4 F#4 D4 F#4 | A4/2"),
    ("blue-danube", "D major", "J. Strauss II, 'The Blue Danube' (1866)",
     "D4/4 | D4 F#4 A4 | A4/2 A5/4 A5/2 F#5/4 F#5/2 D4/4 | D4 F#4 A4 |"
     " A4/2 A5/4 A5/2 G5/4 G5/2 C#4/4 | C#4 E4 B4 | B4/2 B5/4 B5/2 G5/4 G5/2 C#4/4 |"
     " C#4 E4 B4 | B4/2 B5/4 B5/2 F#5/4 F#5/2 D4/4 | D4 F#4 A4 |"
     " D5/2 D6/4 D6/2 A5/4 A5/2 D4/4 | D4 F#4 A4 | D5/2 D6/4 D6/2 B5/4 B5/2 E4/4 |"
     " E4 G4 B4 | B4/2 B5/4 B5/2 G#5/4 A5/2"),
    ("largo", "Db major", "Dvorak, Symphony No. 9, Largo (1893)",
     "F4/4. Ab4/8 Ab4/2 | F4/4. Eb4/8 Db4/2 | Eb4/4. F4/8 Ab4/4. F4/8 | Eb4/1 |"
     " F4/4. Ab4/8 Ab4/2 | F4/4. Eb4/8 Db4/2 | Eb4/4. F4/8 Eb4/4. Db4/8 | Db4/1"),
    ("la-donna-e-mobile", "B major", "Verdi, 'Rigoletto', 'La donna e mobile' (1851)",
     "F#4/8 F#4 F#4 A#4/8. G#4/16 E4/4 | E4/8 E4 E4 G#4/8. F#4/16 D#4/4 |"
     " F#4/8 F#4 F#4 B4/8. A#4/16 G#4/4 | G#4/8 G#4 G#4 B4/8. A#4/16 F#4/4"),
    ("gymnopedie", "D major", "Satie, Gymnopedie No. 1 (1888)",
     "F#5/4 A5 G5 F#5 C#5 B4 C#5 D5 A4/2. F#4/1"),
    ("moldau", "E minor", "Smetana, 'Ma vlast', Vltava (1874)",
     "E4/4 | B4/2 C5/4 | D5/2 E5/4 | B4/2 B4/4 | A4/2 A4/4 | G4/2 G4/4 | F#4/2 F#4/4 |"
     " E4/2 E4/4 | B4/2 C5/4 | D5/2 E5/4 | B4/2 B4/4 | A4/2 A4/4 | G4/2 G4/4 | F#4/2 F#4/4 | E4/2."),
    ("joy-to-the-world", "D major", "Hymn tune 'Antioch' (1839)",
     "D5/4 C#5/8. B4/16 A4/4. G4/8 | F#4/4 E4/4 D4/4. A4/8 | B4/4. B4/8 C#5/4. C#5/8 |"
     " D5/2. D5/8 D5/8 | C#5/8 B4 A4 A4/8. G4/16 F#4/8 D5 D5 C#5 B4 A4 A4/8. G4/16 F#4/8 |"
     " F#4 F#4 F#4 F#4 F#4/16 G4 A4/4. G4/16 F#4 E4/8 E4 E4 E4/16 F#4 G4/4. F#4/16 E4 |"
     " D4/8 D5/4 B4/8 A4/8. G4/16 F#4/8 G4/8 F#4/4 E4/4 D4/2"),
    ("o-come-all-ye-faithful", "A major", "Hymn tune 'Adeste fideles' (1751), in A",
     "A4/4 | A4/2 E4/4 A4/4 | B4/2 E4/2 | C#5/4 B4/4 C#5/4 D5/4 | C#5/2 B4/4 A4/4 |"
     " A4/2 G#4/4 F#4/4 | G#4/4 A4/4 B4/4 C#5/4 | G#4/2 F#4/4. E4/8 | E4/1"),
    ("bridal-chorus", "Bb major", "Wagner, 'Lohengrin', Bridal Chorus (1850)",
     "F4/4 | Bb4/4. Bb4/8 Bb4/2 | F4/4 C5/4 A4/4 Bb4/4 | F4/4 Bb4/4. Eb5/8 Eb5/4 |"
     " D5/4 C5/4 Bb4/4 A4/4 | Bb4/4 C5/2"),
    ("invention-4", "D minor", "Bach, Invention No. 4, BWV 775, subject",
     "D4/16 E4 F4 G4 A4 Bb4 | C#4 Bb4 A4 G4 F4 E4 | F4/8 A4/8 D5/8"),
    ("jesu-joy", "G major", "Bach, Cantata BWV 147, 'Jesu, Joy of Man's Desiring' (1723)",
     "G4/12 A4 B4 D5 C5 C5 E5 D5 D5 G5 F#5 G5 D5 B4 G4 A4 B4 C5 D5 E5 D5 C5 B4 A4 |"
     " B4 G4 F#4 G4 A4 D4 F#4 A4 C5 B4 A4 B4"),
    ("we-three-kings", "E minor", "Hopkins, 'We Three Kings' (1857)",
     "B4/4 A4/8 G4/4 E4/8 | F#4/8 G4 F#4 E4/4. | B4/4 A4/8 G4/4 E4/8 | F#4/8 G4 F#4 E4/4. |"
     " G4/4 G4/8 A4/4 A4/8 | B4/8 B4 B4 D5 C5 B4 | A4/8 B4 A4 G4/4 F#4/8 | E4/4."),
    ("god-rest-ye", "F minor", "English carol 'God Rest You Merry, Gentlemen', in F minor",
     "F4/4 F4 C5 C5 | Bb4 Ab4 G4 F4 | Eb4 F4 G4 Ab4 | Bb4 C5/2. | F4/4 F4 C5 C5 |"
     " Bb4 Ab4 G4 F4 | Eb4 F4 G4 Ab4 | Bb4 C5/2. | C5/4 Db5 Bb4 C5 | Db5 Eb5 F5 C5 |"
     " Bb4 Ab4 F4 G4 | Ab4 Bb4/2 Ab4/4 | Bb4 C5/2 Db5/4 | C5 C5 Bb4 Ab4 | G4 F4/2 Ab4/8 G4/8 |"
     " F4/4 Bb4/2 Ab4/4 | Bb4 C5 Db5 Eb5 | F5 C5 Bb4 Ab4 | G4 F4/2."),
    ("dies-irae", "D minor", "Plainchant sequence 'Dies irae'",
     "F4/4 E4 F4 D4 E4 C4 D4/2 D4/4 | F4 F4 G4 F4 E4 D4 C4 E4 F4 E4 D4/2"),
    ("deck-the-halls", "F major", "Welsh carol 'Nos Galan'",
     "C5/4. Bb4/8 A4/4 G4 | F4 G4 A4 F4 | G4/8 A4 Bb4 G4 A4/4. G4/8 | F4/4 E4 F4/2 |"
     " C5/4. Bb4/8 A4/4 G4 | F4 G4 A4 F4 | G4/8 A4 Bb4 G4 A4/4. G4/8 | F4/4 E4 F4/2 |"
     " G4/4. A4/8 Bb4/4 G4 | A4/4. Bb4/8 C5/4 G4 | A4/8 B4 C5/4 D5/8 E5 F5/4 | E5/4 D5 C5/2"),
    ("good-king-wenceslas", "G major", "Tune 'Tempus adest floridum' (1582)",
     "G4/4 G4 G4 A4 | G4 G4 D4/2 | E4/4 D4 E4 F#4 | G4/2 G4/2 | G4/4 G4 G4 A4 |"
     " G4 G4 D4/2 | E4/4 D4 E4 F#4 | G4/2 G4/2 | D5/4 C5 B4 A4 | B4 A4 G4/2 |"
     " E4/4 D4 E4 F#4 | G4/2 G4/2 | D4/4 D4 E4 F#4 | G4 G4 A4/2 | D5/4 C5 B4 A4 |"
     " G4/2 C5/2 | G4/1"),
    ("god-save-the-king", "G major", "Anthem 'God Save the King' (1745)",
     "G4/4 G4 A4 | F#4/4. G4/8 A4/4 | B4/4 B4 C5 | B4/4. A4/8 G4/4 | A4/4 G4 F#4 | G4/2. |"
     " D5/4 D5 D5 | D5/4. C5/8 B4/4 | C5/4 C5 C5 | C5/4. B4/8 A4/4 |"
     " B4/4 C5/8 B4 A4 G4 | B4/4. C5/8 D5/4 | E5/8 C5 B4/4 A4/4 | G4/2."),
]

PROFILES = [
    (":krumhansl-kessler", analysis.discrete.KrumhanslKessler),
    (":temperley", analysis.discrete.TemperleyKostkaPayne),
    (":aarden", analysis.discrete.AardenEssen),
]

# The 24 candidate keys of DETECT-KEY, our spelling (src/key-detect.lisp).
MAJOR_TONICS = ["C", "Db", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"]
MINOR_TONICS = ["C", "C#", "D", "Eb", "E", "F", "F#", "G", "G#", "A", "Bb", "B"]


def candidate(pc, mode):
    return f"{(MAJOR_TONICS if mode == 'major' else MINOR_TONICS)[pc]} {mode}"


# --- Reading the melodies ---------------------------------------------------

def parse_notes(text):
    notes, duration = [], Fraction(1, 4)
    for token in text.replace("|", " ").split():
        name, _, value = token.partition("/")
        if value:
            dotted = value.endswith(".")
            duration = Fraction(1, int(value.rstrip(".")))
            if dotted:
                duration *= Fraction(3, 2)
        notes.append((name, duration))
    return notes


def m21_pitch(name):
    """Our pitch name ("Bb4", "F#4", "E#4") as a music21 Pitch."""
    letter, rest = name[0], name[1:]
    accidental = rest.rstrip("-0123456789")
    octave = rest[len(accidental):]
    m21 = accidental.replace("b", "-")
    return pitch.Pitch(letter + m21 + octave)


def spelling_of(p):
    """A music21 pitch in our ASCII spelling, with octave."""
    alter = int(p.alter)
    return p.step + {-2: "bb", -1: "b", 0: "", 1: "#", 2: "##"}[alter] + str(p.octave)


def melody_stream(notes):
    s = stream.Stream()
    for name, duration in notes:
        n = note.Note(m21_pitch(name))
        n.quarterLength = duration * 4
        s.append(n)
    return s


def key_of(text):
    tonic, mode = text.split()
    return key.Key(tonic.replace("b", "-") if len(tonic) > 1 else tonic, mode)


def same_key(text, pc, mode):
    k = key_of(text)
    return k.tonic.pitchClass == pc and k.mode == mode


# --- Key analysis -------------------------------------------------------------

def exact_order(cls, histogram):
    """The 24 candidates, best first, ranked exactly: Pearson r compared in rational
    arithmetic (r1 > r2 iff sign(c1) c1^2 v2 > sign(c2) c2^2 v1, with c the
    covariance and v the profile's variance; the histogram's variance is common).
    Exact ties keep the candidate order (C major, C minor, Db major, C# minor, ...)."""
    h = [Fraction(x) for x in histogram]
    hm = sum(h) / 12
    scored = []
    for index in range(24):
        pc, mode = divmod(index, 2)
        mode = "major" if mode == 0 else "minor"
        w = [Fraction(str(x)) for x in cls().getWeights(mode)]
        wm = sum(w) / 12
        cov = sum((w[(j - pc) % 12] - wm) * (h[j] - hm) for j in range(12))
        var = sum((x - wm) ** 2 for x in w)
        scored.append((index, candidate(pc, mode), cov, var))

    def better(a, b):
        ka = (1 if a[2] > 0 else -1 if a[2] < 0 else 0) * a[2] ** 2 * b[3]
        kb = (1 if b[2] > 0 else -1 if b[2] < 0 else 0) * b[2] ** 2 * a[3]
        return (ka > kb) - (ka < kb)

    import functools
    ordered = sorted(scored, key=functools.cmp_to_key(lambda a, b: -better(a, b) or a[0] - b[0]))
    ties = {(a[1], b[1]) for a in scored for b in scored if a is not b and better(a, b) == 0}
    return [t for _, t, _, _ in ordered], ties


def ranked(cls, s, histogram):
    """music21's ranking: [(our key text, correlation)], best first, with exact ties
    put in candidate order (see EXACT-ORDER)."""
    solution = cls().getSolution(s)
    keys = [solution] + list(solution.alternateInterpretations)
    out = [(candidate(k.tonic.pitchClass, k.mode), float(k.correlationCoefficient)) for k in keys]
    assert len(out) == 24 and len({t for t, _ in out}) == 24, out
    order, ties = exact_order(cls, histogram)
    corr = dict(out)
    # music21's float order agrees with the exact order, except inside exact ties.
    for (a, ca), (b, cb) in zip(out, out[1:]):
        assert ca >= cb, out
        if (a, b) not in ties:
            assert order.index(a) < order.index(b), (a, b, out)
    return [(t, corr[t]) for t in order], len(ties) // 2


def histogram_of(notes):
    h = [Fraction(0)] * 12
    for name, duration in notes:
        h[m21_pitch(name).pitchClass] += duration
    return h


def lisp_string(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def dfloat(x):
    return repr(float(x)).replace("e", "d") + ("" if "e" in repr(float(x)) else "d0")


def ratio(f):
    return str(f.numerator) if f.denominator == 1 else f"{f.numerator}/{f.denominator}"


def ranking_text(rows):
    return "(" + " ".join(f"({lisp_string(t)} {dfloat(c)})" for t, c in rows) + ")"


melody_rows, detection_rows = [], []
stats = {name: [0, 0] for name, _ in PROFILES}
for ident, key_text, source, text in MELODIES:
    notes = parse_notes(text)
    s = melody_stream(notes)
    names = [name for name, _ in notes]
    # Round trip through music21: our spelling survives, and gives the MIDI number.
    for name, n in zip(names, s.notes):
        assert spelling_of(n.pitch) == name, (ident, name, n.pitch)
    midis = [n.pitch.midi for n in s.notes]
    melody_rows.append(
        f"({lisp_string(ident)} {lisp_string(key_text)}\n"
        f"  ({' '.join(lisp_string(n) for n in names)})\n"
        f"  ({' '.join(ratio(d) for _, d in notes)})\n"
        f"  ({' '.join(str(m) for m in midis)}))")
    for profile, cls in PROFILES:
        rows, _ = ranked(cls, s, histogram_of(notes))
        top = [tuple(t.split()) for t, _ in rows[:2]]
        hits = [same_key(key_text, key_of(t).tonic.pitchClass, key_of(t).mode)
                for t, _ in rows[:2]]
        stats[profile][0] += hits[0]
        stats[profile][1] += hits[0] or hits[1]
        detection_rows.append(f"({lisp_string(ident)} {profile}\n  {ranking_text(rows)})")

header = ";; Generated by generate-mt4.py with music21 10.5.2. Do not edit.\n"

(OUT / "mt4-melodies.sexp").write_text(
    header
    + ";; (id key names durations midis): a public-domain melody re-encoded by us, its\n"
    + ";; key (KEY-NAME text), the notated spelled pitches, durations in whole notes, and\n"
    + ";; music21's MIDI number of each pitch.\n(\n"
    + "\n".join(melody_rows) + "\n)\n", encoding="utf-8")

(OUT / "mt4-key-detection.sexp").write_text(
    header
    + ";; (id profile ranking): music21's ranking of the 24 keys for the melody's\n"
    + ";; duration-weighted pitch-class distribution, best first, as (key correlation).\n"
    + ";; Keys are spelled as DETECT-KEY's candidates. :temperley is music21's\n"
    + ";; TemperleyKostkaPayne, :aarden its AardenEssen.\n(\n"
    + "\n".join(detection_rows) + "\n)\n", encoding="utf-8")

# --- Profiles -----------------------------------------------------------------

profile_rows = []
for profile, cls in PROFILES:
    a = cls()
    major = " ".join(ratio(Fraction(str(w))) for w in a.getWeights("major"))
    minor = " ".join(ratio(Fraction(str(w))) for w in a.getWeights("minor"))
    profile_rows.append(f"({profile}\n  ({major})\n  ({minor}))")

(OUT / "mt4-profiles.sexp").write_text(
    header + ";; (profile major minor): music21's getWeights, tonic first, as the exact\n"
    + ";; rationals of the decimals it prints (6.35 = 127/20).\n(\n"
    + "\n".join(profile_rows) + "\n)\n", encoding="utf-8")

# --- Synthetic histograms -----------------------------------------------------

HISTOGRAMS = [
    ("c-major-scale", [1, 0, 1, 0, 1, 1, 0, 1, 0, 1, 0, 1]),
    ("a-harmonic-minor", [1, 0, 1, 0, 1, 1, 0, 0, 1, 1, 0, 1]),
    ("c-only", [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
    ("c-e-g", [2, 0, 0, 0, 1, 0, 0, 1, 0, 0, 0, 0]),
    ("c-eb-g", [2, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0]),
    ("f-sharp-major-triad", [0, 1, 0, 0, 0, 0, 2, 0, 0, 0, 1, 0]),
    ("eb-minor-triad", [0, 0, 0, 2, 0, 0, 1, 0, 0, 0, 1, 0]),
    ("weighted", [Fraction(7, 2), 0, Fraction(5, 4), Fraction(1, 8), 3, 2, Fraction(1, 2),
                  4, 0, Fraction(3, 2), Fraction(1, 4), Fraction(5, 2)]),
    ("krumhansl-1990-example", [7, 0, 5, 0, 7, 16, 0, 16, 0, 15, 6, 0]),
]

histogram_rows = []
for label, weights in HISTOGRAMS:
    s = stream.Stream()
    for pc, w in enumerate(weights):
        if w:
            n = note.Note(pc + 60)
            n.quarterLength = w
            s.append(n)
    cells = " ".join(ratio(Fraction(w)) for w in weights)
    for profile, cls in PROFILES:
        rows, ties = ranked(cls, s, weights)
        if ties:
            print(f"{label} {profile}: {ties} exact ties, in candidate order")
        histogram_rows.append(
            f"({lisp_string(label)} ({cells}) {profile}\n  {ranking_text(rows)})")

(OUT / "mt4-histograms.sexp").write_text(
    header
    + ";; (label histogram profile ranking): a 12-cell histogram (index = pitch class),\n"
    + ";; and music21's ranking of the 24 keys for it, as in mt4-key-detection.sexp.\n(\n"
    + "\n".join(histogram_rows) + "\n)\n", encoding="utf-8")

# --- Transposition -------------------------------------------------------------
#
# Each melody moved to the keys five fifths above and below its own, respelled by
# music21's Stream.transpose. The target key follows CHOOSE-ENHARMONIC-KEY's
# default (at most six accidentals; within that, the given spelling), and the
# interval is TRANSPOSE-TO-KEY's: from the source tonic to the target tonic with
# the letter moving at most three steps.

LETTER_FIFTHS = {"F": -1, "C": 0, "G": 1, "D": 2, "A": 3, "E": 4, "B": 5}
NATURAL = {v: k for k, v in LETTER_FIFTHS.items()}
SIGNATURE_OFFSET = {"major": 0, "minor": -3}


def tonic_fifths(name):
    return LETTER_FIFTHS[name[0]] + 7 * (name.count("#") - name.count("b"))


def fifths_name(f):
    alter = (f + 1) // 7
    return NATURAL[f - 7 * alter] + {-2: "bb", -1: "b", 0: "", 1: "#", 2: "##"}[alter]


def moved_key(key_text, shift):
    tonic, mode = key_text.split()
    f = tonic_fifths(tonic) + shift
    sig = f + SIGNATURE_OFFSET[mode]
    if sig > 6:
        f -= 12
    elif sig < -6:
        f += 12
    return f"{fifths_name(f)} {mode}"


def tonic_interval(from_key, to_key):
    """TRANSPOSE-TO-KEY's interval: FROM's tonic in octave 4 to TO's tonic, the
    letter moving at most three steps."""
    a = m21_pitch(from_key.split()[0] + "4")
    b_name = to_key.split()[0]
    best = None
    for octave in (3, 4, 5):
        b = m21_pitch(b_name + str(octave))
        steps = b.diatonicNoteNum - a.diatonicNoteNum
        if -3 <= steps <= 3:
            best = b
    return interval.Interval(noteStart=a, noteEnd=best)


transposed_rows = []
for ident, key_text, _, text in MELODIES:
    notes = parse_notes(text)
    s = melody_stream(notes)
    for shift in (5, -5):
        to_key = moved_key(key_text, shift)
        iv = tonic_interval(key_text, to_key)
        moved = s.transpose(iv)
        names = []
        for n in moved.notes:
            assert abs(n.pitch.alter) <= 2, (ident, to_key, n.pitch)
            names.append(spelling_of(n.pitch))
        midis = [n.pitch.midi for n in moved.notes]
        transposed_rows.append(
            f"({lisp_string(ident)} {lisp_string(key_text)} {lisp_string(to_key)} {lisp_string(iv.directedName)}\n"
            f"  ({' '.join(lisp_string(n) for n in names)})\n"
            f"  ({' '.join(str(m) for m in midis)}))")

(OUT / "mt4-transposed.sexp").write_text(
    header
    + ";; (id from-key to-key interval names midis): each melody of mt4-melodies.sexp moved\n"
    + ";; five fifths up and down by music21's Stream.transpose (spelling kept), the\n"
    + ";; music21 interval name, the new spelled pitches and their MIDI numbers.\n(\n"
    + "\n".join(transposed_rows) + "\n)\n", encoding="utf-8")

# --- Calibration figures (PROVENANCE.md) ----------------------------------------

total = len(MELODIES)
notes_total = sum(len(parse_notes(t)) for *_, t in MELODIES)
print(f"{total} melodies, {notes_total} notes")
for profile, _ in PROFILES:
    top1, top2 = stats[profile]
    print(f"{profile}: top-1 {top1}/{total} = {top1 / total:.1%}, "
          f"top-2 {top2}/{total} = {top2 / total:.1%}")


def music21_spelling(midis, key_text, window):
    """music21's own pitch speller (pitch.simplifyMultipleEnharmonics), window by window."""
    out = []
    context = key_of(key_text) if key_text else None
    for i in range(0, len(midis), window):
        out += pitch.simplifyMultipleEnharmonics(midis[i:i + window], keyContext=context)
    return [p.name for p in out]


for label, with_key in (("with the key", True), ("without a key", False)):
    right = 0
    for ident, key_text, _, text in MELODIES:
        notes = parse_notes(text)
        midis = [m21_pitch(n).midi for n, _ in notes]
        names = music21_spelling(midis, key_text if with_key else None, 8)
        right += sum(m21_pitch(n).name == got for (n, _), got in zip(notes, names))
    print(f"music21 simplifyMultipleEnharmonics (windows of 8), {label}: "
          f"{right}/{notes_total} = {right / notes_total:.2%}")

right = total_moved = 0
for ident, key_text, _, text in MELODIES:
    s = melody_stream(parse_notes(text))
    for shift in (5, -5):
        to_key = moved_key(key_text, shift)
        moved = s.transpose(tonic_interval(key_text, to_key))
        midis = [n.pitch.midi for n in moved.notes]
        names = music21_spelling(midis, to_key, 8)
        right += sum(n.pitch.name == got for n, got in zip(moved.notes, names))
        total_moved += len(midis)
print(f"music21 simplifyMultipleEnharmonics (windows of 8), transposed melodies with the key: "
      f"{right}/{total_moved} = {right / total_moved:.2%}")
