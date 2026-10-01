// The custom-primitive-data layout the eye-plate look reads, and the only writer of it. Each group's floats are
// consecutive from its slot; a group is pushed as one request. Both eyes get the same blink (a wink is an expression).

struct FMars_Eyes_MaterialValues
{
    UPROPERTY()
    FVector4 Cells;

    UPROPERTY()
    FVector4 Anim;

    UPROPERTY()
    FVector2D Look;

    UPROPERTY()
    FLinearColor Color;
}

namespace mars_eyes_material
{
    const int32 Slot_Cells = 0;    // LeftCell, RightCell, PrevLeftCell, PrevRightCell
    const int32 Slot_Anim = 4;     // Blend, BlinkLeft, BlinkRight, Strength
    const int32 Slot_Look = 8;     // LookX, LookY
    const int32 Slot_Color = 10;   // r, g, b, (unused)

    // The request writes a linear colour as four plain floats, and every value here is single-precision.
    FLinearColor Make_FourFloats(const FVector4& InValue)
    {
        return FLinearColor(float32(InValue.X), float32(InValue.Y), float32(InValue.Z), float32(InValue.W));
    }

    // One deferred request per requested group; the plate applies them once its component exists.
    void Push(FCk_Handle_UnrealComponent& InPlate, const FMars_Eyes_MaterialValues& InValues, bool InCells, bool InAnim, bool InLook, bool InColor)
    {
        if (InCells)
        {
            utils_unreal_component::Request_SetCustomPrimitiveData(InPlate, FCk_Request_UnrealComponent_SetCustomPrimitiveData(
                FCk_CustomPrimitiveData(Slot_Cells, FCk_CustomPrimitiveData_Value(Make_FourFloats(InValues.Cells)))));
        }

        if (InAnim)
        {
            utils_unreal_component::Request_SetCustomPrimitiveData(InPlate, FCk_Request_UnrealComponent_SetCustomPrimitiveData(
                FCk_CustomPrimitiveData(Slot_Anim, FCk_CustomPrimitiveData_Value(Make_FourFloats(InValues.Anim)))));
        }

        if (InLook)
        {
            utils_unreal_component::Request_SetCustomPrimitiveData(InPlate, FCk_Request_UnrealComponent_SetCustomPrimitiveData(
                FCk_CustomPrimitiveData(Slot_Look, FCk_CustomPrimitiveData_Value(InValues.Look))));
        }

        // A linear color is written as four floats; the fourth (alpha) is unused by the look.
        if (InColor)
        {
            utils_unreal_component::Request_SetCustomPrimitiveData(InPlate, FCk_Request_UnrealComponent_SetCustomPrimitiveData(
                FCk_CustomPrimitiveData(Slot_Color, FCk_CustomPrimitiveData_Value(InValues.Color))));
        }
    }
}
