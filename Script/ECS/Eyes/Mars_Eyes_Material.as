// The custom-primitive-data layout the eye-plate look reads, and the only writer of it. Each group's floats are
// consecutive from its slot; a group is pushed as one write. Both eyes get the same blink (a wink is an expression).

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

// Which value groups a push writes.
struct FMars_Eyes_PushGroups
{
    UPROPERTY()
    bool Cells = false;

    UPROPERTY()
    bool Anim = false;

    UPROPERTY()
    bool Look = false;

    UPROPERTY()
    bool Color = false;

    bool Get_Any() const
    {
        return Cells || Anim || Look || Color;
    }
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

    // Writes the requested groups to whichever plate the presentation names: straight into a primitive's custom
    // primitive data when a plate component is set (CPD is per primitive, so every material slot on it sees the values;
    // only the eye-plate slot reads them), else one deferred request per group to the CkUnrealComponent plate, which
    // applies them once its component exists. The caller checks that a plate is set.
    void Push(const FMars_Fragment_Eyes_Presentation& InPresentation, const FMars_Eyes_MaterialValues& InValues, const FMars_Eyes_PushGroups& InGroups)
    {
        auto Component = InPresentation.PlateComponent.Get();
        if (ck::IsValid(Component))
        {
            DoPush_Component(Component, InValues, InGroups);
            return;
        }

        auto Plate = InPresentation.Plate;
        DoPush_Plate(Plate, InValues, InGroups);
    }

    void DoPush_Component(UPrimitiveComponent InComponent, const FMars_Eyes_MaterialValues& InValues, const FMars_Eyes_PushGroups& InGroups)
    {
        if (InGroups.Cells)
        { InComponent.SetCustomPrimitiveDataVector4(Slot_Cells, InValues.Cells); }

        if (InGroups.Anim)
        { InComponent.SetCustomPrimitiveDataVector4(Slot_Anim, InValues.Anim); }

        if (InGroups.Look)
        { InComponent.SetCustomPrimitiveDataVector2(Slot_Look, InValues.Look); }

        // Four floats, like the request path; the fourth (alpha) is unused by the look.
        if (InGroups.Color)
        {
            const auto& Color = InValues.Color;
            InComponent.SetCustomPrimitiveDataVector4(Slot_Color, FVector4(Color.R, Color.G, Color.B, Color.A));
        }
    }

    void DoPush_Plate(FCk_Handle_UnrealComponent& InPlate, const FMars_Eyes_MaterialValues& InValues, const FMars_Eyes_PushGroups& InGroups)
    {
        if (InGroups.Cells)
        {
            utils_unreal_component::Request_SetCustomPrimitiveData(InPlate, FCk_Request_UnrealComponent_SetCustomPrimitiveData(
                FCk_CustomPrimitiveData(Slot_Cells, FCk_CustomPrimitiveData_Value(Make_FourFloats(InValues.Cells)))));
        }

        if (InGroups.Anim)
        {
            utils_unreal_component::Request_SetCustomPrimitiveData(InPlate, FCk_Request_UnrealComponent_SetCustomPrimitiveData(
                FCk_CustomPrimitiveData(Slot_Anim, FCk_CustomPrimitiveData_Value(Make_FourFloats(InValues.Anim)))));
        }

        if (InGroups.Look)
        {
            utils_unreal_component::Request_SetCustomPrimitiveData(InPlate, FCk_Request_UnrealComponent_SetCustomPrimitiveData(
                FCk_CustomPrimitiveData(Slot_Look, FCk_CustomPrimitiveData_Value(InValues.Look))));
        }

        // A linear color is written as four floats; the fourth (alpha) is unused by the look.
        if (InGroups.Color)
        {
            utils_unreal_component::Request_SetCustomPrimitiveData(InPlate, FCk_Request_UnrealComponent_SetCustomPrimitiveData(
                FCk_CustomPrimitiveData(Slot_Color, FCk_CustomPrimitiveData_Value(InValues.Color))));
        }
    }
}
