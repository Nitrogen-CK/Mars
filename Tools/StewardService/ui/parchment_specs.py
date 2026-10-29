"""Emit new-only Steward parchment UISpecs; never imports unreal or mutates assets.

Run: python Tools/StewardService/ui/parchment_specs.py --write
Build each assets[i].spec using its buildParams, then apply its style/label maps
and postBuild values, compile and read back. Do not feed the manifest itself to
build_ui_from_spec. Existing ChalkParchment assets are read-only dependencies.
"""

import argparse
import json
from pathlib import Path


DEST = "/Game/Mars/UI/Widgets/Steward/"
SKINS = "/Game/Mars/UI/Widgets/ChalkParchment/"
STYLES = "/Game/Mars/UI/Styles/ChalkParchment/"
TEXTURES = "/Game/Mars/UI/Textures/ChalkParchment/"
INK = "#241F1B"


def rect(x, y, width, height):
    return {"position": {"x": x, "y": y}, "size": {"x": width, "y": height}}


def text(name, value, x, y, width, height, size):
    return {"type": "CommonTextBlock", "customClassPath": "/Script/CommonUI.CommonTextBlock",
            "id": name, "slot": rect(x, y, width, height),
            "style": {"visibility": "HitTestInvisible"},
            "content": {"text": value, "fontSize": size, "fontColor": INK, "wrapMode": "Wrap"}}


def image(name, texture, x, y, width, height, visibility="HitTestInvisible"):
    return {"type": "Image", "id": name, "slot": rect(x, y, width, height),
            "style": {"visibility": visibility},
            "content": {"brushPath": TEXTURES + texture + "_Mars_T"}}


def button(name, x, y, width, height):
    return {"type": "UserWidget", "id": name,
            "customClassPath": SKINS + "ButtonPaper_Mars_WBP.ButtonPaper_Mars_WBP_C",
            "slot": rect(x, y, width, height)}


def style_path(name):
    return STYLES + name + "_Mars_STYLE." + name + "_Mars_STYLE_C"


def asset(name, parent, width, height, children, style_map):
    return {"asset_path": DEST + name,
            "buildParams": {"mode": "rebuild", "overwrite": False,
                            "treat_warnings_as_errors": False, "raw_mode": True},
            "spec": {"version": 1, "name": name,
                     "parentClass": "/Script/Angelscript." + parent,
                     "metadata": {"authoringTool": "Monolith UISpec",
                                  "sourceFile": "Tools/StewardService/ui/parchment_specs.py",
                                  "description": "New Steward parchment; preserves old chalk WBPs."},
                     "rootWidget": {"type": "SizeBox", "id": "DesignSize",
                                    "style": {"width": width, "height": height},
                                    "children": [{"type": "CanvasPanel", "id": "Root", "children": children}]}},
            "styles": {key: style_path(value) for key, value in style_map.items()}}


row = asset("ServiceParchmentRow_Mars_WBP", "Mars_ChalkServiceRow_Widget", 680, 155, [
    # The physical parchment supplies the background. No per-row opaque panels.
    image("RowRule", "DividerDiamond", 34, 148, 612, 7),
    text("Title", "Service", 52, 14, 568, 50, 34),
    text("Summary", "Explore together", 52, 66, 568, 78, 22),
    image("SelectedMarker", "Checkmark", 8, 28, 32, 32, "Collapsed"),
    # Script toggles this on navigation focus or mouse hover.
    image("FocusCorners", "CategoryPointer", 12, 73, 28, 28, "Collapsed"),
], {"Title": "TextInk", "Summary": "TextInk"})
row["requiredBindings"] = {"Title": "UCommonTextBlock", "Summary": "UCommonTextBlock"}
row["optionalBindingsAuthored"] = {"SelectedMarker": "UWidget", "FocusCorners": "UWidget"}
row["postBuild"] = {"cdo": {"bToggleable": True, "bSelectable": True, "Style": style_path("ButtonPaper")},
                    "fontSizes": {"Title": 34, "Summary": 22}}

main = asset("ServiceParchment_Mars_WBP", "Mars_ChalkService_Widget", 800, 900, [
    {"type": "CommonBorder", "id": "Paper", "slot": rect(0, 0, 800, 900),
     "style": {"visibility": "HitTestInvisible"}},
    text("Heading", "AVAILABLE SERVICES", 55, 20, 690, 55, 38),
    image("HeadingRule", "DividerDiamond", 80, 76, 640, 10),
    text("Instructions", "Choose a service for your party", 70, 158, 660, 44, 25),
    {"type": "ScrollBox", "id": "ServicesScroll", "slot": rect(60, 90, 680, 620),
     "children": [{"type": "VerticalBox", "id": "ServiceRows"}]},
    text("PreviewTitle", "Choose a service", 76, 620, 648, 48, 30),
    text("PreviewSummary", "Browse a service to see its details.", 76, 674, 648, 88, 25),
    text("CurrentLabel", "CURRENT SERVICE", 76, 768, 224, 30, 20),
    text("CurrentSelection", "No service selected", 300, 766, 424, 40, 23),
    button("Confirm", 70, 752, 388, 58),
    button("Back", 478, 752, 252, 58),
    text("Status", "", 76, 834, 648, 32, 18),
], {"Paper": "BorderPaper", **{name: "TextInk" for name in
    ["Heading", "Instructions", "PreviewTitle", "PreviewSummary", "CurrentLabel", "CurrentSelection", "Status"]}})
