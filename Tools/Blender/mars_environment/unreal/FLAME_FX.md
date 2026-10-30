# Flame_Mars_NS: the one flame effect

Every Mars flame (torch, lantern, wall torch, brazier, torch sconce; the hearth later) is drawn by one Niagara system,
`/Game/Mars/Fx/Flame/Flame_Mars_NS`, scaled per use through user parameters. The dressing that owns it is
`Script/WorldObjects/Items/Mars_FlameDressing.as` (`constants_flame_fx`): an archetype `UNiagaraComponent` on the flame
node, created inactive, `Activate(true)` on the kernel's lit edge and `Deactivate()` on the dark one, parameters below.
The candle draws no Niagara (`FxSize 0`): its mesh bakes a flame on `CandleFlame_Mars_M` and the dressing darkens that
through custom primitive data 1 (`Set_BakedFlame`), as it does the brazier's and the sconce's baked tongues under the
effect.

**Until the asset exists** the dressing falls back to the CkParticles behaviours Fire (3) and SmokePlume (12), spawned at
the flame node and moved with it each tick, Fire scaled by `FxSize / 45`, brightness through `Request_ApplyTuningValues`.
Nothing else needs to change when the asset lands: the dressing finds it by path at construction.

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

## Emitters (what `mars_flame_niagara.py` builds)

| Emitter | Spawn | Life | Motion | Material |
|---|---|---|---|---|
| Tongues | 22/s in a disc of 0.18 Size at the root | 0.35-0.7 s | rise with ease-out to Size (0.8 Size enclosed), two-sine curl capped at 0.3 Size (0.12 enclosed), Wind lean, sprite narrows and shortens | `FlameSprite_Mars_MI` |
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

- `FlameSprite_Mars_M`: a teardrop SDF (round foot, narrowing tip, the width profile `0.62 * sqrt(1 - h) * (1 - 0.3 h)`)
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
3. Three empty CPU emitters named Tongues / Embers / Glow, Local Space on; per emitter: Spawn Rate (22 / `User.EmberRate`
   / 2), Initialize Particle, a Scratch Pad module in Particle Spawn with the `NS_*_SPAWN` body and inputs bound to the
   User parameters, Particle State, Dynamic Material Parameters, a Scratch Pad module in Particle Update with the
   `NS_*_UPDATE` body (Embers also reads `Engine.DeltaTime`), a Sprite Renderer on the emitter's `_MI` (Tongues:
   Velocity Aligned if the look wants the stretch; the update module does not write Velocity, so Camera facing is
   also fine).
4. Save; place a torch in PIE, light it: tongues, embers and glow should appear and dip with a gutter; stow it and the
   effect stops (the dressing deactivates on the dark edge).

## PIE checklist (no lane sees any of this)

Tongues, embers and glow on the torch, the wall torch, the sconce and the brazier; the lantern's tongues inside the
glass with no embers; running streams the torch flame back (Wind); the lantern swings in hand and on the belt and
settles in a few swings; a stow does not whip it (sway Reset on mount change); the candle shows one flame that goes dark
when snuffed; the brazier's baked tongues read as coals until lit.
