"""Finish ONLY the two new Steward WBPs; execute through Monolith editor Python.

Requires parchment_specs.json assets already created. No topology changes, no
shared style writes, no map access. Run again safely to reapply the same values.
The report describes authored template values, not populated runtime behavior.
"""
import json
from pathlib import Path
import unreal

HERE = Path(__file__).resolve().parent
MANIFEST = json.loads((HERE / "parchment_specs.json").read_text(encoding="utf-8"))
ALLOWED = {
    "/Game/Mars/UI/Widgets/Steward/ServiceParchmentRow_Mars_WBP",
    "/Game/Mars/UI/Widgets/Steward/ServiceParchment_Mars_WBP",
}
assert {a["asset_path"] for a in MANIFEST["assets"]} == ALLOWED


def widget(path, name):
    result = unreal.find_object(None, path + "." + path.rsplit("/", 1)[-1] + ":WidgetTree." + name)
    assert result, (path, name)
    return result


def node_names(node):
    return [node["id"]] + [name for child in node.get("children", []) for name in node_names(child)]


def node_list(node):
    return [node] + [item for child in node.get("children", []) for item in node_list(child)]


def patch_layout(path, node):
    control = widget(path, node["id"])
    control.modify()
    if node["type"] == "SizeBox":
        control.set_width_override(node["style"]["width"])
        control.set_height_override(node["style"]["height"])
    slot = node.get("slot", {})
    if "position" in slot and "size" in slot:
        control.slot.set_position(unreal.Vector2D(**slot["position"]))
        control.slot.set_size(unreal.Vector2D(**slot["size"]))
    for child in node.get("children", []):
        patch_layout(path, child)


def cdo_value(cdo, name):
    value = cdo.get_editor_property(name)
    return value.get_path_name() if name in ("RowClass", "Style") else value


report = {"scope": sorted(ALLOWED), "assets": [], "runtimePopulated": False,
          "evidenceBoundary": "Authored widget templates only; main requires SetCatalog on a live instance."}
for entry in MANIFEST["assets"]:
    path = entry["asset_path"]
    blueprint = unreal.load_asset(path)
    assert blueprint, path
    blueprint.modify()
    patch_layout(path, entry["spec"]["rootWidget"])
    for name, class_path in entry["styles"].items():
        control = widget(path, name)
        control.modify()
        style = unreal.load_class(None, class_path)
        assert style, class_path
        control.set_style(style)
    for name, size in entry["postBuild"]["fontSizes"].items():
        control = widget(path, name)
        control.modify()
        font = control.get_editor_property("font")
        font.set_editor_property("size", size)
        control.set_font(font)
        control.set_auto_wrap_text(True)
    labels = {}
    for name, label in entry.get("labels", {}).items():
        control = widget(path, name)
        control.modify()
        control.set_editor_property("ButtonText", unreal.Text(label))
        # The inherited AS PreConstruct/Construct refreshes the label at runtime.
        # Set the nested design-time label too; never save its shared source WBP.
        if hasattr(control, "refresh_label"):
            control.refresh_label()
        labels[name] = str(control.get_editor_property("ButtonText"))
    generated = unreal.EditorAssetLibrary.load_blueprint_class(path)
    assert generated, path
    cdo = unreal.get_default_object(generated)
    cdo.modify()
    for name, value in entry["postBuild"]["cdo"].items():
        if name in ("RowClass", "Style"):
            value = unreal.load_class(None, value)
            assert value, "Row class did not load"
        cdo.set_editor_property(name, value)
    for name in entry["postBuild"].get("collapsed", []):
        control = widget(path, name)
        control.modify()
        control.set_visibility(unreal.SlateVisibility.COLLAPSED)
    if "paperBrushTint" in entry["postBuild"]:
        control = widget(path, "Paper")
        control.modify()
        control.set_brush_color(unreal.LinearColor(*entry["postBuild"]["paperBrushTint"]))
    if path.endswith("/ServiceParchment_Mars_WBP"):
        scroll = widget(path, "ServicesScroll")
        scroll.modify()
        scroll.set_orientation(unreal.Orientation.ORIENT_VERTICAL)
        scroll.set_scroll_bar_visibility(unreal.SlateVisibility.VISIBLE)
        scroll.set_allow_overscroll(False)
        scroll.set_navigation_destination(unreal.DescendantScrollDestination.INTO_VIEW)
    assert unreal.EditorAssetLibrary.save_loaded_asset(blueprint, only_if_is_dirty=False), path
    root = widget(path, "DesignSize")
    bindings = {name: widget(path, name).get_class().get_path_name() for name in entry["requiredBindings"]}
    readback = {
        "asset": path, "bindings": bindings,
        "rootWidthOverride": root.get_editor_property("width_override"),
        "rootHeightOverride": root.get_editor_property("height_override"),
        "styles": {name: widget(path, name).get_editor_property("style").get_path_name()
                   for name in entry["styles"]},
        "fontSizes": {name: widget(path, name).get_editor_property("font").get_editor_property("size")
                      for name in entry["postBuild"]["fontSizes"]},
        "labels": labels,
        "cdo": {name: cdo_value(cdo, name) for name in entry["postBuild"]["cdo"]},
        "collapsed": {name: str(widget(path, name).get_visibility())
                      for name in entry["postBuild"].get("collapsed", [])},
        "widgetNames": node_names(entry["spec"]["rootWidget"]),
        "canvasSlots": {node["id"]: {
            "position": [widget(path, node["id"]).slot.get_position().x,
                         widget(path, node["id"]).slot.get_position().y],
            "size": [widget(path, node["id"]).slot.get_size().x,
                     widget(path, node["id"]).slot.get_size().y]}
            for node in node_list(entry["spec"]["rootWidget"]) if "position" in node.get("slot", {})},
    }
    if path.endswith("/ServiceParchment_Mars_WBP"):
        readback["scroll"] = {"orientation": str(scroll.get_editor_property("orientation")),
                              "scrollBarVisibility": str(scroll.get_editor_property("scroll_bar_visibility")),
                              "allowOverscroll": scroll.get_editor_property("allow_overscroll"),
                              "navigationDestination": str(scroll.get_editor_property("navigation_destination")),
                              "contentClass": widget(path, "ServiceRows").get_class().get_path_name(),
                              "contentParent": widget(path, "ServiceRows").get_parent().get_name()}
    report["assets"].append(readback)

output = HERE / "setup_report.json"
output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
print(json.dumps(report, indent=2))