main["requiredBindings"] = {"ServiceRows": "UPanelWidget (VerticalBox within ServicesScroll)",
    **{name: "UCommonTextBlock" for name in ["PreviewTitle", "PreviewSummary", "CurrentSelection", "Status"]},
    "Confirm": "UMars_Button_Widget (ButtonPaper_Mars_WBP)", "Back": "UMars_Button_Widget (ButtonPaper_Mars_WBP)"}
main["labels"] = {"Confirm": "Confirm & open gate", "Back": "Back"}
main["postBuild"] = {
    "cdo": {"RowClass": DEST + "ServiceParchmentRow_Mars_WBP.ServiceParchmentRow_Mars_WBP_C"},
    "fontSizes": {"Heading": 38, "Instructions": 25, "PreviewTitle": 30, "PreviewSummary": 25,
                  "CurrentLabel": 20, "CurrentSelection": 23, "Status": 18},
    "collapsed": ["Instructions", "PreviewTitle", "PreviewSummary", "CurrentLabel", "CurrentSelection"],
    "paperBrushTint": [0.86, 0.78, 0.62, 1.0],
    "ServicesScroll": {"orientation": "Vertical", "scrollBarVisibility": "Visible",
                       "allowOverscroll": False, "navigationDestination": "IntoView"},
}
for node in main["spec"]["rootWidget"]["children"][0]["children"]:
    if node["id"] in main["postBuild"]["collapsed"]:
        node.setdefault("style", {})["visibility"] = "Collapsed"

PAYLOAD = {
    "purpose": "New-only cream parchment mission list for the Steward, using existing service behavior.",
    "action": "ui::build_ui_from_spec",
    "boardUse": {"drawSize": [800, 900], "renderedSafeAreaCm": [76, 85.5],
                 "widgetWorldScale": 0.095, "anchorCenterZCm": 156.0,
                 "topZCm": 198.75, "bottomZCm": 113.25,
                 "visibleRows": 4, "rowHeightPx": 155, "listHeightPx": 620},
    "assets": [row, main],
    "setup": [
        "Assert both destinations absent. dry_run each spec with buildParams, inspect warnings, then create in manifest order with overwrite=false.",
        "raw_mode=true is deliberate: the live Monolith allowlist only exposes generic properties for CommonTextBlock. Keep it confined to these new destinations.",
        "Apply each external styles map via apply_style_to_widget; UISpec styleRef is for value styles and cannot reference an existing CommonUI style class.",
        "After styles apply, reapply postBuild.fontSizes and wrapping (styles can override font size). Keep ink dark on cream. Set Confirm/Back ButtonText, call RefreshLabel, compile/save.",
        "Set main CDO RowClass to the new row generated class. Row bToggleable=true is inherited; verify it remains true.",
        "Set ServicesScroll vertical/visible scrollbar/no overscroll. Verify focused rows scroll into view with navigation. No catalog preview children belong in ServiceRows: SetCatalog clears it.",
        "Compile both WBPs; read back requiredBindings, RowClass, button class/labels, styles/font sizes and 800x900 desired size.",
        "Render with a real catalog containing four services; verify four readable rows, wheel scrolling when catalog grows, keyboard/gamepad navigation, selection marker, status, Confirm and Back.",
        "Do not alter existing ChalkParchment WBPs or shared style classes. New dependencies only; no catalog icons are authored because service data has no icon binding.",
    ],
    "sources": [
        "Script/UI/Camp/Mars_ChalkCampWidgets.as: UMars_ChalkService_Widget / UMars_ChalkServiceRow_Widget",
        "Script/UI/Common/Mars_Button_Widget.as: optional SelectedMarker / FocusCorners bindings and indicator visibility",
        "docs/campaigns/2026-10-03-mars-ui-flow/tools/vestibule_widgets.py: new-only UISpec authoring pattern",
        "Content/Mars/UI/Styles/ChalkParchment/BorderPaper_Mars_STYLE.ckexport: parchment texture brush",
        "Content/Mars/UI/Styles/ChalkParchment/TextInk_Mars_STYLE.ckexport: Alegreya font / dark ink",
        "Live Monolith ui::dump_ui_spec_schema (2026-10-28): document/node fields and CommonTextBlock allowlist",
    ],
}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--write", action="store_true", help="write sibling parchment_specs.json")
    args = parser.parse_args()
    output = json.dumps(PAYLOAD, indent=2) + "\n"
    if args.write:
        path = Path(__file__).with_suffix(".json")
        path.write_text(output, encoding="utf-8")
        print(path)
    else:
        print(output, end="")
