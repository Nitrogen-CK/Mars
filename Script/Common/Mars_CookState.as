// The cooking materials' per-component float block (Custom Primitive Data 0..12): sear per face in the mesh's local axes
// (0 raw, 1 full crust, 2 burnt), then the finish, then the crumb coating at 12. One struct and one writer for every cooking
// mesh the project drives.
struct FMars_CookState
{
    // Six, indexed by int32(EMars_Searing_Face): +X -X +Y -Y +Z -Z.
    UPROPERTY()
    TArray<float32> FaceSear;

    UPROPERTY()
    float32 Penetration = 0.0f;

    UPROPERTY()
    float32 OilCoat = 0.0f;

    UPROPERTY()
    float32 Glaze = 0.0f;

    // Raw to cooked silhouette, 0..1.
    UPROPERTY()
    float32 Shape = 0.0f;

    // Batter: 0 raw, 1 golden, 2 burnt.
    UPROPERTY()
    float32 Fry = 0.0f;

    // Stew soak, 0..1.
    UPROPERTY()
    float32 Wet = 0.0f;

    // Crumb coating coverage, 0..1.
    UPROPERTY()
    float32 Crumb = 0.0f;

    FMars_CookState()
    {
        for (int32 Index = 0; Index < utils_searing::k_FaceCount; ++Index)
        { FaceSear.Add(0.0f); }
    }
}

namespace constants_cookstate
{
    // A display's cook state is rewritten only once one of its floats has moved this far since the last write.
    const float32 k_WriteThreshold = 0.02f;
}

namespace utils_cookstate
{
    // Indices 0..12 as cooking_spec.py / FOOD_LIBRARY.md lay them out, as four Vector4 groups at 0, 4, 8 and 12. Expects six
    // face sears; the writers check.
    TArray<FCk_CustomPrimitiveData> Make_CustomPrimitiveData(const FMars_CookState& InState)
    {
        const auto& Sear = InState.FaceSear;
        auto Data = TArray<FCk_CustomPrimitiveData>();
        Data.Add(FCk_CustomPrimitiveData(0, FCk_CustomPrimitiveData_Value(FVector4(Sear[0], Sear[1], Sear[2], Sear[3]))));
        Data.Add(FCk_CustomPrimitiveData(4, FCk_CustomPrimitiveData_Value(FVector4(Sear[4], Sear[5], InState.Penetration, InState.OilCoat))));
        Data.Add(FCk_CustomPrimitiveData(8, FCk_CustomPrimitiveData_Value(FVector4(InState.Glaze, InState.Shape, InState.Fry, InState.Wet))));
        Data.Add(FCk_CustomPrimitiveData(12, FCk_CustomPrimitiveData_Value(FVector4(InState.Crumb, 0.0, 0.0, 0.0))));
        return Data;
    }

    void Write_CustomPrimitiveData(UPrimitiveComponent InComponent, const FMars_CookState& InState)
    {
        if (ck::EnsureIfNot(ck::IsValid(InComponent), "[CookState] has no component to write the cook state to"))
        { return; }

        if (ck::EnsureIfNot(InState.FaceSear.Num() == utils_searing::k_FaceCount,
            f"[CookState] [{InComponent.GetName()}] needs {utils_searing::k_FaceCount} face sears (got {InState.FaceSear.Num()})"))
        { return; }

        for (const auto& Data : Make_CustomPrimitiveData(InState))
        { utils_graphics::Apply_CustomPrimitiveData(InComponent, Data); }
    }

    // A RuntimeMesh display owns its component, so the write is deferred: one request per group, applied once the display is
    // Ready.
    void Request_Write(FCk_Handle_RuntimeMeshDisplay InDisplay, const FMars_CookState& InState)
    {
        if (ck::EnsureIfNot(InState.FaceSear.Num() == utils_searing::k_FaceCount,
            f"[CookState] a display write needs {utils_searing::k_FaceCount} face sears (got {InState.FaceSear.Num()})"))
        { return; }

        for (const auto& Data : Make_CustomPrimitiveData(InState))
        { utils_runtime_mesh_display::Request_SetCustomPrimitiveData(InDisplay, FCk_Request_RuntimeMeshDisplay_SetCustomPrimitiveData(Data)); }
    }

    // True once any of the 13 floats differs by at least InThreshold.
    bool Get_HasMovedBeyond(const FMars_CookState& InFrom, const FMars_CookState& InTo, float32 InThreshold)
    {
        if (ck::EnsureIfNot(InFrom.FaceSear.Num() == utils_searing::k_FaceCount && InTo.FaceSear.Num() == utils_searing::k_FaceCount,
            f"[CookState] compares {InFrom.FaceSear.Num()} face sears with {InTo.FaceSear.Num()} (needs {utils_searing::k_FaceCount} each)"))
        { return true; }

        for (int32 Face = 0; Face < utils_searing::k_FaceCount; ++Face)
        {
            if (Math::Abs(InTo.FaceSear[Face] - InFrom.FaceSear[Face]) >= InThreshold)
            { return true; }
        }

        return Math::Abs(InTo.Penetration - InFrom.Penetration) >= InThreshold
            || Math::Abs(InTo.OilCoat - InFrom.OilCoat) >= InThreshold
            || Math::Abs(InTo.Glaze - InFrom.Glaze) >= InThreshold
            || Math::Abs(InTo.Shape - InFrom.Shape) >= InThreshold
            || Math::Abs(InTo.Fry - InFrom.Fry) >= InThreshold
            || Math::Abs(InTo.Wet - InFrom.Wet) >= InThreshold
            || Math::Abs(InTo.Crumb - InFrom.Crumb) >= InThreshold;
    }
}
