// Validate() accepts a table with a Surface.Default row, and rejects, each naming its rule: no Default row, a row's or an
// impactor override's kind missing from Default, an invalid kind tag, an empty cell, unsorted or duplicate MinIntensity,
// a non-finite MinIntensity, a descending IntensityRange, a negative volume, a PitchJitter of 1, a negative
// RemoteVolumeScale and a zero EarshotDistance.
class UMars_AutoTest_SurfaceFx_ValidateRejectsInvalid : UMars_AutoTestRig_SurfaceFx
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("validate good and bad tables", n"Step_Validate");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Validate(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Good = Make_TableWithStone(GameplayTags::SurfaceFx_Footstep, Make_Cell(Make_Variant(0.0f, "StoneStep"))).Validate();
        Assert_True(Good.IsValid(), f"a table with a Default row is accepted (error: {Good.Get_Error()})");

        auto NoDefault = Make_Table();
        NoDefault.Rows.Remove(GameplayTags::Surface_Default);
        AssertRejected(NoDefault, "a table without a Default row");

        auto KindMissing = Make_TableWithStone(GameplayTags::SurfaceFx_Land, Make_Cell(Make_Variant(0.0f, "StoneLand")));
        Remove_DefaultKind(KindMissing, GameplayTags::SurfaceFx_Land);
        AssertRejected(KindMissing, "a row's kind the Default row lacks");

        auto OverrideKindMissing = Make_Table();
        auto Override = FMars_SurfaceFx_Kinds();
        Override.ByKind.Add(GameplayTags::SurfaceFx_Land, Make_Cell(Make_Variant(0.0f, "ImpactorLand")));
        auto Stone = FMars_SurfaceFx_Row();
        Stone.ByImpactor.Add(GameplayTags::Impactor, Override);
        OverrideKindMissing.Rows.Add(GameplayTags::Surface_Stone, Stone);
        Remove_DefaultKind(OverrideKindMissing, GameplayTags::SurfaceFx_Land);
        AssertRejected(OverrideKindMissing, "an impactor override's kind the Default row lacks");

        AssertRejected(Make_TableWithStone(FGameplayTag(), Make_Cell(Make_Variant(0.0f, "Nameless"))), "an invalid kind tag");
        AssertRejected(Make_TableWithStone(GameplayTags::SurfaceFx_Footstep, FMars_SurfaceFx_Cell()), "an empty cell");

        auto Unsorted = Make_Cell(Make_Variant(300.0f, "Heavy"));
        Unsorted.Variants.Add(Make_Variant(100.0f, "Light"));
        AssertRejected(Make_TableWithStone(GameplayTags::SurfaceFx_Impact, Unsorted), "variants in descending MinIntensity");

        auto Duplicate = Make_Cell(Make_Variant(100.0f, "First"));
        Duplicate.Variants.Add(Make_Variant(100.0f, "Second"));
        AssertRejected(Make_TableWithStone(GameplayTags::SurfaceFx_Impact, Duplicate), "two variants at one MinIntensity");

        AssertRejected(Make_TableWithStone(GameplayTags::SurfaceFx_Impact, Make_Cell(Make_Variant(float32(Math::Sqrt(-1.0)), "NaN"))),
            "a non-finite MinIntensity");

        auto Descending = Make_Variant(0.0f, "Descending");
        Descending.IntensityRange = FVector2D(300.0, 100.0);
        AssertRejected(Make_TableWithStone(GameplayTags::SurfaceFx_Impact, Make_Cell(Descending)), "a descending IntensityRange");

        auto Negative = Make_Variant(0.0f, "Negative");
        Negative.VolumeRange = FVector2D(-0.1, 1.0);
        AssertRejected(Make_TableWithStone(GameplayTags::SurfaceFx_Impact, Make_Cell(Negative)), "a negative volume");

        auto Jittery = Make_Variant(0.0f, "Jittery");
        Jittery.PitchJitter = 1.0f;
        AssertRejected(Make_TableWithStone(GameplayTags::SurfaceFx_Impact, Make_Cell(Jittery)), "a PitchJitter of 1");

        auto Loud = Make_Table();
        Loud.RemoteVolumeScale = -0.5f;
        AssertRejected(Loud, "a negative RemoteVolumeScale");

        auto Deaf = Make_Table();
        Deaf.EarshotDistance = 0.0f;
        AssertRejected(Deaf, "a zero EarshotDistance");
    }

    private void Remove_DefaultKind(UMars_SurfaceFx_Table InTable, FGameplayTag InKind)
    {
        FMars_SurfaceFx_Row Default;
        InTable.Rows.Find(GameplayTags::Surface_Default, Default);
        Default.Kinds.ByKind.Remove(InKind);
        InTable.Rows.Add(GameplayTags::Surface_Default, Default);
    }

    private void AssertRejected(const UMars_SurfaceFx_Table InTable, const FString& InWhat)
    {
        const auto Result = InTable.Validate();
        Assert_False(Result.IsValid(), f"{InWhat} is rejected");
        Assert_True(Result.Get_Error().Len() > 0, f"the rejection of {InWhat} names its rule (error: {Result.Get_Error()})");
    }
}
