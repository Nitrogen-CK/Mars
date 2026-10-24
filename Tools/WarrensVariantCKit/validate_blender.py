"""Audit the freshly reopened Variant C .blend; never generate or save models.

Run Blender with --background <saved .blend> --python-exit-code 1 --python
<this file>. The main library contains 83 new and 113 reused mesh collections.
The JSON report is written on both success and failure.
"""

import hashlib
import json
import math
import sys
import traceback
import uuid
from datetime import datetime, timezone
from pathlib import Path

import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree


HERE = Path(__file__).resolve().parent
OUT = HERE / "Output"
REPORT_PATH = OUT / "Reports/blender_validation.json"
EXPECTED_NEW = 83
EXPECTED_LIBRARY = 196
CM_TOLERANCE = .002
SOCKET_TOLERANCE_M = .00002
CONTACT_TOLERANCE_M = .005


def require(condition, message):
    if not condition:
        raise AssertionError(message)


def finite(values):
    return all(math.isfinite(float(v)) for v in values)


def plain(value):
    if hasattr(value, "to_dict"):
        return {k: plain(v) for k, v in value.to_dict().items()}
    if hasattr(value, "to_list"):
        return [plain(v) for v in value.to_list()]
    if isinstance(value, dict):
        return {k: plain(v) for k, v in value.items()}
    if isinstance(value, (tuple, list)):
        return [plain(v) for v in value]
    return value


def read_json(path):
    return json.loads(path.read_text(encoding="utf-8"))


def close_vector(actual, expected, tolerance, label):
    require(len(actual) == len(expected), label + ": vector dimensions differ")
    require(finite(actual) and finite(expected), label + ": non-finite vector")
    require(all(abs(a - b) <= tolerance for a, b in zip(actual, expected)),
            f"{label}: actual={list(actual)}, expected={list(expected)}")


def catalog_ids():
    result = set()
    for line in (OUT / ".blender_assets.cats.txt").read_text().splitlines():
        if ":" not in line or line.startswith("#"):
            continue
        ident = line.split(":", 1)[0]
        uuid.UUID(ident)
        result.add(ident)
    require(result, "No asset catalog UUIDs")
    return result


def artifact_mesh(row, instance):
    collection = instance.instance_collection
    require(collection is not None, row["id"] + ": missing instance collection")
    objects = [o for o in collection.all_objects if o.type == "MESH"]
    require(len(objects) == 1, row["id"] + ": expected one finished mesh per collection")
    obj = objects[0]
    # Appended collections can acquire suffixes, so identity comes from metadata.
    require(obj.get("catalog_id") == row["id"], row["id"] + ": catalog_id mismatch")
    return obj, collection


