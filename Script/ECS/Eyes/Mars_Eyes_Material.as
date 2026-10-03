// The only writer of the eye plate's custom primitive data; the layout is constants_eyes::k_Slot_*. Both eyes get the
// same blink (a wink is an expression).

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

namespace utils_eyes
{
    // One deferred request for the group; the plate applies it once its component exists.
    void Push_PlateGroup(FCk_Handle_UnrealComponent& InPlate, const FMars_Eyes_MaterialValues& InValues, EMars_Eyes_PlateGroup InGroup)
    {
        auto Data = FCk_CustomPrimitiveData();
        if (InGroup == EMars_Eyes_PlateGroup::Cells)
        { Data = FCk_CustomPrimitiveData(constants_eyes::k_Slot_Cells, FCk_CustomPrimitiveData_Value(DoMake_FourFloats(InValues.Cells))); }
        else if (InGroup == EMars_Eyes_PlateGroup::Anim)
        { Data = FCk_CustomPrimitiveData(constants_eyes::k_Slot_Anim, FCk_CustomPrimitiveData_Value(DoMake_FourFloats(InValues.Anim))); }
        else if (InGroup == EMars_Eyes_PlateGroup::Look)
        { Data = FCk_CustomPrimitiveData(constants_eyes::k_Slot_Look, FCk_CustomPrimitiveData_Value(InValues.Look)); }
        else
        {
            // A linear color is written as four floats; the fourth (alpha) is unused by the look.
            Data = FCk_CustomPrimitiveData(constants_eyes::k_Slot_Color, FCk_CustomPrimitiveData_Value(InValues.Color));
        }

        utils_unreal_component::Request_SetCustomPrimitiveData(InPlate, FCk_Request_UnrealComponent_SetCustomPrimitiveData(Data));
    }

    // The request writes a linear colour as four plain floats, and every value here is single-precision.
    FLinearColor DoMake_FourFloats(const FVector4& InValue)
    {
        return FLinearColor(float32(InValue.X), float32(InValue.Y), float32(InValue.Z), float32(InValue.W));
    }
}
