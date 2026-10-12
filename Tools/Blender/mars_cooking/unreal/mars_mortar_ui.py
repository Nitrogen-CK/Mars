"""The mortar station's meter (UMars_MortarMeter_Widget, Script/UI/Mortar): builds MortarMeter_Mars_WBP and gives the
gameplay HUD its MortarMeter child. Host-side, against a running editor's Monolith (like mars_food_niagara.py), because a
widget tree can only be authored through Monolith's ui actions:

    python Tools\\Blender\\mars_cooking\\unreal\\mars_mortar_ui.py --port 9316

Run it against the editor that has the project open (a second editor cannot save an asset the first has loaded), not in
PIE. Re-runnable: the meter's tree (everything under its root) is rebuilt each run, the HUD child is added once.

    MortarMeter_Mars_WBP  SizeBox (560 wide)
                            Body      VerticalBox      everything drawn; the widget collapses it while no mortar is worked
                              Prompt    TextBlock      what the phase asks for
                              ProgressSize SizeBox (18 high)
                                Progress  ProgressBar  the batch's progress
                              BarFrame  Border         the timing bar's dark frame
                                BarSize   SizeBox (46 high)
                                  Bar       CanvasPanel
                                    Window    Image    green; the widget places it by its anchors (bar lengths)
                                    Marker    Image    white; where a strike is judged

Colours and the size boxes' overrides are set by editor Python on the widget templates, not through Monolith's
set_widget_property: it takes a colour string it cannot parse without an error and stores transparent black, and the
override flags are off its allowlist. finish() reads every one of them back and fails if any did not take.
    Gameplay_HUD_Mars_WBP  + MortarMeter (MortarMeter_Mars_WBP) top centre, under the screen's top edge
"""
import argparse
import json
import sys
import urllib.request

METER = "/Game/Mars/UI/Widgets/Mortar/MortarMeter_Mars_WBP"
HUD = "/Game/Mars/UI/Widgets/Gameplay_HUD_Mars_WBP"
HUD_CHILD = "MortarMeter"
# (widget class, name, parent), in build order
TREE = (("VerticalBox", "Body", "SizeBox"), ("TextBlock", "Prompt", "Body"), ("SizeBox", "ProgressSize", "Body"),
        ("ProgressBar", "Progress", "ProgressSize"), ("Border", "BarFrame", "Body"), ("SizeBox", "BarSize", "BarFrame"),
        ("CanvasPanel", "Bar", "BarSize"), ("Image", "Window", "Bar"), ("Image", "Marker", "Bar"))


class Monolith:
    def __init__(self, port):
        self.url = "http://localhost:%d/mcp" % port
        self.sid, self.rpc = None, 0
        self._post({"jsonrpc": "2.0", "id": self._id(), "method": "initialize", "params": {
            "protocolVersion": "2025-03-26", "capabilities": {}, "clientInfo": {"name": "mars_mortar_ui", "version": "1"}}})
        try:
            self._post({"jsonrpc": "2.0", "method": "notifications/initialized"})
        except Exception:
            pass

    def _id(self):
        self.rpc += 1
        return self.rpc

    def _post(self, payload, timeout=600):
        req = urllib.request.Request(self.url, data=json.dumps(payload).encode(), method="POST", headers={
            "Content-Type": "application/json", "Accept": "application/json, text/event-stream"})
        if self.sid:
            req.add_header("Mcp-Session-Id", self.sid)
        with urllib.request.urlopen(req, timeout=timeout) as r:
            self.sid = r.headers.get("Mcp-Session-Id") or self.sid
            body = r.read().decode("utf-8", "replace")
        if body.startswith("event:") or "\ndata:" in body or body.startswith("data:"):
            chunks = [line[5:].strip() for line in body.splitlines() if line.startswith("data:")]
            body = chunks[-1] if chunks else "{}"
        return json.loads(body) if body.strip() else {}

    def call(self, tool, action, params, check=True):
        rep = self._post({"jsonrpc": "2.0", "id": self._id(), "method": "tools/call", "params": {
            "name": tool, "arguments": {"action": action, "params": params}}})
        res = rep.get("result", {})
        text = "\n".join(c.get("text", "") for c in res.get("content", []) if c.get("type") == "text")
        failed = bool(rep.get("error") or res.get("isError")) or "severity: error" in text
        if check and failed:
            raise RuntimeError("%s %s %s failed: %s" % (tool, action, json.dumps(params), rep.get("error") or text))
        try:
            return json.loads(text)
        except ValueError:
            return {"_text": text, "_failed": failed}

    def ui(self, action, check=True, **params):
        return self.call("ui_query", action, params, check)

    def python(self, code):
        out = self.call("editor_query", "run_python", {"command": code, "unattended": True})
        lines = [o.get("output", "") for o in out.get("output", [])]
        if not out.get("success", True):
            raise RuntimeError("run_python failed: %s" % out)
        return "".join(lines)


def _names(node, out=None):
    out = {} if out is None else out
    out[node["name"]] = node
    for child in node.get("children", []):
        _names(child, out)
    return out