def audit_mesh(row, instance, known_catalogs, source_part=None):
    ident = row["id"]
    obj, collection = artifact_mesh(row, instance)
    mesh = obj.data
    require(len(mesh.vertices) >= 3 and mesh.polygons, ident + ": empty mesh")
    require(not obj.modifiers, ident + ": unapplied modifiers in finished mesh")
    require(all(finite(v.co) for v in mesh.vertices), ident + ": non-finite vertex")
    require(all(finite(r) for r in obj.matrix_world), ident + ": non-finite transform")
    for k in range(4):
        close_vector(obj.matrix_world[k], [float(k == j) for j in range(4)], .00001,
                     ident + ": finished object transform")
    for item in (obj, collection):
        require(item.asset_data is not None, ident + ": missing asset marker")
        require(item.asset_data.catalog_id in known_catalogs, ident + ": unknown catalog UUID")
    require(obj.asset_data.catalog_id == collection.asset_data.catalog_id,
            ident + ": object/collection catalog disagreement")

    lo = [min(v.co[k] for v in mesh.vertices) * 100 for k in range(3)]
    hi = [max(v.co[k] for v in mesh.vertices) * 100 for k in range(3)]
    extent = [hi[k] - lo[k] for k in range(3)]
    close_vector(lo, row["bounds_min_cm"], CM_TOLERANCE, ident + ": lower bounds")
    close_vector(hi, row["bounds_max_cm"], CM_TOLERANCE, ident + ": upper bounds")
    close_vector(extent, row["actual_dimensions_cm"], CM_TOLERANCE, ident + ": real dimensions")
    declared = row["dimensions_cm"]
    if source_part is not None:
        expected = [source_part["dimensions_cm"][k] for k in ("width", "depth", "height")]
        close_vector(declared, expected, CM_TOLERANCE, ident + ": production catalog dimensions")
        require(row["source_id"] == source_part["source_id"], ident + ": source ID mismatch")
        require(row["pivot"] == source_part["production_pivot"], ident + ": catalog pivot mismatch")
    for axis in range(3):
        # Flat carriers are documented by their actual geometry, not nominal thickness.
        if extent[axis] < CM_TOLERANCE and row.get("flags", {}).get("card"):
            continue
        require(abs(extent[axis] - declared[axis]) <= CM_TOLERANCE,
                ident + ": catalog envelope differs on axis " + str(axis))
    require(sum(v > CM_TOLERANCE for v in extent) >= 2, ident + ": collapsed geometry")
    close_vector([(lo[k] + hi[k]) / 2 for k in (0, 1)], [0, 0], CM_TOLERANCE,
                 ident + ": XY origin")
    pivot = row["pivot"]
    require(pivot in {"center", "top contact", "bottom center"}, ident + ": unknown pivot")
    if pivot == "center":
        require(abs(lo[2] + hi[2]) <= CM_TOLERANCE, ident + ": center pivot shifted")
    elif pivot == "top contact":
        require(abs(hi[2]) <= CM_TOLERANCE, ident + ": top contact shifted")
    else:
        require(abs(lo[2]) <= CM_TOLERANCE, ident + ": bottom contact shifted")

    require(len(mesh.vertices) == row["vertices"], ident + ": saved vertex count differs")
    mesh.calc_loop_triangles()
    require(len(mesh.loop_triangles) == row["triangles"], ident + ": triangle count differs")
    smallest = math.inf
    for triangle in mesh.loop_triangles:
        require(len(set(triangle.vertices)) == 3, ident + ": repeated triangle index")
        a, b, c = (mesh.vertices[i].co for i in triangle.vertices)
        area = (b - a).cross(c - a).length / 2
        require(math.isfinite(area) and area > 1e-14, ident + ": zero/non-finite triangle area")
        require(finite(triangle.normal), ident + ": non-finite triangle normal")
        smallest = min(smallest, area)
    require(mesh.uv_layers, ident + ": missing UV0")
    for layer in mesh.uv_layers:
        require(len(layer.data) == len(mesh.loops), ident + ": incomplete UV layer")
        require(all(finite(loop.uv) for loop in layer.data), ident + ": non-finite UV")
    require(len(mesh.materials) == len(row["material_keys"]), ident + ": material slot count")
    keys = []
    for material in mesh.materials:
        require(material is not None, ident + ": empty material slot")
        key = material.get("catalog_key")
        require(isinstance(key, str) and key, ident + ": missing material catalog key")
        keys.append(key)
    require(keys == row["material_keys"], ident + ": material key/slot order differs")
    require(all(0 <= poly.material_index < len(keys) for poly in mesh.polygons),
            ident + ": polygon material index out of range")
    flags = row.get("flags", {})
    sockets = flags.get("sockets_m", {})
    if flags.get("source_sockets_m"):
        require(set(sockets) == set(flags["source_sockets_m"]), ident + ": untransformed sockets")
    saved_sockets = plain(obj.get("sockets_m", {}))
    require(set(saved_sockets) == set(sockets), ident + ": saved socket names differ")
    for name, point in sockets.items():
        require(len(point) == 3 and finite(point), ident + ": invalid socket " + name)
        close_vector(saved_sockets[name], point, SOCKET_TOLERANCE_M, ident + ": socket " + name)
    fbx_root = HERE.parent / row["kit"] / "Output" if row.get("kit") else OUT
    fbx = fbx_root / row["fbx"].replace("\\", "/")
    require(fbx.is_file() and fbx.stat().st_size > 0, ident + ": missing/empty FBX")
    return dict(id=ident, status="passed", vertices=len(mesh.vertices), triangles=len(mesh.loop_triangles),
                bounds_cm=extent, pivot=pivot, uv_layers=len(mesh.uv_layers), material_keys=keys,
                socket_count=len(sockets), minimum_triangle_area_m2=smallest)


