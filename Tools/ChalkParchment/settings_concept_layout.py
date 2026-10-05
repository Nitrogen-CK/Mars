"""Apply concept layout to the existing Settings templates. Run through editor MCP, PIE stopped."""
import unreal

BASE = '/Game/Mars/UI/Widgets/ChalkParchment/'
STYLE = '/Game/Mars/UI/Styles/ChalkParchment/'
LABEL_COLUMN_WIDTH = 335
CONTROL_INSET = 20

def widget(asset, name):
    path = BASE + asset + '_Mars_WBP'
    unreal.load_asset(path)
    result = unreal.find_object(None, path + '.' + asset + '_Mars_WBP:WidgetTree.' + name)
    assert result, (asset, name)
    result.modify()
    return result

def box(name, x, y, width, height):
    slot = widget('Settings', name).slot
    slot.set_position(unreal.Vector2D(x,y))
    slot.set_size(unreal.Vector2D(width,height))

def text_style(control, size):
    font = widget('SettingsToggleRow', '_DisplayNameText').get_editor_property('font')
    font.set_editor_property('size', size)
    font.set_editor_property('typeface_font_name','Bold')
    control.set_font(font)
    control.set_color_and_opacity(unreal.SlateColor(specified_color=unreal.LinearColor(.012,.009,.006,1)))
    control.set_style(unreal.load_class(None,STYLE+'TextSettingsLabel_Mars_STYLE.TextSettingsLabel_Mars_STYLE_C'))

def label_column(asset, row_name, label_name, controls):
    # LabelColumn is authored through MCP and compiled before reparenting, so
    # every widget has the GUID required by the Widget Blueprint compiler.
    row=widget(asset,row_name)
    label=widget(asset,label_name)
    column=widget(asset,'LabelColumn')
    children=[column]+[widget(asset,name) for name in controls]
    assert {child.get_name() for child in row.get_all_children()} <= {label_name,'LabelColumn',*controls}
    if label.get_parent()!=column:
        label.remove_from_parent()
        column.add_child(label)
    row.clear_children()
    for child in children:
        row.add_child(child)
    column.set_width_override(LABEL_COLUMN_WIDTH)
    column.slot.set_size(unreal.SlateChildSize(size_rule=unreal.SlateSizeRule.AUTOMATIC))
    column.slot.set_vertical_alignment(unreal.VerticalAlignment.V_ALIGN_FILL)
    label.set_min_desired_width(0)
    label.slot.set_padding(unreal.Margin(0,0,CONTROL_INSET,0))
    label.slot.set_vertical_alignment(unreal.VerticalAlignment.V_ALIGN_CENTER)

label_column('SettingsSliderRow','Row','_DisplayNameText',['SliderHitArea','_ValueText'])
label_column('SettingsToggleRow','Row','_DisplayNameText',['CheckHitArea','_ValueText'])
label_column('SettingsDropdownRow','Row','_DisplayNameText',['ControlSize'])
label_column('Settings','BindingsRow','BindingsLabel',['ViewBindings'])

for name, label in [('TabAudio','Audio'),('TabVideo','Video'),('TabControls','Controls'),('TabAccessibility','Accessibility'),('ViewBindings','VIEW BINDINGS'),('RestoreDefaults','Restore audio defaults')]:
    control = widget('Settings',name)
    control.set_editor_property('ButtonText',unreal.Text(label))
    control.set_editor_property('bAlignLabelLeft',name.startswith('Tab'))
    if name in ['TabAccessibility','ViewBindings']:
        control.set_is_enabled(False)

# A stable label/control/help grid, with one baseline per 100-unit row.
for index,name in enumerate(['TabAudio','TabVideo','TabControls','TabAccessibility']):
    box(name,100,232+index*96,275,80)
box('RailRule',395,215,1,475)
box('SectionText',430,215,720,64)
box('SectionRule',430,286,700,1)
box('RowsScroll',430,302,700,406)
box('HelpRule',1170,215,1,475)
box('HelpTitle',1200,222,270,112)
box('HelpDescription',1200,342,270,310)
box('RestoreDefaults',110,752,430,65)
box('PendingText',660,767,350,45)
box('BindingsRow',430,602,700,100)
widget('Settings','BindingsRow').set_visibility(unreal.SlateVisibility.COLLAPSED)
label=widget('Settings','BindingsLabel')
label.set_text(unreal.Text('Input bindings'))
text_style(label,28)
label.slot.set_vertical_alignment(unreal.VerticalAlignment.V_ALIGN_CENTER)
button=widget('Settings','ViewBindings')
button.slot.set_size(unreal.SlateChildSize(value=1,size_rule=unreal.SlateSizeRule.FILL))
button.slot.set_vertical_alignment(unreal.VerticalAlignment.V_ALIGN_CENTER)
button.slot.set_padding(unreal.Margin(20,12,0,12))

for asset in ['SettingsSliderRow','SettingsToggleRow','SettingsDropdownRow']:
    widget(asset,'Root').set_height_override(100)
    label=widget(asset,'_DisplayNameText')
    text_style(label,28)
    label.slot.set_padding(unreal.Margin(0,0,20,0))

