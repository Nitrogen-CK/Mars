// Drip dressing never collides and never feeds the CkJolt static-world bake: every primitive of a leak and of a
// puddle cluster is NoCollision, casts no shadow and carries the Ck.Jolt.NoBake component tag, and the leak, puddle
// and wet-streak actors carry the actor tag (a NoCollision component is not bake-eligible, the tag is in the default
// exclusion list), so adding, moving or regenerating drips never stales the cook hash.
class UMars_AutoTest_DripLeak_StaysOutOfTheJoltBake : UCk_AutoTest_Base
{
    default _TimeoutSeconds = 8.0f;
    default _AutoStageOriginField = false;

    private AMars_DripLeak _Leak;
    private AMars_Puddle _Puddle;
    private AMars_WetStreak _Streak;
    private AStaticMeshActor _Floor;
    private FVector _Origin = FVector(14000.0, 7100.0, 5000.0);

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("spawn the floor", n"Step_SpawnFloor");
        Add_Step_WaitFrames("let the floor body register", 2);
        Add_Step("spawn the dressing", n"Step_SpawnDressing");
        Add_Step("nothing collides or bakes", n"Step_Assert");
        Add_Step("cleanup", n"Step_Cleanup");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_SpawnFloor(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Floor = utils_drip_test::Spawn_Slab(_Origin, FVector(600.0, 600.0, 20.0));
    }

    UFUNCTION()
    private void Step_SpawnDressing(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Leak = utils_drip_test::Begin_Leak(_Origin + FVector(0.0, 0.0, 300.0));
        if (ck::IsValid(_Leak))
        { FinishSpawningActor(_Leak); }

        _Puddle = Cast<AMars_Puddle>(SpawnActor(AMars_Puddle, _Origin + FVector(150.0, 0.0, 30.0), FRotator::ZeroRotator, NAME_None, true));
        if (ck::IsValid(_Puddle))
        {
            _Puddle.UseStaticMobility = false;
            FinishSpawningActor(_Puddle);
        }

        _Streak = Cast<AMars_WetStreak>(SpawnActor(AMars_WetStreak, _Origin + FVector(-150.0, 0.0, 200.0)));
    }

    private void Assert_NoBake(UPrimitiveComponent InPrimitive, const FString& InName)
    {
        Assert_True(InPrimitive.GetCollisionEnabled() == ECollisionEnabled::NoCollision, f"{InName} has no collision");
        Assert_True(InPrimitive.ComponentHasTag(n"Ck.Jolt.NoBake"), f"{InName} carries Ck.Jolt.NoBake");
        Assert_False(InPrimitive.CastShadow, f"{InName} casts no shadow");
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(ck::IsValid(_Leak) && ck::IsValid(_Puddle) && ck::IsValid(_Streak), "the dressing spawned");
        if (ck::Is_NOT_Valid(_Leak) || ck::Is_NOT_Valid(_Puddle) || ck::Is_NOT_Valid(_Streak))
        { return; }

        Assert_True(_Leak.Drops.GetInstanceCount() > 0 && _Puddle.Get_PuddleCount() > 0, "there is something to check");
        Assert_NoBake(_Leak.Drops, "leak drops");
        Assert_NoBake(_Leak.Rings, "leak rings");
        Assert_NoBake(_Leak.WaterRings, "leak water rings");
        Assert_NoBake(_Leak.PuddleWet, "leak wet puddles");
        Assert_NoBake(_Leak.PuddleGloss, "leak gloss puddles");
        Assert_NoBake(_Puddle.PuddleWet, "puddle wet layer");
        Assert_NoBake(_Puddle.PuddleGloss, "puddle gloss layer");
        Assert_True(_Leak.ActorHasTag(n"Ck.Jolt.NoBake"), "the leak actor is tagged");
        Assert_True(_Puddle.ActorHasTag(n"Ck.Jolt.NoBake"), "the puddle actor is tagged");
        Assert_True(_Streak.ActorHasTag(n"Ck.Jolt.NoBake"), "the streak actor is tagged");
    }

    UFUNCTION()
    private void Step_Cleanup(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        utils_drip_test::Destroy(_Leak);
        utils_drip_test::Destroy(_Puddle);
        utils_drip_test::Destroy(_Streak);
        utils_drip_test::Destroy(_Floor);
    }
}
