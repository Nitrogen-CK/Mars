# The flame card and Flame_Mars_NS

Every Mars flame (torch, lantern, wall torch, brazier, torch sconce; the hearth later) is drawn by **one flame card**
plus one Niagara system for what rises off it, scaled per use. The dressing that owns both is
`Script/WorldObjects/Items/Mars_FlameDressing.as` (`constants_flame_fx`).

**The card** (`FlameCard_Mars_M`, instance `FlameCard_Mars_MI`, mesh `FlameCard_Mars_SM`, all from `mars_flame_ue.py`):
a 48-row strip (the engine Plane has four vertices and cannot curl) on the flame node, rolled upright and scaled W x H
(its scale only sizes the bounds, `BoundsScale` 3). Unlit and **translucent** (a masked card's moving vertices smeared
under motion blur; translucency writes no velocity), with a soft outline (`Edge Feather`) and an exposure-independent
emissive (`Exposure Independence` 1 routes it through EyeAdaptationInverse, so it reads the same in daylight and in a
crypt; `Strength` is its on-screen brightness). The vertex shader rebuilds the strip from its UVs as a billboard about
the vertical axis with its **base pinned at the flame node**; the tip is bent by `Lean` (the card's own world velocity,
negated, on an underdamped spring in the dressing: it trails, overshoots and settles), the part of the lean pointing at
the camera shows as an outward bend (`Toward Camera Bend`), the flame swings rather than stretches (it lowers as it
leans), and a ripple travels up a trailing flame (`Trail Ripple`, `Cycles`, `Speed`). The pixel shader is a round-footed
teardrop SDF warped and eroded by a coarse noise and torn into licks near the tip by a fine one (`Warp`, `Erode`, `Tear`,
`Detail Scale` / `Speed`), white-hot core through the flame `Colour` (the dressing sets the light's colour here) to a
dark-red tip. Custom primitive data per card:

| Slot | Meaning | Written |
|---|---|---|
| 0 | Phase, this flame's random number | once |
| 1 | Intensity 0..1 (the kernel's brightness; 0 dark) | every flicker tick |
| 2-4 | Lean, world cm the tip is pushed | every flicker tick |
| 5 | Enclosed 0 / 1 (1 caps the bend at 0.4 H instead of 1.2 H) | once |
| 6, 7 | Height, Width, cm | once |

**The system** `/Game/Mars/Fx/Flame/Flame_Mars_NS` (`mars_flame_niagara.py`): Embers and Glow only; an archetype
`UNiagaraComponent` on the flame node, created inactive, `Activate(true)` on the kernel's lit edge and `Deactivate()` on
the dark one. The candle draws neither (`FxSize 0`): its mesh bakes a flame on `CandleFlame_Mars_M` and the dressing
darkens that through custom primitive data 1 (`Set_BakedFlame`), as it does the brazier's and the sconce's baked tongues
under the card. The light sits on its own node half the flame height over the flame node (mid-flame).

## User parameters (the contract script relies on)

| Name | Type | Written | Meaning |
|---|---|---|---|
| `Size` | float | once, `FMars_FlameLook.FxSize` | tongue height in cm: torch 18, lantern 10, wall torch / sconce 18, brazier 45, hearth 60 |
| `Intensity` | float | every flicker tick | 0..1, the kernel's brightness (fuel scale x flicker); a gutter dips it, dark is 0 |
| `Colour` | linear color | once, `FMars_FlameLook.Color` | the flame's colour (the same as its light's) |
| `EmberRate` | float | once, `FxEmberRate` (0 when enclosed) | embers per second: torch 6, lantern 0, brazier 20 |
| `Wind` | vector | every flicker tick | world cm/s the flame streams against: the flame node's velocity negated, capped at 400 |
| `Enclosed` | float | once, `FxEnclosed` | 0 open, 1 behind glass: tongues clamp inside the lantern, no embers |

Looping and persistent: no one-shot effect type, no `EFT_DistanceCulledOneShot_Mars`. Local-space emitters: the system
rides the flame node, so everything is in flame-node centimetres with the tongues rooted at the origin.

## Emitters (what `mars_flame_niagara.py` builds; the flame itself is the card)

| Emitter | Spawn | Life | Motion | Material |
|---|---|---|---|---|
| Embers | `User.EmberRate` in the upper third | 1-2.5 s (0 when enclosed) | rise ~1.2 Size/s slowing, three-sine turbulence, Wind drift, point shrinks | `EmberSprite_Mars_MI` |
| Glow | 2/s at 0.45 Size | 1 s | still; two overlap and cross-fade on age (sin^2) | `FlameGlow_Mars_MI` |

Each emitter: `SpawnRate` (emitter update) -> `InitializeParticle` -> `Mars<Emitter>Spawn` (particle spawn) ->
`ParticleState` -> `DynamicMaterialParameters` (registers the attribute) -> `Mars<Emitter>Update` (particle update) ->
one sprite renderer. The dynamic material parameter the update modules write is `(phase, normalized age, Intensity,
Enclosed)`; `Particles.Color.rgb` is the user `Colour`; `Color.a` and `SpriteRotation / 360` carry two per-particle
randoms (only attributes the stack already registered can be used; a new one fails to compile). The CPU VM has no
`smoothstep`. Module bodies live in `mars_flame_hlsl.py`.

## Materials (`mars_flame_ue.py`, built inside the editor)

All three: unlit, additive, two-sided, `Used with Niagara Sprites`, one `Dynamic Parameter` node (slot 0, names
Phase / Age / Intensity / Enclosed) and `Particle Color`.

- `FlameSprite_Mars_M` (unused by the system since the card took over the flame; kept for a particle flame): a teardrop SDF (round foot, narrowing tip, the width profile `0.62 * sqrt(1 - h) * (1 - 0.3 h)`)
  eroded by a scrolling two-octave value noise so the edge licks; `CkUsf_SdfEdgeAA` (include `/CkUsf/Common.ush`) for
  the hard edge plus a soft haze outside it; the candle's flicker idea per sprite with the phase from `Dyn.x`; colour
  ramps Core (white-hot) at the foot of a young tongue, the particle colour in the body, Tip (dark red) at the tip and
  with age; alpha fades with age squared, times `Dyn.z`.
- `EmberSprite_Mars_M`: a soft point, particle colour -> orange -> black by age, through `EyeAdaptationInverse` so an
  ember reads in any room; `Strength` low (0.35) because it is exposure-independent and blooms in the dark.
- `FlameGlow_Mars_M`: radial falloff in the particle colour, `sin^2(age * pi)` so two overlapping glows sum to a steady
  halo.

## Running it

Monolith must be up (9316 is Stephen's editor, 9317 the hidden one; `env_drive.py --port 9317 --launch`):

    python Tools/Blender/mars_environment/unreal/mars_flame_niagara.py --port 9317

Builds the materials first (inside the editor), then the module scripts, the system, the emitters, compiles, prints the
diagnostics and saves. Re-running replaces the system and modules; instance values an artist edited survive. Then
regenerate `Script/Generated/MarsAssets.as` (it is regenerated on editor start) if anything wants `assets::Flame_Mars_NS`;
the dressing itself loads by path and needs nothing.

## Hand-authoring (Monolith down)

Make the same asset by hand in the Niagara editor and the dressing picks it up unchanged:

1. Three materials as above (or run only `mars_flame_ue.build_materials()` through the editor's Python console: it
   needs no Monolith, only `import sys; sys.path.insert(0, r"D:\Repo\Mars\Tools\Blender\mars_environment\unreal")`).
2. Empty Niagara system `Flame_Mars_NS` under `/Game/Mars/Fx/Flame`; user parameters exactly as the table (names,
   types; `Enclosed` is a float, `Wind` a vector, `Colour` a linear color).
3. Two empty CPU emitters named Embers / Glow, Local Space on; per emitter: Spawn Rate (`User.EmberRate` / 2), Initialize Particle, a Scratch Pad module in Particle Spawn with the `NS_*_SPAWN` body and inputs bound to the
   User parameters, Particle State, Dynamic Material Parameters, a Scratch Pad module in Particle Update with the
   `NS_*_UPDATE` body (Embers also reads `Engine.DeltaTime`), a Sprite Renderer on the emitter's `_MI`.
4. Save; place a torch in PIE, light it: the card, embers and glow should appear and dip with a gutter; stow it and the
   effect stops (the dressing deactivates on the dark edge).

## PIE checklist (no lane sees any of this)

Tongues, embers and glow on the torch, the wall torch, the sconce and the brazier; the lantern's tongues inside the
glass with no embers; running streams the torch flame back (Wind); the lantern swings in hand and on the belt and
settles in a few swings; a stow does not whip it (sway Reset on mount change); the candle shows one flame that goes dark
when snuffed; the brazier's baked tongues read as coals until lit.

## Gotchas met building it (Monolith / editor Python)

- A `DynamicParameter` or `VectorParameter` node's first output pin is a scalar / RGB: link `"RGBA"` to read `.w`.
- There is no `MaterialExpressionObjectScale` in Python: sizes go through custom primitive data.
- Monolith's constant setter is `set_module_input_value`; `set_module_input` does not exist.
- The editor caches `mars_flame_hlsl`: `mars_flame_ue` reloads it on import so a module reload picks up new bodies.
- Rebuilding through Stephen's editor (9316) needs `--force` on `env_drive.py` whenever a map is dirty; the build saves
  only the flame assets.

- Build the card mesh only in the hidden editor: `env_drive.py --port 9317 --module mars_flame_ue --alias mf --call
  "mf.build_card_mesh()"`. It writes `Saved/FlameFx/FlameCard_Mars_SM.obj` and imports it as a NEW asset. Never rebuild
  a live mesh's geometry from Python: on 2026-10-30 that shut down the interactive editor.
- `Mars.Flame.DebugLean 1` prints each lit flame's tick rate, step, speed, lean and node / card positions once a second.
- Keep per-tick history in plain members: a `TOptional<FVector>` member read back the current value, and the lean never moved.