readout=widget('SettingsSliderRow','_ValueText')
text_style(readout,26)
readout.set_style(unreal.load_class(None,STYLE+'TextSettingsValue_Mars_STYLE.TextSettingsValue_Mars_STYLE_C'))
readout.set_min_desired_width(90)
readout.set_editor_property('justification',unreal.TextJustify.RIGHT)
readout.slot.set_padding(unreal.Margin(12,0,8,0))
readout.slot.set_vertical_alignment(unreal.VerticalAlignment.V_ALIGN_CENTER)
widget('SettingsSliderRow','SliderHitArea').set_width_override(255)
widget('SettingsSliderRow','SliderHitArea').clear_min_desired_width()
check=widget('SettingsToggleRow','CheckHitArea')
check.set_width_override(48)
check.slot.set_padding(unreal.Margin(CONTROL_INSET,0,0,0))
widget('SettingsToggleRow','_ValueText').set_min_desired_width(285)
widget('SettingsToggleRow','_ValueText').slot.set_padding(unreal.Margin(12,0,0,0))
widget('SettingsToggleRow','_ValueText').slot.set_vertical_alignment(unreal.VerticalAlignment.V_ALIGN_CENTER)
text_style(widget('SettingsToggleRow','_ValueText'),28)
widget('SettingsToggleRow','_ValueText').set_style(unreal.load_class(None,STYLE+'TextSettingsValue_Mars_STYLE.TextSettingsValue_Mars_STYLE_C'))
combo=widget('SettingsDropdownRow','_ValueComboBox')
font=combo.get_editor_property('font')
font.set_editor_property('size',28)
combo.set_editor_property('font',font)
combo.get_parent().set_width_override(365)
combo.get_parent().slot.set_vertical_alignment(unreal.VerticalAlignment.V_ALIGN_CENTER)
combo.slot.set_padding(unreal.Margin(CONTROL_INSET,0,0,0))

def sized_brush(name, bounds, dimensions, size):
    b=unreal.SlateBrush()
    b.set_editor_property('resource_object',unreal.load_asset('/Game/Mars/UI/Textures/ChalkParchment/'+name+'_Mars_T'))
    v=unreal.DeprecateSlateVector2D()
    v.set_editor_property('x',size[0]); v.set_editor_property('y',size[1])
    b.set_editor_property('image_size',v)
    x0,y0,x1,y1=bounds; width,height=dimensions
    assert b.import_text(f'(UVRegion=(Min=(X={x0/width},Y={y0/height}),Max=(X={x1/width},Y={y1/height}),bIsValid=True))')
    b.set_editor_property('draw_as',unreal.SlateBrushDrawType.IMAGE)
    return b

track=sized_brush('SliderTrack',(72,272,2104,448),(2172,724),(253,12))
fill=sized_brush('SliderFill',(40,264,2136,464),(2172,724),(253,12))
thumb=sized_brush('ControlThumb',(88,88,1160,1160),(1254,1254),(40,40))
widget('SettingsSliderRow','SliderTrack').set_brush(track)
widget('SettingsSliderRow','SliderTrack').set_color_and_opacity(unreal.LinearColor(.40,.37,.30,1))
widget('SettingsSliderRow','SliderFill').set_brush(fill)
for name in ['TrackSize','FillSize']:
    control=widget('SettingsSliderRow',name)
    control.set_height_override(12)
    control.set_visibility(unreal.SlateVisibility.HIT_TEST_INVISIBLE)
    control.slot.set_vertical_alignment(unreal.VerticalAlignment.V_ALIGN_CENTER)
    control.slot.set_horizontal_alignment(unreal.HorizontalAlignment.H_ALIGN_FILL if name=='TrackSize' else unreal.HorizontalAlignment.H_ALIGN_LEFT)
    control.slot.set_padding(unreal.Margin(20,0,20,0))
slider=widget('SettingsSliderRow','_ValueSlider')
slider.slot.set_horizontal_alignment(unreal.HorizontalAlignment.H_ALIGN_FILL)
slider.slot.set_vertical_alignment(unreal.VerticalAlignment.V_ALIGN_FILL)
ss=slider.get_editor_property('widget_style')
for name in ['normal_bar_image','hovered_bar_image','disabled_bar_image']:
    empty=unreal.SlateBrush(); empty.set_editor_property('draw_as',unreal.SlateBrushDrawType.NO_DRAW_TYPE)
    ss.set_editor_property(name,empty)
for name in ['normal_thumb_image','hovered_thumb_image','disabled_thumb_image']:
    ss.set_editor_property(name,thumb)
slider.set_editor_property('widget_style',ss)
slider.set_editor_property('slider_handle_color',unreal.LinearColor(1,1,1,1))
slider.set_editor_property('indent_handle',False)
focus=widget('SettingsSliderRow','FocusCorners')
focus.set_visibility(unreal.SlateVisibility.COLLAPSED)
focus.slot.set_horizontal_alignment(unreal.HorizontalAlignment.H_ALIGN_FILL)
focus.slot.set_vertical_alignment(unreal.VerticalAlignment.V_ALIGN_FILL)
focus.slot.set_padding(unreal.Margin(0,24,0,24))
for corner in ['TL','TR','BR','BL']:
    target=widget('SettingsSliderRow','Focus'+corner)
    source=widget('ButtonPaper','Focus'+corner)
    target.set_brush(source.get_editor_property('brush'))
    target.set_render_transform(source.get_editor_property('render_transform'))
    target.set_desired_size_override(unreal.Vector2D(18,18))
    target.set_visibility(unreal.SlateVisibility.HIT_TEST_INVISIBLE)
    target.slot.set_horizontal_alignment(unreal.HorizontalAlignment.H_ALIGN_LEFT if corner.endswith('L') else unreal.HorizontalAlignment.H_ALIGN_RIGHT)
    target.slot.set_vertical_alignment(unreal.VerticalAlignment.V_ALIGN_TOP if corner.startswith('T') else unreal.VerticalAlignment.V_ALIGN_BOTTOM)
print('Concept Settings layout applied. Compile/save the four touched WBPs.')
