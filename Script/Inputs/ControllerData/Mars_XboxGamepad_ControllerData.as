// Xbox gamepad key glyphs for UCommonActionWidget / UCk_InputActionWidget_UE.
// No Xbox or PS5 glyph textures exist yet, so every key maps to an empty brush (the generic gamepad data has them).

// Every gamepad key with an empty brush; the Xbox and PS5 controller data share it until their glyphs exist.
TArray<FCommonInputKeyBrushConfiguration> Get_Mars_EmptyGamepadBrushEntries()
{
    auto Entries = TArray<FCommonInputKeyBrushConfiguration>();
    const auto EmptyBrush = FSlateBrush();

    // Face buttons  (Bottom=A/Cross, Right=B/Circle, Left=X/Square, Top=Y/Triangle)
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Gamepad_FaceButton_Bottom, EmptyBrush));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Gamepad_FaceButton_Right, EmptyBrush));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Gamepad_FaceButton_Left, EmptyBrush));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Gamepad_FaceButton_Top, EmptyBrush));

    // Shoulders / bumpers
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Gamepad_LeftShoulder, EmptyBrush));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Gamepad_RightShoulder, EmptyBrush));

    // Triggers (digital + analog axis)
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Gamepad_LeftTrigger, EmptyBrush));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Gamepad_RightTrigger, EmptyBrush));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Gamepad_LeftTriggerAxis, EmptyBrush));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Gamepad_RightTriggerAxis, EmptyBrush));

    // D-Pad
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Gamepad_DPad_Up, EmptyBrush));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Gamepad_DPad_Down, EmptyBrush));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Gamepad_DPad_Left, EmptyBrush));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Gamepad_DPad_Right, EmptyBrush));

    // Special buttons (View / Menu, Create / Options)
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Gamepad_Special_Left, EmptyBrush));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Gamepad_Special_Right, EmptyBrush));

    // Thumbstick clicks
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
class UMars_XboxGamepad_ControllerData : UCommonInputBaseControllerData
{
    default InputType = ECommonInputType::Gamepad;
    default GamepadName = n"XboxOne";
    default InputBrushDataMap = Get_Mars_EmptyGamepadBrushEntries();
}