def build_meter(m):
    tree = m.ui("get_widget_tree", check=False, asset_path=METER)
    if "root" not in tree:
        m.ui("create_widget_blueprint", save_path=METER, parent_class="Mars_MortarMeter_Widget", root_widget="SizeBox")
        tree = m.ui("get_widget_tree", asset_path=METER)
    have = _names(tree["root"])
    if "SizeBox" not in have:
        raise RuntimeError("%s has no root SizeBox (root is %s): delete the asset and rerun" % (METER, tree["root"]["name"]))
    if "Body" in have:
        m.ui("remove_widget", asset_path=METER, widget_name="Body")
    for cls, name, parent in TREE:
        m.ui("add_widget", asset_path=METER, widget_class=cls, widget_name=name, parent_name=parent)

    m.ui("set_widget_property", asset_path=METER, widget_name="BarFrame", property_name="Padding", value=[5, 5, 5, 5])
    zero = {"left": 0, "top": 0, "right": 0, "bottom": 0}
    m.ui("set_slot_property", asset_path=METER, widget_name="Window",
         anchors={"min_x": 0.3, "min_y": 0.0, "max_x": 0.48, "max_y": 1.0}, offsets=zero)
    m.ui("set_slot_property", asset_path=METER, widget_name="Marker",
         anchors={"min_x": 0.696, "min_y": 0.0, "max_x": 0.704, "max_y": 1.0}, offsets=zero, z_order=1)
    m.ui("set_text", asset_path=METER, widget_name="Prompt", text="Crush: click on the green", font_size=20,
         justification="center", text_color={"r": 1.0, "g": 0.94, "b": 0.8, "a": 1.0})
    for name in ("Prompt", "ProgressSize"):
        m.ui("set_slot_property", asset_path=METER, widget_name=name, padding={"left": 0, "top": 0, "right": 0, "bottom": 6})
    print(m.python(_FINISH_METER % {"wbp": METER, "name": METER.rsplit("/", 1)[1]}).strip())


def add_to_hud(m):
    tree = m.ui("get_widget_tree", asset_path=HUD)
    have = _names(tree["root"])
    if HUD_CHILD not in have:
        m.ui("add_widget", asset_path=HUD, widget_class=METER + "." + METER.rsplit("/", 1)[1] + "_C", widget_name=HUD_CHILD,
             parent_name=tree["root"]["name"])
    m.ui("set_slot_property", asset_path=HUD, widget_name=HUD_CHILD,
         anchors={"min_x": 0.5, "min_y": 0.0, "max_x": 0.5, "max_y": 0.0}, alignment={"x": 0.5, "y": 0.0},
         position={"x": 0, "y": 70}, auto_size=True, z_order=5)
    print(m.python(_FINISH_HUD % {"wbp": HUD, "name": HUD.rsplit("/", 1)[1]}).strip())


# Editor Python on the meter's widget templates: colours and size overrides, read back, then compile and save.
_FINISH_METER = """
import unreal
path, name = "%(wbp)s", "%(name)s"
wbp = unreal.load_asset(path)
def template(widget):
    return unreal.find_object(None, "%%s.%%s:WidgetTree.%%s" %% (path, name, widget))
green = unreal.LinearColor(0.08, 0.85, 0.12, 1.0)
template("SizeBox").set_width_override(560.0)
template("ProgressSize").set_height_override(18.0)
template("BarSize").set_height_override(46.0)
template("Window").set_color_and_opacity(green)
template("Marker").set_color_and_opacity(unreal.LinearColor(1.0, 1.0, 1.0, 1.0))
template("BarFrame").set_brush_color(unreal.LinearColor(0.03, 0.025, 0.02, 0.92))
template("Progress").set_fill_color_and_opacity(green)
template("Progress").set_percent(0.0)
took = {
    "Window": template("Window").get_editor_property("color_and_opacity").a,
    "Marker": template("Marker").get_editor_property("color_and_opacity").a,
    "BarFrame": template("BarFrame").get_editor_property("brush_color").a,
    "Progress": template("Progress").get_editor_property("fill_color_and_opacity").a,
    "BarSize": template("BarSize").get_editor_property("height_override"),
    "ProgressSize": template("ProgressSize").get_editor_property("height_override"),
}
bad = [k for k, v in took.items() if v <= 0.0]
if bad:
    raise RuntimeError("did not take: %%s" %% bad)
unreal.BlueprintEditorLibrary.compile_blueprint(wbp)
print(name, "styled", took, "saved", unreal.EditorAssetLibrary.save_loaded_asset(wbp, False))
"""

_FINISH_HUD = """
import unreal
wbp = unreal.load_asset("%(wbp)s")
unreal.BlueprintEditorLibrary.compile_blueprint(wbp)
print("%(name)s", "saved", unreal.EditorAssetLibrary.save_loaded_asset(wbp, False))
"""


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--port", type=int, default=9316)
    args = ap.parse_args()
    m = Monolith(args.port)
    state = m.python("import unreal\nprint(unreal.get_editor_subsystem(unreal.LevelEditorSubsystem).is_in_play_in_editor())")
    if "True" in state:
        sys.exit("the editor is in PIE: stop it and rerun")
    build_meter(m)
    add_to_hud(m)
    print("MORTAR_UI_OK")


if __name__ == "__main__":
    main()