def bell_opening(row, obj):
    """Probe actual saved triangles: a low cap or missing inner wall must fail."""
    mesh = obj.data
    mesh.calc_loop_triangles()
    bvh = BVHTree.FromPolygons([v.co.copy() for v in mesh.vertices],
                               [tuple(t.vertices) for t in mesh.loop_triangles], all_triangles=True)
    lo = Vector([v / 100 for v in row["bounds_min_cm"]])
    hi = Vector([v / 100 for v in row["bounds_max_cm"]])
    center = (lo + hi) / 2
    radius = min(hi.x - lo.x, hi.y - lo.y) / 2
    height = hi.z - lo.z
    epsilon = max(height * 1e-5, .00001)
    upward = []
    for x in (-.25, 0, .25):
        for y in (-.25, 0, .25):
            origin = Vector((center.x + x * radius, center.y + y * radius, lo.z - height * .02))
            hit, normal, index, distance = bvh.ray_cast(origin, Vector((0, 0, 1)), height * 1.1)
            require(hit is not None, row["id"] + ": mouth ray misses interior crown")
            require(hit.z > lo.z + height * .2, row["id"] + ": low disc blocks bell mouth")
            require(normal.z < -.1, row["id"] + ": mouth ray reached outside instead of inner ceiling")
            upward.append(dict(x=float(origin.x), y=float(origin.y), first_hit_z=float(hit.z)))
    walls = []
    origin = Vector((center.x, center.y, lo.z + height * .3))
    for i in range(8):
        angle = i * math.tau / 8
        direction = Vector((math.cos(angle), math.sin(angle), 0))
        inner, n1, index, distance = bvh.ray_cast(origin, direction, radius * 1.2)
        require(inner is not None and distance > radius * .2, row["id"] + ": cavity missing")
        require(n1.dot(direction) < -.1, row["id"] + ": invalid inner-wall normal")
        outer, n2, index, thickness = bvh.ray_cast(inner + direction * epsilon, direction, radius)
        require(outer is not None and epsilon < thickness < radius * .3,
                row["id"] + ": missing or implausible outer wall")
        require(n2.dot(direction) > .1, row["id"] + ": invalid outer-wall normal")
        walls.append(dict(direction=list(direction), inner_distance_m=float(distance),
                          wall_thickness_m=float(thickness + epsilon)))
    return dict(id=row["id"], status="passed", open_mouth_rays=upward, cavity_wall_rays=walls)


def audit_contacts(manifest, by_id):
    scene = bpy.data.scenes.get("02_VariantC_Cutaway")
    if manifest.get("stage") != "assembled":
        return dict(status="not_exercised", reason="models_only artifact has no saved assembly")
    require(scene is not None, "Assembled manifest has no saved cutaway scene")
    # Freshly reopened inactive scenes can retain identity matrix_world caches
    # despite correct stored location/rotation/scale. Evaluate this scene before
    # measuring saved instance contacts; this changes no saved artifact data.
    require(bpy.context.window is not None, "Scene evaluation requires the background window context")
    bpy.context.window.scene = scene
    bpy.context.view_layer.update()
    data = read_json(OUT / "fitted_instances.json")
    placed = []
    for index, row in enumerate(data["placements"]):
        ident = row.get("mesh_id", row["id"])
        if ident not in by_id:
            continue
        obj = scene.objects.get(row["id"] + "_Assembly_" + str(index))
        if obj is not None:
            placed.append((row, obj, by_id[ident]))

    def socket_world(entry, name):
        row, instance, mesh_row = entry
        point = mesh_row.get("flags", {}).get("sockets_m", {}).get(name)
        require(point is not None, mesh_row["id"] + ": missing contact socket " + name)
        mesh, collection = artifact_mesh(mesh_row, instance)
        return instance.matrix_world @ (mesh.matrix_world @ Vector(point) - collection.instance_offset)

    contracts = [("WVC013", "pulley_axle", "WVC014", "axle_center"),
                 ("WVC013", "drum_axle", "WVC015", "axle_center"),
                 ("WVC020", "bell_attachment", "WVC019", "crown_attachment"),
                 ("WVC019", "clapper_hinge", "WVC021", "hinge_center"),
                 ("WVC026", "lid_seat", "WVC081", "underside_center")]
    checked = []
    for left, left_socket, right, right_socket in contracts:
        lefts = [e for e in placed if e[2]["id"] == left]
        rights = [e for e in placed if e[2]["id"] == right]
        if left == "WVC026":
            lefts = [e for e in lefts if "closed" in e[0].get("role", "")]
            rights = [e for e in rights if "closed" in e[0].get("role", "")]
        for a in lefts:
            candidates = [e for e in rights if e[0]["tile"] == a[0]["tile"]]
            if len(candidates) > 1 and "source_prop_index" in a[0]:
                candidates = [e for e in candidates if e[0].get("source_prop_index") == a[0]["source_prop_index"]]
            require(len(candidates) == 1, f"Contact {left}/{right}: missing or ambiguous paired instance")
            b = candidates[0]
            delta = (socket_world(a, left_socket) - socket_world(b, right_socket)).length
            require(delta <= CONTACT_TOLERANCE_M, f"Contact {left}/{right}: socket gap {delta}m")
            checked.append(dict(tile=a[0]["tile"], left=left, right=right,
                                sockets=[left_socket, right_socket], gap_m=delta))
        require(lefts or not rights, f"Contact {left}/{right}: target exists without source")
    require(checked, "Assembled artifact exercised no separate-part socket contacts")
    return dict(status="passed", tolerance_m=CONTACT_TOLERANCE_M, contacts=checked,
                scope="Saved assembly socket coincidence; does not prove complete collision-free fit")


