// Within a cell the highest variant at or below the intensity plays, its volume mapped and clamped from IntensityRange
// onto VolumeRange. Below the lowest variant nothing plays, and the event does not fall through to the Default row even
// though Default would play at that intensity.
class UMars_AutoTest_SurfaceFx_VariantByIntensity : UMars_AutoTestRig_SurfaceFx
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("pick variants by intensity", n"Step_Pick");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Pick(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Light = Make_Variant(100.0f, "Light");
        Light.IntensityRange = FVector2D(100.0, 300.0);
        Light.VolumeRange = FVector2D(0.2, 0.5);

        auto Cell = Make_Cell(Light);
        Cell.Variants.Add(Make_Variant(300.0f, "Heavy"));

        const auto Table = Make_TableWithStone(GameplayTags::SurfaceFx_Impact, Cell);
        const auto Valid = Table.Validate();
        Assert_True(Valid.IsValid(), f"the test table validates (error: {Valid.Get_Error()})");

        Assert_Plays(Table, Make_Event(GameplayTags::SurfaceFx_Impact, GameplayTags::Surface_Stone, 50.0f), "");
        Assert_Plays(Table, Make_Event(GameplayTags::SurfaceFx_Impact, GameplayTags::Surface_Stone, 100.0f), "Light");
        Assert_Plays(Table, Make_Event(GameplayTags::SurfaceFx_Impact, GameplayTags::Surface_Stone, 299.0f), "Light");
        Assert_Plays(Table, Make_Event(GameplayTags::SurfaceFx_Impact, GameplayTags::Surface_Stone, 300.0f), "Heavy");
        Assert_Plays(Table, Make_Event(GameplayTags::SurfaceFx_Impact, GameplayTags::Surface_Stone, 5000.0f), "Heavy");

        Assert_Volume(Table, 100.0f, 0.2f);
        Assert_Volume(Table, 200.0f, 0.35f);
        Assert_Volume(Table, 300.0f, 1.0f);
    }

    private void Assert_Volume(const UMars_SurfaceFx_Table InTable, float32 InIntensity, float32 InExpected)
    {
        const auto Resolved = utils_surface_fx::Resolve(InTable, Make_Event(GameplayTags::SurfaceFx_Impact, GameplayTags::Surface_Stone, InIntensity));
        Assert_True(Resolved.IsSet(), f"an impact at {InIntensity} plays");
        if (Resolved.IsSet() == false)
        { return; }

        Assert_Equals_Float(Resolved.GetValue().Volume, InExpected, 0.001, f"an impact at {InIntensity} plays at volume {InExpected}");
    }
}
