// Generic gamepad key glyphs for UCommonActionWidget / UCk_InputActionWidget_UE.
// Brush lines are commented out until the Prompt_* textures exist under /Game/Mars and their
// accessors are generated (Script/Mars_Assets.as) - uncomment them, and the size locals, then.

TArray<FCommonInputKeyBrushConfiguration> Get_Mars_GenericGamepadBrushEntries()
{
    auto Entries = TArray<FCommonInputKeyBrushConfiguration>();
    const auto EmptyBrush = FSlateBrush();
    const auto BrushSize = FVector2D(32.0f, 32.0f);

    // Face buttons  (Bottom=A, Right=B, Left=X, Top=Y)
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Gamepad_FaceButton_Bottom, FSlateBrush(assets::load::Prompt_Joystick_A_Mars_T(), BrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Gamepad_FaceButton_Right, FSlateBrush(assets::load::Prompt_Joystick_B_Mars_T(), BrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Gamepad_FaceButton_Left, FSlateBrush(assets::load::Prompt_Joystick_X_Mars_T(), BrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Gamepad_FaceButton_Top, FSlateBrush(assets::load::Prompt_Joystick_Y_Mars_T(), BrushSize)));

    // Shoulders / bumpers
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Gamepad_LeftShoulder, FSlateBrush(assets::load::Prompt_Joystick_LB_Mars_T(), BrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Gamepad_RightShoulder, FSlateBrush(assets::load::Prompt_Joystick_RB_Mars_T(), BrushSize)));

    // Triggers (digital + analog axis)
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Gamepad_LeftTrigger, FSlateBrush(assets::load::Prompt_Joystick_LT_Mars_T(), BrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Gamepad_RightTrigger, FSlateBrush(assets::load::Prompt_Joystick_RT_Mars_T(), BrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Gamepad_LeftTriggerAxis, EmptyBrush));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Gamepad_RightTriggerAxis, EmptyBrush));

    // D-Pad
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Gamepad_DPad_Up, FSlateBrush(assets::load::Prompt_Joystick_ArrowUp_Mars_T(), BrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Gamepad_DPad_Down, FSlateBrush(assets::load::Prompt_Joystick_ArrowDown_Mars_T(), BrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Gamepad_DPad_Left, FSlateBrush(assets::load::Prompt_Joystick_ArrowLeft_Mars_T(), BrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Gamepad_DPad_Right, FSlateBrush(assets::load::Prompt_Joystick_ArrowRight_Mars_T(), BrushSize)));

    // Special buttons (View / Menu - aka Back / Start)
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Gamepad_Special_Left, FSlateBrush(assets::load::Prompt_Joystick_Share_Mars_T(), BrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Gamepad_Special_Right, FSlateBrush(assets::load::Prompt_Joystick_Start_Mars_T(), BrushSize)));

    // Thumbstick clicks
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Gamepad_LeftThumbstick, FSlateBrush(assets::load::Prompt_Joystick_L3_Mars_T(), BrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Gamepad_RightThumbstick, FSlateBrush(assets::load::Prompt_Joystick_R3_Mars_T(), BrushSize)));

    // Left stick directional (digital)
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Gamepad_LeftStick_Up, FSlateBrush(assets::load::Prompt_Joystick_LUp_Mars_T(), BrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Gamepad_LeftStick_Down, FSlateBrush(assets::load::Prompt_Joystick_LDown_Mars_T(), BrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Gamepad_LeftStick_Left, FSlateBrush(assets::load::Prompt_Joystick_LLeft_Mars_T(), BrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Gamepad_LeftStick_Right, FSlateBrush(assets::load::Prompt_Joystick_LRight_Mars_T(), BrushSize)));

    // Right stick directional (digital)
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Gamepad_RightStick_Up, FSlateBrush(assets::load::Prompt_Joystick_RUp_Mars_T(), BrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Gamepad_RightStick_Down, FSlateBrush(assets::load::Prompt_Joystick_RDown_Mars_T(), BrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Gamepad_RightStick_Left, FSlateBrush(assets::load::Prompt_Joystick_RLeft_Mars_T(), BrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Gamepad_RightStick_Right, FSlateBrush(assets::load::Prompt_Joystick_RRight_Mars_T(), BrushSize)));


    return Entries;
}

UCLASS(Abstract)
class UMars_GenericGamepad_ControllerData : UCommonInputBaseControllerData
{
    default InputType = ECommonInputType::Gamepad;
    default GamepadName = n"Windows";
    default InputBrushDataMap = Get_Mars_GenericGamepadBrushEntries();
}