def main():
    report = dict(status="failed", generated_utc=datetime.now(timezone.utc).isoformat(),
                  blend_file=bpy.data.filepath, assets=[], errors=[], scope="Fresh saved Blender artifact only")

    def check(name, function):
        try:
            return function()
        except Exception as error:
            report["errors"].append(dict(check=name, error=str(error), traceback=traceback.format_exc(limit=4)))
            return None

    try:
        require(bpy.data.filepath and Path(bpy.data.filepath).is_file(), "Open a saved .blend before auditing")
        require(Path(bpy.data.filepath).resolve() in {(OUT / "WarrensVariantC_KitLibrary.blend").resolve(),
                                                    (OUT / "WarrensVariantC_Diorama.blend").resolve()},
                "Wrong saved Blender artifact")
        manifest = read_json(OUT / "asset_manifest.json")
        catalog = read_json(HERE / "model_catalog.json")
        inputs = [HERE / "build_kit.py", HERE / "model_catalog.json",
                  HERE.parent / "ChainCrossingKit/build_kit.py"]
        inputs += sorted((HERE / "generators").glob("*.py"))
        if manifest.get("stage") == "assembled":
            inputs.append(OUT / "fitted_instances.json")
        saved_time = Path(bpy.data.filepath).stat().st_mtime
        newer = [str(p) for p in inputs if p.is_file() and p.stat().st_mtime > saved_time + .001]
        require(not newer, "Saved artifact predates production inputs: " + str(newer))
        report["production_input_sha256"] = {str(p.relative_to(HERE.parent)): hashlib.sha256(p.read_bytes()).hexdigest()
                                               for p in inputs if p.is_file()}
        require(manifest["source_catalog_sha256"] == hashlib.sha256((HERE / "model_catalog.json").read_bytes()).hexdigest(),
                "Manifest was produced from a different model catalog")
        new_rows, shared = manifest["assets"], manifest["shared_assets"]
        require(len(new_rows) == manifest["count"] == EXPECTED_NEW, "Expected 83 new meshes")
        rows = new_rows + shared
        require(len(rows) == manifest["library_entries"] == EXPECTED_LIBRARY, "Expected 196 library entries")
        require(len({r["id"] for r in rows}) == EXPECTED_LIBRARY, "Duplicate library ID")
        catalog_parts = {r["id"]: r for r in catalog["models"]}
        require(set(catalog_parts) == {r["id"] for r in new_rows}, "New model catalog coverage differs")
        require({r["id"] for r in catalog["existing_assets"]} == {r["id"] for r in shared}, "Shared catalog coverage differs")
        scene = bpy.data.scenes.get("01_VariantCLibrary")
        require(scene is not None, "Missing library scene")
        instances = [o for o in scene.objects if o.instance_type == "COLLECTION"]
        require(len(instances) == EXPECTED_LIBRARY, "Library instance count differs")
        require(not any(o.type == "MESH" for o in scene.objects), "Library contains raw production mesh proxies")
        instance_map = {o.name.split("_", 1)[0]: o for o in instances}
        require(set(instance_map) == {r["id"] for r in rows}, "Library instance IDs differ")
        require(len({o.instance_collection for o in instances}) == EXPECTED_LIBRARY, "Duplicate collection references")
        known_catalogs = catalog_ids()
        for row in rows:
            result = check(row["id"], lambda r=row: audit_mesh(r, instance_map[r["id"]], known_catalogs,
                                                             catalog_parts.get(r["id"])))
            report["assets"].append(result or dict(id=row["id"], status="failed"))
        by_id = {r["id"]: r for r in rows}
        bell = by_id["WVC019"]
        report["bell_opening"] = check("bell_opening", lambda: bell_opening(bell, artifact_mesh(bell, instance_map[bell["id"]])[0]))
        report["separate_part_contacts"] = check("separate_part_contacts", lambda: audit_contacts(manifest, by_id))
        images = [i for i in bpy.data.images if i.source == "FILE"]
        unpacked = [i.name for i in images if not i.packed_file and not len(i.packed_files)]
        require(images and not unpacked, "Unpacked file textures: " + str(unpacked))
        report.update(new_models=len(new_rows), reused_models=len(shared), library_entries=len(instances),
                      packed_file_images=len(images), triangles=sum(r.get("triangles", 0) for r in report["assets"]),
                      stage=manifest["stage"], asset_manifest_sha256=hashlib.sha256((OUT / "asset_manifest.json").read_bytes()).hexdigest())
    except Exception as error:
        report["errors"].append(dict(check="artifact", error=str(error), traceback=traceback.format_exc(limit=4)))
    report["status"] = "failed" if report["errors"] else "passed"
    REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
    REPORT_PATH.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print("VARIANT_C_FRESH_BLENDER_AUDIT", report["status"], "errors", len(report["errors"]), flush=True)
    if report["errors"]:
        raise SystemExit(1)
    return report


if __name__ == "__main__":
    main()
