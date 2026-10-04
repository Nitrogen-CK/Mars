// The only writer of the eye plate's custom primitive data; the layout is constants_eyes::k_Slot_*. A group reaches a
// CkUnrealComponent plate as one deferred request (applied once its component exists) and a plate primitive straight
// away. Both eyes get the same blink (a wink is an expression).

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
    // To whichever the plate names: the primitive when set, else the CkUnrealComponent plate. The caller checks one is set.
    void Push_Group(FMars_Eyes_Plate& InPlate, const FMars_Eyes_MaterialValues& InValues, EMars_Eyes_PlateGroup InGroup)
    {
        auto Primitive = InPlate.Primitive.Get();
        if (ck::IsValid(Primitive))
        {
            Push_PrimitiveGroup(Primitive, InValues, InGroup);
            return;
        }

        Push_PlateGroup(InPlate.Component, InValues, InGroup);
    }

    // Straight into the primitive's custom primitive data (per primitive, so every material slot on it sees the values;
    // only the eye-plate slot reads them).
    void Push_PrimitiveGroup(UPrimitiveComponent InPrimitive, const FMars_Eyes_MaterialValues& InValues, EMars_Eyes_PlateGroup InGroup)
    {
        if (InGroup == EMars_Eyes_PlateGroup::Cells)
        { InPrimitive.SetCustomPrimitiveDataVector4(constants_eyes::k_Slot_Cells, InValues.Cells); }
        else if (InGroup == EMars_Eyes_PlateGroup::Anim)
        { InPrimitive.SetCustomPrimitiveDataVector4(constants_eyes::k_Slot_Anim, InValues.Anim); }
        else if (InGroup == EMars_Eyes_PlateGroup::Look)
        { InPrimitive.SetCustomPrimitiveDataVector2(constants_eyes::k_Slot_Look, InValues.Look); }
        else
        {
            // Four floats, like the request path; the fourth (alpha) is unused by the look.
            const auto& Color = InValues.Color;
            InPrimitive.SetCustomPrimitiveDataVector4(constants_eyes::k_Slot_Color, FVector4(Color.R, Color.G, Color.B, Color.A));
        }
    }

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
