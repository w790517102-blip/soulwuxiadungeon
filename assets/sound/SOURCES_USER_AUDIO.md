# User-provided battle audio (2026-11-05)

| Game asset | Source supplied by project owner | Processing | Battle use |
| --- | --- | --- | --- |
| `SE_fist_miss_1.ogg` | `11月5日(1).mp4` | AAC audio extracted, mono 44.1 kHz Vorbis, +6 dB before peak limiting (0.30 linear), 0.10 s fade at the end; 0.65 s total. Measured mean level is about 8 dB above the first extracted version. | Fist/default attack miss or dodge, replacing the earlier sample at the same path |
| `SE_liuchen_lianjue_4hit.ogg` | `11月5日(2).mp4` | AAC audio extracted, mono 44.1 kHz Vorbis, 3x tempo with pitch preserved, +11 dB before peak limiting (0.60 linear), short edge fades; 1.09 s total. Measured mean level is about 8 dB above the first extracted version. | `skill_lianjuejian` with the `liuchen_jue` synergy when all four strikes actually play |

The MP4 sources are kept in the owner's Downloads folder and are not copied into the game project. The three-strike base skill and early target defeat continue using the existing sword sound family.
