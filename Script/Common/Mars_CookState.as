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

namespace utils_cookstate
{
    // Indices 0..12 as cooking_spec.py / FOOD_LIBRARY.md lay them out, four Vector4 writes.
    void Write_CustomPrimitiveData(UPrimitiveComponent InComponent, const FMars_CookState& InState)
    {
        if (ck::EnsureIfNot(ck::IsValid(InComponent), "[CookState] has no component to write the cook state to"))
        { return; }

        if (ck::EnsureIfNot(InState.FaceSear.Num() == utils_searing::k_FaceCount,
            f"[CookState] [{InComponent.GetName()}] needs {utils_searing::k_FaceCount} face sears (got {InState.FaceSear.Num()})"))
        { return; }

        const auto& Sear = InState.FaceSear;
        InComponent.SetCustomPrimitiveDataVector4(0, FVector4(Sear[0], Sear[1], Sear[2], Sear[3]));
        InComponent.SetCustomPrimitiveDataVector4(4, FVector4(Sear[4], Sear[5], InState.Penetration, InState.OilCoat));
        InComponent.SetCustomPrimitiveDataVector4(8, FVector4(InState.Glaze, InState.Shape, InState.Fry, InState.Wet));
        InComponent.SetCustomPrimitiveDataVector4(12, FVector4(InState.Crumb, 0.0, 0.0, 0.0));
    }
}
