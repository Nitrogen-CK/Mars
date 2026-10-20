// PlayStation 5 gamepad key glyphs for UCommonActionWidget / UCk_InputActionWidget_UE: the Xbox data's empty brushes
// (Get_Mars_EmptyGamepadBrushEntries) until its glyph textures exist; only the gamepad name differs.
UCLASS(Abstract)
class UMars_PS5Gamepad_ControllerData : UMars_XboxGamepad_ControllerData
{
    default GamepadName = n"PS5";
}
