// A five-strand cluster leak 400 cm above a slab (top at Z0 + 10, nothing overhead) traces each strand down to the
// floor (1.01 s of fall): 30 drop cards (6 slots per strand, Slot 0..5), every card's custom data 0 = the 400 cm fall and Surface =
// Floor; one ring decal per strand whose custom data 0..4 equal that strand's cards bit for bit (the ring sync
// contract); one puddle per strand in each layer, 1.5 cm above the floor. A second Rebuild lays the same strands.
class UMars_AutoTest_DripLeak_TracesStrandsDownToTheFloor : UCk_AutoTest_Base
{
    default _TimeoutSeconds = 8.0f;
    default _AutoStageOriginField = false;

    private AMars_DripLeak _Leak;
    private AStaticMeshActor _Floor;
    private FVector _Origin = FVector(14000.0, 3100.0, 5000.0);

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("spawn the floor", n"Step_SpawnFloor");
        Add_Step_WaitFrames("let the floor body register", 2);
        Add_Step("spawn the leak", n"Step_SpawnLeak");
        Add_Step("strands land on the floor", n"Step_Assert");
        Add_Step("a second rebuild lays the same strands", n"Step_AssertIdempotent");
        Add_Step("cleanup", n"Step_Cleanup");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_SpawnFloor(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Floor = utils_drip_test::Spawn_Slab(_Origin, FVector(800.0, 800.0, 20.0));
    }

    UFUNCTION()
    private void Step_SpawnLeak(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Leak = utils_drip_test::Begin_Leak(_Origin + FVector(0.0, 0.0, 410.0));
        if (ck::Is_NOT_Valid(_Leak))
        { return; }

        _Leak.Layout = EMars_DripLayout::Cluster;
        _Leak.Count = 5;
        _Leak.Radius = 100.0f;
        _Leak.Look.Mode = EMars_DripMode::Drops;
        _Leak.Impact.Puddles = true;
        FinishSpawningActor(_Leak);
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(ck::IsValid(_Floor) && ck::IsValid(_Leak), "the rig spawned");
        if (ck::Is_NOT_Valid(_Leak))
        { return; }

        Assert_Equals_Int(_Leak.Drops.GetInstanceCount(), 30, "six drop cards per strand");
        Assert_Equals_Int(_Leak.Rings.GetInstanceCount(), 5, "one ring decal per strand");
        Assert_Equals_Int(_Leak.PuddleWet.GetInstanceCount(), 5, "one wet puddle per strand");
        Assert_Equals_Int(_Leak.PuddleGloss.GetInstanceCount(), 5, "one gloss puddle per strand");

        for (int32 Strand = 0; Strand < 5; ++Strand)
        {
            for (int32 Slot = 0; Slot < 6; ++Slot)
            {
                const int32 Card = Strand * 6 + Slot;
                Assert_Equals_Float(_Leak.Get_CardValue(Card, EMars_DripCardData::Slot), float(Slot), 1e-6, f"card {Card} slot");
                Assert_Equals_Float(_Leak.Get_CardValue(Card, EMars_DripCardData::Length), 400.0, 0.5, f"card {Card} falls 400 cm");
                Assert_Equals_Float(_Leak.Get_CardValue(Card, EMars_DripCardData::Surface), 0.0, 1e-6, f"card {Card} lands on a floor");
            }

            int32 Mismatches = 0;
            for (int32 Value = 0; Value < int32(EMars_DripRingData::RingAmp); ++Value)
            {
                if (_Leak.Get_RingValue(Strand, EMars_DripRingData(Value)) != _Leak.Get_CardValue(Strand * 6, EMars_DripCardData(Value)))
                { Mismatches += 1; }
            }
            Assert_Equals_Int(Mismatches, 0, f"ring {Strand} carries its strand's five sync floats bit for bit");

            FTransform Puddle;
            _Leak.PuddleWet.GetInstanceTransform(Strand, Puddle, true);
            Assert_Equals_Float(Puddle.GetLocation().Z, _Origin.Z + 10.0 + 1.5, 0.05, f"puddle {Strand} hovers 1.5 cm over the floor");

            FTransform Card;
            _Leak.Drops.GetInstanceTransform(Strand * 6, Card, true);
            Assert_Equals_Float(Card.GetLocation().Z, _Origin.Z + 10.0, 0.05, f"strand {Strand}'s cards sit at the impact");
        }

        Assert_Equals_Int(_Leak.CachedStrands.Num(), 5, "five strands cached");
        Assert_True(_Leak.EffectiveRate > 0.0f && _Leak.FallSeconds > 0.95f && _Leak.FallSeconds < 1.05f,
            f"the readouts show the clock (rate {_Leak.EffectiveRate}, fall {_Leak.FallSeconds} s)");
    }

    UFUNCTION()
    private void Step_AssertIdempotent(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        if (ck::Is_NOT_Valid(_Leak))
        { return; }

        const float Seed = _Leak.Get_CardValue(7, EMars_DripCardData::Seed);
        const float Rate = _Leak.Get_CardValue(7, EMars_DripCardData::Rate);
        _Leak.Rebuild();
        Assert_Equals_Int(_Leak.Drops.GetInstanceCount(), 30, "rebuilding clears the previous cards first");
        Assert_Equals_Int(_Leak.Rings.GetInstanceCount(), 5, "and the rings");
        Assert_True(_Leak.Get_CardValue(7, EMars_DripCardData::Seed) == Seed && _Leak.Get_CardValue(7, EMars_DripCardData::Rate) == Rate,
            "the same seed lays the same strands");
    }

    UFUNCTION()
    private void Step_Cleanup(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        utils_drip_test::Destroy(_Leak);
        utils_drip_test::Destroy(_Floor);
    }
}
