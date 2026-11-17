# Pale Crawler R01 - assembly manifest and sidecar schema (contract between builder, validator and Unreal wrapper)

All numbers are Unreal centimetres in the Unreal frame: +X forward, +Y right, +Z up. Rotations are three column
vectors `[[xx,xy,xz],[yx,yy,yz],[zx,zy,zz]]` = the piece's local X, Y, Z axes expressed in the parent frame (right-handed,
orthonormal, det +1; NEVER a negative scale). World space in a pose: ground is z = 0, the spider faces +X.

Files (all in `docs/art/pale-crawler-model-r01/production/export/`):

- `PaleCrawler_R01_Assembly.json` - the manifest below.
- `<Mesh>.fbx` + `<Mesh>.json` - one FBX per render assembly and its sidecar.
- Mesh names: `PaleCrawler_R01_Body_Mars_SM`, `PaleCrawler_R01_LegUpper<Pair>_Mars_SM`, `PaleCrawler_R01_LegLower<Pair>_Mars_SM`
  for Pair in Front, MidFront, MidBack, Back, `PaleCrawler_R01_Foot_Mars_SM`, `PaleCrawler_R01_Chelicera_Mars_SM` (11 meshes).

## Sidecar `<Mesh>.json`

```json
{"name": "PaleCrawler_R01_LegUpperFront_Mars_SM",
 "role": "body|upper|lower|foot|chelicera", "pair": "Front|MidFront|MidBack|Back|null",
 "fbx": "PaleCrawler_R01_LegUpperFront_Mars_SM.fbx",
 "slots": ["Ivory", "Joint"],                  // material slot names in slot order, exactly as exported
 "tris": 212, "render_vertices": 636,          // triangles; unique (position, normal) corners after flat split
 "bounds_min": [x,y,z], "bounds_max": [x,y,z], // local frame, cm
 "local_frame": "pivot at the hip-knee midpoint; +X hip->knee; +Y toward the pole",
 "joints_local": {"proximal": [x,y,z], "distal": [x,y,z]},   // segments: the two joints in the piece's local frame
                                               // chelicera: {"root":[0,0,0], "tip":[x,y,z]}; body/foot: {}
 "forms": ["coxa", "femur", "knee_knuckle"],   // anatomical forms combined into this render assembly
 "forms_tris": {"coxa": 60, "femur": 120, "knee_knuckle": 32},
 "triangles": [[[x,y,z],[x,y,z],[x,y,z]], ...] // OPTIONAL (validator may read a separate <Mesh>.tris.json instead)
}
```

Authored triangle data for the validator lives in `<Mesh>.tris.json`: `{"triangles": [[[x,y,z]*3], ...], "normals": [[nx,ny,nz], ...],
"slot_index": [i, ...]}` in the piece's local frame (cm), same order as the FBX export order.

## Manifest `PaleCrawler_R01_Assembly.json`

```json
{"version": 1, "units": "cm", "frame": "Unreal +X forward, +Y right, +Z up; body origin = Body bounds centre; pose ground z = 0",
 "builder": "Tools/Blender/mars_monsters/pale_crawler_r01/build_pale_crawler.py", "blend": "<abs path>",
 "parameters": {"BODY_LENGTH_CM": 50.0, "STANCE_WIDTH_CM": 180.0, "KNEE_HEIGHT_CM": 60.0, "CHEF_HEIGHT_CM": 140.0, ...},
 "measurements": {"body_length": 50.0, "stance_width": 180.0, "highest_knee": 60.0, "head_top": 33.1,
                  "body_centre_height": 24.0, "body_bounds_min": [..], "body_bounds_max": [..], ...},
 "materials": {"slots": ["Ivory", "Underside", "Joint", "Eye"],
               "srgb": {"Ivory": [r,g,b], "Underside": [..], "Joint": [..], "Eye": [..]},
               "roughness": {"Ivory": 0.75, ...}},
 "meshes": {"<Mesh>": <the sidecar without triangles>, ...},
 "totals": {"unique_tris": n, "assembled_tris": n, "assembled_instances": 27},
 "chef_marker": {"height": 140.0, "location": [x,y,0]},
 "poses": {
   "neutral": {
     "body_centre_height": 24.0,
     "instances": [ {"mesh": "PaleCrawler_R01_Body_Mars_SM", "id": "Body", "location": [x,y,z], "rotation_cols": [[..],[..],[..]]},
                    {"mesh": "PaleCrawler_R01_LegUpperFront_Mars_SM", "id": "R1.Upper", ...}, ... ],
     "legs": [ {"id": "R1", "side": "R", "pair": "Front", "hip": [..], "knee": [..], "ankle": [..], "foot": [..],
                "pole": [..], "upper_length": 52.3, "lower_length": 73.8,
                "hip_body": [..], "knee_body": [..], "foot_body": [..], "pole_body": [..]}, ... 8 legs, R1..R4 then L1..L4 ],
     "chelicerae": [ {"id": "R", "root": [..], "tip": [..]}, {"id": "L", ...} ] },
   "crouch": { same shape }
 }
}
```

`instances` is the complete list a consumer needs to assemble the spider: body (1) + 8 x (Upper, Lower, Foot) + 2 chelicerae
= 27 instances. A left leg wears the right pair's meshes under a proper rotation (its local +Y points to its own pole);
no instance has a negative scale. `*_body` are the same joints in the body's frame (body origin, body axes).
