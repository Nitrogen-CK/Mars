// Keyboard & mouse key glyphs for UCommonActionWidget / UCk_InputActionWidget_UE.
// Brush lines are commented out until the Prompt_* textures exist under /Game/Mars and their
// accessors are generated (Script/Mars_Assets.as) - uncomment them, and the size locals, then.

TArray<FCommonInputKeyBrushConfiguration> Get_Mars_KeyboardBrushEntries()
{
    auto Entries = TArray<FCommonInputKeyBrushConfiguration>();
    const auto EmptyBrush = FSlateBrush();
    const auto BrushSize = FVector2D(32.0f, 32.0f);
    const auto WideBrushSize = FVector2D(64.0f, 32.0f);

    // Letters
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::A, FSlateBrush(assets::load::Prompt_PC_A_Mars_T(), BrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::B, FSlateBrush(assets::load::Prompt_PC_B_Mars_T(), BrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::C, FSlateBrush(assets::load::Prompt_PC_C_Mars_T(), BrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::D, FSlateBrush(assets::load::Prompt_PC_D_Mars_T(), BrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::E, FSlateBrush(assets::load::Prompt_PC_E_Mars_T(), BrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::F, FSlateBrush(assets::load::Prompt_PC_F_Mars_T(), BrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::G, FSlateBrush(assets::load::Prompt_PC_G_Mars_T(), BrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::H, FSlateBrush(assets::load::Prompt_PC_H_Mars_T(), BrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::I, FSlateBrush(assets::load::Prompt_PC_I_Mars_T(), BrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::J, FSlateBrush(assets::load::Prompt_PC_J_Mars_T(), BrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::K, FSlateBrush(assets::load::Prompt_PC_K_Mars_T(), BrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::L, FSlateBrush(assets::load::Prompt_PC_L_Mars_T(), BrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::M, FSlateBrush(assets::load::Prompt_PC_M_Mars_T(), BrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::N, FSlateBrush(assets::load::Prompt_PC_N_Mars_T(), BrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::O, FSlateBrush(assets::load::Prompt_PC_O_Mars_T(), BrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::P, FSlateBrush(assets::load::Prompt_PC_P_Mars_T(), BrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Q, FSlateBrush(assets::load::Prompt_PC_Q_Mars_T(), BrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::R, FSlateBrush(assets::load::Prompt_PC_R_Mars_T(), BrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::S, FSlateBrush(assets::load::Prompt_PC_S_Mars_T(), BrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::T, FSlateBrush(assets::load::Prompt_PC_T_Mars_T(), BrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::U, FSlateBrush(assets::load::Prompt_PC_U_Mars_T(), BrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::V, FSlateBrush(assets::load::Prompt_PC_V_Mars_T(), BrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::W, FSlateBrush(assets::load::Prompt_PC_W_Mars_T(), BrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::X, FSlateBrush(assets::load::Prompt_PC_X_Mars_T(), BrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Y, FSlateBrush(assets::load::Prompt_PC_Y_Mars_T(), BrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Z, FSlateBrush(assets::load::Prompt_PC_Z_Mars_T(), BrushSize)));

    // Number row
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Zero, FSlateBrush(assets::load::Prompt_PC_0_Mars_T(), BrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::One, FSlateBrush(assets::load::Prompt_PC_1_Mars_T(), BrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Two, FSlateBrush(assets::load::Prompt_PC_2_Mars_T(), BrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Three, FSlateBrush(assets::load::Prompt_PC_3_Mars_T(), BrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Four, FSlateBrush(assets::load::Prompt_PC_4_Mars_T(), BrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Five, FSlateBrush(assets::load::Prompt_PC_5_Mars_T(), BrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Six, FSlateBrush(assets::load::Prompt_PC_6_Mars_T(), BrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Seven, FSlateBrush(assets::load::Prompt_PC_7_Mars_T(), BrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Eight, FSlateBrush(assets::load::Prompt_PC_8_Mars_T(), BrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Nine, FSlateBrush(assets::load::Prompt_PC_9_Mars_T(), BrushSize)));

    // Function keys
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::F1, FSlateBrush(assets::load::Prompt_PC_F1_Mars_T(), BrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::F2, FSlateBrush(assets::load::Prompt_PC_F2_Mars_T(), BrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::F3, FSlateBrush(assets::load::Prompt_PC_F3_Mars_T(), BrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::F4, FSlateBrush(assets::load::Prompt_PC_F4_Mars_T(), BrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::F5, FSlateBrush(assets::load::Prompt_PC_F5_Mars_T(), BrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::F6, FSlateBrush(assets::load::Prompt_PC_F6_Mars_T(), BrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::F7, FSlateBrush(assets::load::Prompt_PC_F7_Mars_T(), BrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::F8, FSlateBrush(assets::load::Prompt_PC_F8_Mars_T(), BrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::F9, FSlateBrush(assets::load::Prompt_PC_F9_Mars_T(), BrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::F10, FSlateBrush(assets::load::Prompt_PC_F10_Mars_T(), BrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::F11, FSlateBrush(assets::load::Prompt_PC_F11_Mars_T(), BrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::F12, FSlateBrush(assets::load::Prompt_PC_F12_Mars_T(), BrushSize)));

    // Modifiers
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::LeftShift, FSlateBrush(assets::load::Prompt_PC_LShift_Mars_T(), WideBrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::RightShift, FSlateBrush(assets::load::Prompt_PC_RShift_Mars_T(), WideBrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::LeftControl, FSlateBrush(assets::load::Prompt_PC_Ctrl_Mars_T(), WideBrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::RightControl, FSlateBrush(assets::load::Prompt_PC_Ctrl_Mars_T(), WideBrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::LeftAlt, FSlateBrush(assets::load::Prompt_PC_Alt_Mars_T(), WideBrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::RightAlt, FSlateBrush(assets::load::Prompt_PC_Alt_Mars_T(), WideBrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::LeftCommand, EmptyBrush));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::RightCommand, EmptyBrush));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::CapsLock, FSlateBrush(assets::load::Prompt_PC_CapsLock_Mars_T(), WideBrushSize)));

    // Navigation
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Up, FSlateBrush(assets::load::Prompt_PC_Up_Mars_T(), BrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Down, FSlateBrush(assets::load::Prompt_PC_Down_Mars_T(), BrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Left, FSlateBrush(assets::load::Prompt_PC_Left_Mars_T(), BrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Right, FSlateBrush(assets::load::Prompt_PC_Right_Mars_T(), BrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Home, FSlateBrush(assets::load::Prompt_PC_Home_Mars_T(), BrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::End, FSlateBrush(assets::load::Prompt_PC_End_Mars_T(), BrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::PageUp, FSlateBrush(assets::load::Prompt_PC_PageUp_Mars_T(), BrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::PageDown, FSlateBrush(assets::load::Prompt_PC_PageDown_Mars_T(), BrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Insert, FSlateBrush(assets::load::Prompt_PC_Insert_Mars_T(), BrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Delete, FSlateBrush(assets::load::Prompt_PC_Delete_Mars_T(), BrushSize)));

    // Editing / whitespace
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::SpaceBar, FSlateBrush(assets::load::Prompt_PC_Space_Mars_T(), WideBrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Enter, FSlateBrush(assets::load::Prompt_PC_Enter_Mars_T(), WideBrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Tab, FSlateBrush(assets::load::Prompt_PC_Tab_Mars_T(), WideBrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Escape, FSlateBrush(assets::load::Prompt_PC_ESC_Mars_T(), BrushSize)));

    // Symbols / punctuation
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Hyphen, FSlateBrush(assets::load::Prompt_PC_Subtract_Mars_T(), BrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Equals, FSlateBrush(assets::load::Prompt_PC_Equals_Mars_T(), BrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::LeftBracket, FSlateBrush(assets::load::Prompt_PC_LBracket_Mars_T(), BrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::RightBracket, FSlateBrush(assets::load::Prompt_PC_RBracket_Mars_T(), BrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Backslash, FSlateBrush(assets::load::Prompt_PC_Backslash_Mars_T(), BrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Semicolon, FSlateBrush(assets::load::Prompt_PC_SemiColon_Mars_T(), BrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Apostrophe, FSlateBrush(assets::load::Prompt_PC_Apostrophe_Mars_T(), BrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Quote, FSlateBrush(assets::load::Prompt_PC_Quote_Mars_T(), BrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Comma, FSlateBrush(assets::load::Prompt_PC_Comma_Mars_T(), BrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Period, FSlateBrush(assets::load::Prompt_PC_Period_Mars_T(), BrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Slash, FSlateBrush(assets::load::Prompt_PC_Slash_Mars_T(), BrushSize)));

    // Numpad
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::NumPadZero, FSlateBrush(assets::load::Prompt_PC_0_Mars_T(), BrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::NumPadOne, FSlateBrush(assets::load::Prompt_PC_1_Mars_T(), BrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::NumPadTwo, FSlateBrush(assets::load::Prompt_PC_2_Mars_T(), BrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::NumPadThree, FSlateBrush(assets::load::Prompt_PC_3_Mars_T(), BrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::NumPadFour, FSlateBrush(assets::load::Prompt_PC_4_Mars_T(), BrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::NumPadFive, FSlateBrush(assets::load::Prompt_PC_5_Mars_T(), BrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::NumPadSix, FSlateBrush(assets::load::Prompt_PC_6_Mars_T(), BrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::NumPadSeven, FSlateBrush(assets::load::Prompt_PC_7_Mars_T(), BrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::NumPadEight, FSlateBrush(assets::load::Prompt_PC_8_Mars_T(), BrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::NumPadNine, FSlateBrush(assets::load::Prompt_PC_9_Mars_T(), BrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Add, FSlateBrush(assets::load::Prompt_PC_Add_Mars_T(), BrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Subtract, FSlateBrush(assets::load::Prompt_PC_Subtract_Mars_T(), BrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Multiply, FSlateBrush(assets::load::Prompt_PC_Multiply_Mars_T(), BrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::Divide, FSlateBrush(assets::load::Prompt_PC_Slash_Mars_T(), BrushSize)));

    // Lock keys
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::NumLock, FSlateBrush(assets::load::Prompt_PC_NumLock_Mars_T(), WideBrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::ScrollLock, FSlateBrush(assets::load::Prompt_PC_ScrollLock_Mars_T(), WideBrushSize)));

    // Mouse buttons
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::LeftMouseButton, FSlateBrush(assets::load::Prompt_PC_MouseLeftClick_Mars_T(), BrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::RightMouseButton, FSlateBrush(assets::load::Prompt_PC_MouseRightClick_Mars_T(), BrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::MiddleMouseButton, FSlateBrush(assets::load::Prompt_PC_MouseMiddleClick_Mars_T(), BrushSize)));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::ThumbMouseButton, EmptyBrush));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::ThumbMouseButton2, EmptyBrush));

    // Mouse wheel
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::MouseScrollUp, EmptyBrush));
    Entries.Add(Make_CommonInputKeyBrushConfiguration(EKeys::MouseScrollDown, EmptyBrush));


    return Entries;
}

UCLASS(Abstract)
class UMars_Keyboard_ControllerData : UCommonInputBaseControllerData
{
    default InputType = ECommonInputType::MouseAndKeyboard;
    default InputBrushDataMap = Get_Mars_KeyboardBrushEntries();
}
