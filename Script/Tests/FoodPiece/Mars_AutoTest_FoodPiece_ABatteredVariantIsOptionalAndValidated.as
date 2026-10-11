// Not every food is batterable: a definition without a battered mesh validates and is not batterable (the meat slab), one
// with a battered mesh validates and is (the whole mushroom), and so does a battered mesh with a small pivot offset. A copy
// of the whole mushroom is rejected, each naming its rule, with a non-finite pivot offset, a pivot offset beyond
// constants_food::k_MaxBatteredPivotOffsetCm, an empty battered material slot, and battered materials or a pivot offset but
// no battered mesh.
class UMars_AutoTest_FoodPiece_ABatteredVariantIsOptionalAndValidated : UCk_AutoTest_Base
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("validate foods with and without a battered variant", n"Step_Validate");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Validate(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto MeatSlab = mars::Food_MeatSlab_Mars.Validate();
        Assert_True(MeatSlab.IsValid(), f"a food without a battered mesh is accepted (error: {MeatSlab.Get_Error()})");
        Assert_False(mars::Food_MeatSlab_Mars.Get_IsBatterable(), "a food without a battered mesh is not batterable");

        const auto Mushroom = mars::Food_Mushroom_Mars.Validate();
        Assert_True(Mushroom.IsValid(), f"a food with a battered mesh is accepted (error: {Mushroom.Get_Error()})");
        Assert_True(mars::Food_Mushroom_Mars.Get_IsBatterable(), "a food with a battered mesh is batterable");

        auto Shifted = Make_Copy();
        Shifted.Visuals.Battered.PivotOffset = FVector(0.0, 0.0, 2.0);
        const auto ShiftedResult = Shifted.Validate();
        Assert_True(ShiftedResult.IsValid(), f"a small pivot offset is accepted (error: {ShiftedResult.Get_Error()})");

        auto NotFinite = Make_Copy();
        NotFinite.Visuals.Battered.PivotOffset = FVector(Math::Sqrt(-1.0), 0.0, 0.0);
        AssertRejected(NotFinite, "a non-finite pivot offset");

        auto Absurd = Make_Copy();
        Absurd.Visuals.Battered.PivotOffset = FVector(0.0, 0.0, constants_food::k_MaxBatteredPivotOffsetCm * 2.0);
        AssertRejected(Absurd, "a pivot offset beyond the ceiling");

        auto EmptySlot = Make_Copy();
        EmptySlot.Visuals.Battered.Materials.Add(TSoftObjectPtr<UMaterialInterface>());
        AssertRejected(EmptySlot, "an empty battered material slot");

        auto MaterialsWithoutMesh = Make_Copy();
        MaterialsWithoutMesh.Visuals.Battered.Mesh = TSoftObjectPtr<UStaticMesh>();
        MaterialsWithoutMesh.Visuals.Battered.Materials.Add(TSoftObjectPtr<UMaterialInterface>(assets::Mushroom_Batter_Mars_MI().ToSoftObjectPath()));
        AssertRejected(MaterialsWithoutMesh, "battered materials without a battered mesh");

        auto OffsetWithoutMesh = Make_Copy();
        OffsetWithoutMesh.Visuals.Battered.Mesh = TSoftObjectPtr<UStaticMesh>();
        OffsetWithoutMesh.Visuals.Battered.PivotOffset = FVector(1.0, 0.0, 0.0);
        AssertRejected(OffsetWithoutMesh, "a pivot offset without a battered mesh");
    }

    // A fresh definition with the whole mushroom's fields.
    private UMars_Food_Def Make_Copy()
    {
        const auto Source = mars::Food_Mushroom_Mars;
        auto Copy = NewObject(this, UMars_Food_Def);
        Copy.Data = Source.Data;
        Copy.Tuners = Source.Tuners;
        Copy.Body = Source.Body;
        Copy.Visuals = Source.Visuals;
        Copy.Layout = Source.Layout;
        return Copy;
    }

    private void AssertRejected(UMars_Food_Def InFood, const FString& InWhat)
    {
        const auto Result = InFood.Validate();
        Assert_False(Result.IsValid(), f"{InWhat} is rejected");
        Assert_True(Result.Get_Error().Len() > 0, f"the rejection of {InWhat} names its rule (error: {Result.Get_Error()})");
    }
}
