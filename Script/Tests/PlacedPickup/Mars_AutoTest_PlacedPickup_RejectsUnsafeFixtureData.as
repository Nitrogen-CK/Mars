class UMars_AutoTest_PlacedPickup_RejectsUnsafeFixtureData : UCk_AutoTest_Base
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("validate explicit fixture data and world-axis witnesses", n"Step_Validate");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Validate(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Config = Cast<UMars_PlacedPickup_EntityScript>(NewObject(this, UMars_PlacedPickup_EntityScript));
        Config.FixtureId = n"PlacedPickup.Validation";
        Config.Definition = utils_held_item::Make_DefinitionSoft(mars_items::Ration());
        Config.SpawnTransform = FTransform(FRotator(0.0, 90.0, 0.0), FVector(100.0, 200.0, 300.0));
        Config.SupportHeightOffsetCm = -20.0;
        Config.SupportHalfExtentsCm = FVector2D(10.0, 30.0);
        Assert_True(Config.Get_Validation().IsValid(), "finite authored fixture validates");
        const auto Points = Config.Get_ExpectedWitnesses();
        Assert_Equals_Int(Points.Num(), 5, "centre and four corners");
        Assert_True(Points[0].Equals(FVector(100.0, 200.0, 280.0), 0.001), "support height uses world vertical");
        Assert_True(Points[1].Equals(FVector(90.0, 170.0, 280.0), 0.001), "world-axis footprint ignores item yaw");
        Config.SupportHalfExtentsCm.X = 0.0;
        Assert_False(Config.Get_Validation().IsValid(), "zero footprint rejected");
        Config.SupportHalfExtentsCm.X = 10.0;
        Config.SupportHeightOffsetCm = Math::Sqrt(-1.0);
        Assert_False(Config.Get_Validation().IsValid(), "nonfinite support plane rejected");
        Config.SupportHeightOffsetCm = -20.0;
        Config.ProbeHalfRangeCm = 0.0;
        Assert_False(Config.Get_Validation().IsValid(), "zero probe range rejected");
        Config.ProbeHalfRangeCm = 11.0;
        Assert_False(Config.Get_Validation().IsValid(), "unbounded probe range rejected");
        Config.ProbeHalfRangeCm = 5.0;
        Config.SupportToleranceCm = 2.01;
        Assert_False(Config.Get_Validation().IsValid(), "tolerance above two centimetres rejected");
        Config.SupportToleranceCm = 2.0;
        Config.SpawnTransform.SetScale3D(FVector(2.0, 1.0, 1.0));
        Assert_False(Config.Get_Validation().IsValid(), "scaled placement rejected");
        Config.SpawnTransform.SetScale3D(FVector::OneVector);
        Config.FixtureId = NAME_None;
        Assert_False(Config.Get_Validation().IsValid(), "anonymous fixture rejected");
        Config.FixtureId = n"PlacedPickup.Validation";
        Config.Definition = TSoftObjectPtr<UCk_InventoryItem_Definition>();
        Assert_False(Config.Get_Validation().IsValid(), "missing definition rejected");
        Assert_True(Config.Get_State() == EMars_PlacedPickup_State::Waiting, "validation alone never dispatches");
        Assert_False(ck::IsValid(Config.Get_SpawnedEntity()), "validation created no pending item");
    }
}
