# Warrens 3D mockup viewer

A browser mockup of an anchored expedition map, built from the same `data/<map>.json` the greybox builder reads, so a
layout can be walked at chef scale before anything is built in Unreal.

```
python viewer/make_layouts.py            # bundle data/warrens*.json into viewer/layouts.js (--fresh re-runs design_warrens_v*.py first)
python -m http.server 8765 --directory viewer   # or open viewer/index.html straight from disk
```

Open `http://localhost:8765/?layout=v4` (also `?layout=warrens.json` for the live v3). three.js comes from cdnjs, so the
page needs the network once.

- **Orbit / Plan / Walk.** Walk is first person at the chef's numbers (walk 4.2 m/s, sprint 7, crouch 2.2, eye 1.1 m,
  step 0.6 m): WASD, Shift, C to crouch (a 1.3 m crawl needs it), Esc. The floor is the rasterized data, so walls block
  and a drop takes you to the level below; there is no climbing a ladder, use the node drop-down to teleport.
- **Work light / Expedition light.** Expedition is the game's darkness: the placed lights, plus the 7 m held-lantern pool
  on the walker (and its ring on the floor). "lantern + hearth only" is the worst case: nothing placed but the hearth.
- **Metrics** are computed from the plan graph and the data (corridor share, runs over 12 m, closure sets, dead ends,
  pockets per family, floor heights) with the same rules as the offline checker.
- **URL state** makes a view reproducible: `?layout=v4&view=fp&light=exp&pos=72,51,0&yaw=-90&pitch=-10&panel=0`,
  `?view=plan&r=70`, `?view=orbit&target=17,38&r=45&phi=40&theta=-20&labels=0`. Headless Chrome renders these:
  `chrome --headless=new --use-angle=swiftshader --enable-unsafe-swiftshader --window-size=1400,880 --virtual-time-budget=15000 --screenshot=out.png "<url>"`.
  Keep the scene under about 16 point lights or the software renderer drops some.

The viewer rasterizes at 0.5 m like `build_warrens.py` (rooms, foyer pads and links walkable, the rest solid; ramps,
crawl lintels, low tunnels, cracks, grates, Rafters platforms and rails, ladders). Every cell carries a floor height, so
the viewer also accepts what the builder does not know yet (listed at the top of `viewer.js`): polygon rooms, rooms at
any height, `extraRamps`, `niches` (pockets), `water`, `props`, and holes on any level. Those are the proposals the
builder needs to learn before a layout that uses them can be built.
