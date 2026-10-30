// A leak placed in mid-air under a ceiling slab (bottom face at Z0 + 290) with a floor below (top at Z0 + 10) hangs its
// strand 1 cm under the ceiling (AttachUp traces up and finds a downward-facing face) and the fall is measured from
// there: 289 - 10 = 279 cm.
class UMars_AutoTest_DripLeak_AttachesUpToTheCeiling : UCk_AutoTest_Base
{
    default _TimeoutSeconds = 8.0f;
    default _AutoStageOriginField = false;

    private AMars_DripLeak _Leak;
    private AStaticMeshActor _Floor;
    private AStaticMeshActor _Ceiling;
    private FVector _Origin = FVector(14000.0, 3900.0, 5000.0);

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("spawn the floor and the ceiling", n"Step_SpawnSlabs");
        Add_Step_WaitFrames("let the bodies register", 2);
        Add_Step("spawn the leak", n"Step_SpawnLeak");
        Add_Step("the strand hangs under the ceiling", n"Step_Assert");
        Add_Step("cleanup", n"Step_Cleanup");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_SpawnSlabs(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Floor = utils_drip_test::Spawn_Slab(_Origin, FVector(400.0, 400.0, 20.0));
        _Ceiling = utils_drip_test::Spawn_Slab(_Origin + FVector(0.0, 0.0, 300.0), FVector(400.0, 400.0, 20.0));
    }

    UFUNCTION()
    private void Step_SpawnLeak(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Leak = utils_drip_test::Begin_Leak(_Origin + FVector(0.0, 0.0, 150.0));
        if (ck::IsValid(_Leak))
        { FinishSpawningActor(_Leak); }
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(ck::IsValid(_Leak) && ck::IsValid(_Ceiling), "the rig spawned");
        if (ck::Is_NOT_Valid(_Leak) || _Leak.CachedStrands.Num() != 1)
        {
            Assert_True(false, "one strand traced");
            return;
        }

        const auto Strand = _Leak.CachedStrands[0];
        Assert_Equals_Float(Strand.Source.Z, _Origin.Z + 289.0, 0.5, "the source hangs 1 cm under the ceiling");
        Assert_Equals_Float(float(Strand.Length), 279.0, 0.5, "the fall runs from the ceiling to the floor");
        Assert_True(Strand.State == EMars_DripTraceState::Hit, "the strand landed");
        Assert_Equals_Float(_Leak.Get_CardValue(0, EMars_DripCardData::Length), 279.0, 0.5, "the cards carry that fall");
    }

    UFUNCTION()
    private void Step_Cleanup(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        utils_drip_test::Destroy(_Leak);
        utils_drip_test::Destroy(_Floor);
        utils_drip_test::Destroy(_Ceiling);
    }
}
