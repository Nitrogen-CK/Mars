# Eyes atlas

The eye-plate look's (`Shaders/Looks/EyePlate.ush`) 8x4 distance-field shape atlas: 128 px cells, index = row * 8 + col, row 0 at the top, `value = clamp(0.5 + signedDistancePx / 32, 0, 1)`.

1. Regenerate the PNG (system Python with numpy + Pillow; ends with a self-check): `python Tools/EyesAtlas/make_eye_atlas.py`
2. Import it (Unreal editor Python, PIE stopped): `py "<ProjectDir>/Tools/EyesAtlas/import_eye_atlas.py"` (absolute path; the script finds the PNG next to itself) → `/Game/Mars/Gameplay/PlayerCharacter/Eyes/Eyes_Atlas_Mars_T` (linear, grayscale, no mips, clamped).

The cell table is the `CELLS` list in `make_eye_atlas.py`. It is **append-only**: styles and expressions store cell indices, so never move or reuse an index; new shapes go in the blank cells 24-31.
Shapes are authored for the plate's right half (U >= 0.5; cell left = inner edge); the look mirrors U for the left half.
