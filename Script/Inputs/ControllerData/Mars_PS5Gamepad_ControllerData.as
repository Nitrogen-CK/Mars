// PlayStation 5 gamepad key glyphs for UCommonActionWidget / UCk_InputActionWidget_UE.
// No PS5 glyph textures exist yet, so every key maps to an empty brush.

TArray<FCommonInputKeyBrushConfiguration> Get_Mars_PS5GamepadBrushEntries()
{
    auto Entries = TArray<FCommonInputKeyBrushConfiguration>();
    const auto EmptyBrush = FSlateBrush();

    // Face buttons  (Bottom=Cross, Right=Circle, Left=Square, Top=Triangle)
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Gamepad_FaceButton_Bottom, EmptyBrush));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Gamepad_FaceButton_Right, EmptyBrush));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Gamepad_FaceButton_Left, EmptyBrush));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Gamepad_FaceButton_Top, EmptyBrush));

    // Shoulders / bumpers (L1 / R1)
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Gamepad_LeftShoulder, EmptyBrush));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Gamepad_RightShoulder, EmptyBrush));

    // Triggers (L2 / R2 - digital + analog axis)
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Gamepad_LeftTrigger, EmptyBrush));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Gamepad_RightTrigger, EmptyBrush));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Gamepad_LeftTriggerAxis, EmptyBrush));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Gamepad_RightTriggerAxis, EmptyBrush));

    // D-Pad
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Gamepad_DPad_Up, EmptyBrush));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Gamepad_DPad_Down, EmptyBrush));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Gamepad_DPad_Left, EmptyBrush));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Gamepad_DPad_Right, EmptyBrush));

    // Special buttons (Create / Options)
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Gamepad_Special_Left, EmptyBrush));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Gamepad_Special_Right, EmptyBrush));

    // Thumbstick clicks (L3 / R3)
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Gamepad_LeftThumbstick, EmptyBrush));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Gamepad_RightThumbstick, EmptyBrush));

    // Left stick directional (digital)
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Gamepad_LeftStick_Up, EmptyBrush));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Gamepad_LeftStick_Down, EmptyBrush));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Gamepad_LeftStick_Left, EmptyBrush));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Gamepad_LeftStick_Right, EmptyBrush));

    // Right stick directional (digital)
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Gamepad_RightStick_Up, EmptyBrush));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Gamepad_RightStick_Down, EmptyBrush));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Gamepad_RightStick_Left, EmptyBrush));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Gamepad_RightStick_Right, EmptyBrush));

    return Entries;
}

UCLASS(Abstract)
class UMars_PS5Gamepad_ControllerData : UCommonInputBaseControllerData
{
    default InputType = ECommonInputType::Gamepad;
    default GamepadName = n"PS5";
    default InputBrushDataMap = Get_Mars_PS5GamepadBrushEntries();
}
