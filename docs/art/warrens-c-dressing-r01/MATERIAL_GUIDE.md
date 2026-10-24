# Warrens C / texture and material specification

## What is supplied

19 restrained surface families, each with five maps: BaseColor, ORM, NormalGL, NormalDX, Height. There are95 surface PNGs at1024x1024. The procedural fields are UV-periodic and the outermost texels match exactly in both axes. These are code-native material resources; six separate decorative art sources were generated with the built-in image tool. No AI picture is relabeled as a measured PBR/normal map.

AT01 is a32-swatch palette (512x256), AT02 is the architecture trim and AT03 the prop trim (each1024x1024, five maps), AT04 is the glyph/navigation RGBA atlas (1024x2048). Palette and trim UV metadata are included. Individual icons are256x256 PNG and editable SVG. Four wear decals, two water normal conventions, one periodic water breakup/foam map and a flame card complete the texture inputs.

## Map contract

| Map | Data | Blender | Eventual Unreal import |
|---|---|---|---|
| BaseColor | sRGB RGB, no baked directional illumination | Image sRGB -> Base Color | sRGB on; base-color/default compression |
| ORM.R | local material cavity AO | Separate Color R, optional AO input | Linear, masks compression; do not treat as opacity |
| ORM.G | roughness | Separate Color G -> Roughness | Linear, masks compression |
| ORM.B | metallic (patina lowers metal response) | Separate Color B -> Metallic | Linear, masks compression |
| NormalGL | tangent space +Y | Non-Color -> Normal Map -> Normal | Do not import this as the default DX map |
| NormalDX | same tangent field, inverted green | unused by library | Normalmap compression, sRGB off; use this OR flip GL green, never both |
| Height |16-bit single channel, midpoint neutral | optional, not wired into displacement | Linear; optional future material input; no geometry/collision displacement |
| Alpha art | straight-alpha PNG | RGB -> Base Color, A -> Alpha | Use an appropriate masked/decal material; preserve clean alpha |

Normal maps derive from the same declared millimetre-scale height field; green convention and tiling are validated. Height decode is (value/65535-0.5)*2*relief_mm. Normal strength1 already represents a deliberately quiet surface; increase only after inspecting actual mesh scale. No roughness/normal images were invented by image generation.

## UV and scale

`materials.json` gives physical repeat width/height in metres per tile. Example:TX01 is2m x2m, hence one UV repeat per2m. Wood grain runs along texture V: rotate UVs to follow a beam. Use repeat addressing for surface maps. The tiny shared palette is sampled at the documented swatch centers using nearest/closest filtering; reserve it for flat-colored faces, or store the equivalent swatch in vertex RGB.

Trim sheets repeat ONLY along U. Select one horizontal V band inside `trim_metadata.json` bounds. The8px V inset is a gutter, not useful art space. Do not wrap V, cross a lane boundary, or shrink the entire chart onto a hero prop. AO/roughness/metal data are separate even when a trim row has a constant color. Trim Height is neutral: no fake strip-edge displacement is promised.

The six generated transparent sources are native1254x1254 PNGs and intentionally preserved unchanged. They are directly usable as Blender image inputs. For final streaming/mip atlases, bake them onto the prop's power-of-two atlas during prop production; do not claim the native non-power-of-two files have already been engine-streaming qualified. Keep padding around alpha islands. Exact gameplay glyphs come from the vector/256px files, not painted emblems.

## Base-color ownership and the project materials

This package does not replace the current CkUsf/ProtoGrid masters or physical-material routing. Offline Blender materials demonstrate the maps. A later approved Unreal art pass must adapt them to the project's surface setup while preserving collision, physical materials and entity presentation ownership.

Choose one base-color owner per mesh: vertex RGB/palette OR the colored BaseColor image. Do not multiply two fully colored albedos together. For painted meshes using the project's RGB-albedo/A-cavity convention, preserve those channels; confirm each architecture material's actual vertex contract before assigning masks. ORM.R is material microcavity and is not a bake of an individual prop's scene shadows. The library deliberately does not multiply AO into the base color.

## Shader recipes

- **Opaque stone/wood/bone/cloth:** BaseColor + ORM + correct normal map; opaque surface; no emission. Keep large faceted geometry and one broad bevel as the visible style.
- **Iron/brass/copper:** same graph, ORM.B controls metal response. Use broad rough highlights; no sharp realistic grunge or gleaming polished chrome. Patina stays low contrast.
- **Wet stone:** TX17 is a material candidate with lower roughness, not a new water/physics system. Wetness decals must not change traversability.
- **Palette:** one shared low-cost visual material with face UVs at swatch centers; no claim of measured draw-call performance.
- **Trim:** one surface graph with atlas maps and lane-specific UVs. A separate alpha/emissive slot is the exception, not a new material per bolt.
- **Paint/sign:** use an opaque cloth/stone backing and a thin masked overlay or approved decal path. Do not turn painted seals into interactable widgets.
- **Glass/lantern:** geometry insert separate from frame; emissive contribution and real light are independent. Never encode the lamp pool in the frame albedo.
- **Water:** four-metre periodic normals; RGBA breakup is R slow noise/G second phase/B sparse foam/A white. Two panned samples and existing depth/shore handling are an integration recipe, not a supplied Unreal shader. No world-space flow direction is encoded. The Blender water material is a static look sample.
- **Flame:** a graphic alpha card with a small proposed emissive response; it is not an animated fire simulation. FX_Dust aliases the flour breakup material as a card input; no particle system is created.

## Readability

Keep 70-80percent of a room's visible material area quiet (an art-direction proposal, not a measured current value). Use one dominant neutral, one manufactured accent and one meaningful landmark. Hand controls, keyholes and puzzle discs need clean silhouettes and no distressed symbol ambiguity. Near black is reserved for depth, soot and shadows; the environment does not require bright orange stone to look warm under a lamp.
