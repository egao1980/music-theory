# music-theory

Spelled pitches, intervals, keys and scales, meter and rational time, transposition and respelling, a chord-symbol grammar with dialects, Roman numerals, key detection, and key fit with a tuning offset. Pure Common Lisp, no dependencies.

**Status:** MT0–MT4 and the 0.5.1 and 0.5.2 amendments are implemented (OCI 0.5.2). **MT5 contract (0.6.0):** key fit with a tuning offset ([#22](https://github.com/egao1980/music-theory/issues/22)). The contract is the rules in the header of `src/key-fit.lisp`, the `%mt5-pending` stubs and the Rove suite in `tests/mt5-test.lisp`, which is the specification. The design and its locked decisions are in the capability brief [cl-stack/docs/capabilities/music-theory.md](https://github.com/egao1980/cl-stack/blob/main/docs/capabilities/music-theory.md).

```sh
cl-repo test --system music-theory
```

| File | Contents |
|------|----------|
| `src/pitch.lisp`, `src/fifths.lisp`, `src/interval.lisp` | spelled pitches, the line of fifths, intervals (MT0) |
| `src/meter.lisp`, `src/time.lisp`, `src/tempo.lisp` | meter and metric weight, durations and tie splitting, tempo and phrase windows (MT1) |
| `src/key.lisp`, `src/chord.lisp`, `src/roman.lisp` | keys, scales and degrees, the chord-symbol value, Roman numerals (MT2) |
| `src/chord-symbol.lisp`, `src/chord-tones.lisp` | the chord-symbol grammar, dialects and printer; realisation, essential tones, transposition; MusicXML `<kind>` (MT3, 0.5.1) |
| `src/spell.lisp`, `src/transpose.lisp` | spelling with the deciding rule, transposition between keys, enharmonic keys (MT4, 0.5.1, 0.5.2) |
| `src/key-detect.lisp` | `pitch-class-histogram`, `detect-key` (MT4); **contract:** real pitches with cents in `pitch-class-histogram`, split between the two nearest classes (MT5) |
| `src/key-fit.lisp` | `key-fit`, `make-key-fit` and `+key-fit-offsets+` (given); **contract:** `fit-key`, the joint search over the 24 keys and the offsets -50 … 49 cents (MT5) |
| `src/conditions.lisp` | the conditions of every slice; `no-key-evidence` (given, MT5) |

## License

MIT, see [LICENSE](LICENSE).
