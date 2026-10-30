# Feature showcase: the pan — storyboard (APPROVED 2026-10-25)

**Decisions (Stephen):** approved without the fryer beat (6 is cut; ~42 s). Shoot as **A. kernel replay** on the devlog
stage's cooking bay once its stills pass. Pieces: lookdev cube for beats 1-2, cut slab pieces for beats 4-7 (proposal
not objected to). Captions as listed, none added.

Not a breakdown: a showcase of what the searing station does today, shot on the devlog stage (cooking bay, warm
preset), few captions, about 50 s. Nothing is shot or rendered until you OK this. Mark rows keep / cut / reword.

## What exists now (so the beats only promise real behaviour)
- Pan holds **up to six pieces** (`MaxPieces = 6`); each piece sears **six faces, 3 s per face**, and is **Ready** after the
  sixth. The face on the pan is whichever local axis points down: a flip is a new face resting on the pan.
- Each piece on the pan gets its **own oil pool and a trail that lags behind it**; a lifted piece leaves a puddle that
  closes. Simmer beads cover every piece; the sizzle ramp follows the kernel (full while cooking, a hiss over seared
  faces); **fond** builds on the pan over time; sear past 1.25 **chars**.
- Meat reaches the pan as **slab pieces cut on the bench** (runtime mesh, each cap inherits its cook state), or as whole
  joints. The old lookdev cube is still a valid pan piece for lookdev.
- Sibling stations: **batter** (hold to dip) then **fryer** (iron vat, basket; fry 0 raw, 1 golden, 2 burnt) for the whole
  foods: drumstick, tentacle, puffer, spiked berry, mushroom. Oil bubbles exist as a Niagara system; a flame system sits
  under the pan.

## Beats (16:9, 1080p, 30 fps; big captions only, one per beat, 2.5 s each)

| # | out s | shot (stage cooking bay) | caption |
|---|---|---|---|
| T | 2 | title over a blurred oil macro | Mise en Monstre · The pan |
| 1 | 5 | oil macro: the film shimmers, one cube lands, pool forms, beads start | none (let it land) |
| 2 | 8 | top-down 60°: underside sears over 3 s, the piece flips, the seared face comes up, the pool re-forms around the new footprint | "Six faces. Three seconds each." |
| 3 | 4 | cutting bench insert: the slab cut into four pieces (2 cuts) | "Cut first, then cook" |
| 4 | 10 | three-quarter 30°: five pieces in the pan, each with its own pool, a toss sends two sliding and their trails lag; sizzle on the oil | "Every piece keeps its own pool" |
| 5 | 6 | top-down: one piece left too long goes dark, the fond builds around it | "Leave it, and it chars" |
| 6 | 7 | fryer insert (optional): a battered drumstick and tentacle lowered into the vat, bubbles, lifted golden into the basket | "The fryer takes the battered ones" |
| 7 | 5 | three-quarter: the Ready pieces side by side, raw to charred, slow push | none |
| E | 2 | end card | Mise en Monstre · devlog 02 |

Total ≈ 49 s with beat 6, ≈ 42 s without.

## How it would be shot (pick one; both are honest if captioned as such)
- **A. Kernel replay (recommended):** the stage script drives the pieces' Custom Primitive Data and the pan's parameters
  from the kernel's own numbers (3 s per face, penetration, pool/trail geometry, sizzle ramp rates, fond rate) with the
  material time frozen per frame. Deterministic 30 fps, perfect lighting, re-shootable. The toss in beat 4 would be a
  scripted motion, not physics.
- **B. Real PIE recording:** the hidden editor runs the StationGym, the capture rides the station camera while a scripted
  operator feeds and tosses pieces. Real physics and real kernel, but frame timing is whatever the editor manages,
  the gym lighting is what you did not like, and the hands/HUD are in frame.
- **A + B:** A for beats 1, 2, 4, 5, 7; B only for the bench cut (beat 3) and the toss, cut short.

## Open questions
1. Beat 6 (fryer): in, out, or its own later video?
2. Pieces: the lookdev cube (reads like the old minigame) or cut slab pieces (what the game ships now)? Proposal: cube
   for beats 1-2, slab pieces for 4-7.
3. Length: ~45 s fine, or do you want it under 30 s like the breakdowns?
