// A leak 300 cm over an AMars_StillWater pool (water line at Z0 + 110, a floor below it) lands on the water: the
// down-trace (object type WorldStatic) hits the pool's query-only probe (Water_Mars_PhysMat, or its Mars.Water tag),
// so the strand's length is the 300 cm to the water line, its cards say Surface = Water, it gets one ring card on the
// water (Single Layer Water takes no DBuffer decals, so water rings are a translucent card) and no puddle. The probe
// ignores the trace channels: a Visibility trace through it (the camera, interaction traces) finds nothing between the
// leak and the floor.
class UMars_AutoTest_DripLeak_LandsOnStillWaterAsRingsOnly : UCk_AutoTest_Base
{
    default _TimeoutSeconds = 8.0f;
    default _AutoStageOriginField = false;

    private AMars_DripLeak _Leak;
    private AMars_StillWater _Water;
    private AStaticMeshActor _Floor;
    private FVector _Origin = FVector(14000.0, 4700.0, 5000.0);

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("spawn the floor and the pool", n"Step_SpawnPool");
        Add_Step_WaitFrames("let the bodies register", 2);
        Add_Step("spawn the leak", n"Step_SpawnLeak");
        Add_Step("the strand lands on the water", n"Step_Assert");
        Add_Step("cleanup", n"Step_Cleanup");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_SpawnPool(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Floor = utils_drip_test::Spawn_Slab(_Origin, FVector(400.0, 400.0, 20.0));
        _Water = Cast<AMars_StillWater>(SpawnActor(AMars_StillWater, _Origin + FVector(0.0, 0.0, 110.0), FRotator::ZeroRotator,
            NAME_None, true));
        if (ck::IsValid(_Water))
        {
            _Water.UseStaticMobility = false;
            _Water.Size = FVector2D(300.0, 300.0);
            FinishSpawningActor(_Water);
        }
    }

    UFUNCTION()
    private void Step_SpawnLeak(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Leak = utils_drip_test::Begin_Leak(_Origin + FVector(0.0, 0.0, 410.0));
        if (ck::IsValid(_Leak))
        { FinishSpawningActor(_Leak); }
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(ck::IsValid(_Leak) && ck::IsValid(_Water), "the rig spawned");
        if (ck::Is_NOT_Valid(_Leak) || ck::Is_NOT_Valid(_Water))
        { return; }

        Assert_Equals_Float(_Leak.Get_CardValue(0, EMars_DripCardData::Length), 300.0, 0.5, "the fall ends at the water line");
        Assert_Equals_Float(_Leak.Get_CardValue(0, EMars_DripCardData::Surface), float(int32(EMars_DripSurface::Water)), 1e-6,
            "the cards land on water (the phys mat)");
        Assert_Equals_Int(_Leak.WaterRings.GetInstanceCount(), 1, "one ring card on the water");
        Assert_Equals_Int(_Leak.Rings.GetInstanceCount(), 0, "no ring decal (Single Layer Water takes no decals)");
        Assert_True(_Leak.Get_RingValue(0, EMars_DripRingData::Seed) == _Leak.Get_CardValue(0, EMars_DripCardData::Seed),
            "the water ring carries the strand's seed");
        Assert_Equals_Int(_Leak.PuddleWet.GetInstanceCount(), 0, "no wet puddle on water");
        Assert_Equals_Int(_Leak.PuddleGloss.GetInstanceCount(), 0, "no gloss puddle on water");

        Assert_True(_Water.Probe.GetCollisionEnabled() == ECollisionEnabled::QueryOnly, "the probe is query-only");
        Assert_True(_Water.Probe.GetCollisionObjectType() == ECollisionChannel::ECC_WorldStatic, "the probe is WorldStatic");
        Assert_True(_Water.Probe.ComponentHasTag(n"Ck.Jolt.NoBake"), "the probe stays out of the Jolt bake");
        Assert_True(_Water.Surface.GetCollisionEnabled() == ECollisionEnabled::NoCollision, "the surface never collides");

        FHitResult Hit;
        TArray<AActor> Ignore;
        Ignore.Add(_Leak);
        const bool Blocked = System::LineTraceSingle(_Origin + FVector(0.0, 0.0, 300.0), _Origin + FVector(0.0, 0.0, 50.0),
            ETraceTypeQuery::Visibility, false, Ignore, EDrawDebugTrace::None, Hit, true);
        Assert_False(Blocked, "a Visibility trace passes through the water probe");
    }

    UFUNCTION()
    private void Step_Cleanup(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        utils_drip_test::Destroy(_Leak);
        utils_drip_test::Destroy(_Water);
        utils_drip_test::Destroy(_Floor);
    }
}
