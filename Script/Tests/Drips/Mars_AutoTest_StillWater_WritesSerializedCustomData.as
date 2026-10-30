// A still-water pool writes its size, seed, murk and rain rate into the surface's serialized custom primitive data
// defaults (the run-time setter does not save; the materials read CPD 0..4), scales its 100 cm plane to the pool, and
// makes its probe a thin query-only WorldStatic box carrying Water_Mars_PhysMat and the Mars.Water tag at the water
// line.
class UMars_AutoTest_StillWater_WritesSerializedCustomData : UCk_AutoTest_Base
{
    default _TimeoutSeconds = 8.0f;
    default _AutoStageOriginField = false;

    private AMars_StillWater _Water;
    private FVector _Origin = FVector(14000.0, 9500.0, 5000.0);

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("spawn the pool", n"Step_Spawn");
        Add_Step("the pool writes its custom data", n"Step_Assert");
        Add_Step("cleanup", n"Step_Cleanup");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Spawn(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Water = Cast<AMars_StillWater>(SpawnActor(AMars_StillWater, _Origin, FRotator::ZeroRotator, NAME_None, true));
        if (ck::Is_NOT_Valid(_Water))
        { return; }

        _Water.UseStaticMobility = false;
        _Water.Size = FVector2D(420.0, 260.0);
        _Water.Seed = 9;
        _Water.Murk = 1.7f;
        _Water.RainRate = 0.5f;
        FinishSpawningActor(_Water);
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(ck::IsValid(_Water), "the pool spawned");
        if (ck::Is_NOT_Valid(_Water))
        { return; }

        Assert_Equals_Float(_Water.Get_SurfaceData(EMars_StillWaterData::SizeX), 420.0, 1e-3, "CPD 0 = SizeX");
        Assert_Equals_Float(_Water.Get_SurfaceData(EMars_StillWaterData::SizeY), 260.0, 1e-3, "CPD 1 = SizeY");
        Assert_Equals_Float(_Water.Get_SurfaceData(EMars_StillWaterData::Seed), utils_drip::Roll(9, 0, 12), 1e-5, "CPD 2 = the seed roll");
        Assert_Equals_Float(_Water.Get_SurfaceData(EMars_StillWaterData::Murk), 1.7, 1e-5, "CPD 3 = Murk");
        Assert_Equals_Float(_Water.Get_SurfaceData(EMars_StillWaterData::RainRate), 0.5, 1e-5, "CPD 4 = RainRate");

        const FVector Scale = _Water.Surface.GetRelativeScale3D();
        Assert_True(Math::Abs(Scale.X - 4.2) < 1e-4 && Math::Abs(Scale.Y - 2.6) < 1e-4, f"the plane spans the pool ({Scale.ToString()})");

        Assert_True(_Water.Probe.GetCollisionEnabled() == ECollisionEnabled::QueryOnly, "the probe is query-only");
        Assert_True(_Water.Probe.GetCollisionObjectType() == ECollisionChannel::ECC_WorldStatic, "the probe is WorldStatic");
        Assert_True(_Water.ActorHasTag(n"Mars.Water"), "the pool is tagged Mars.Water");
        UPhysicalMaterial Override = _Water.Probe.BodyInstance.PhysMaterialOverride;
        Assert_True(ck::IsValid(Override) && Override.GetName() == "Water_Mars_PhysMat", "the probe carries Water_Mars_PhysMat");
        const FVector Extent = _Water.Probe.GetScaledBoxExtent();
        Assert_True(Math::Abs(Extent.X - 210.0) < 1e-3 && Math::Abs(Extent.Y - 130.0) < 1e-3 && Extent.Z <= 1.0 + 1e-3,
            f"the probe is a thin box over the pool ({Extent.ToString()})");
    }

    UFUNCTION()
    private void Step_Cleanup(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        utils_drip_test::Destroy(_Water);
    }
}
