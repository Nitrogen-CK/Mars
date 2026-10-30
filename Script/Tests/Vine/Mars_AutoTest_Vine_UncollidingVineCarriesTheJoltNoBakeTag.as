// By default a vine collides with nothing and stays out of the Jolt static bake: the actor and every emitted component
// carry Ck.Jolt.NoBake and the components use NoCollision. With Collision = On a root's spline segments are BlockAll and
// untagged (so CkJolt bakes them), the actor loses the tag, and its knots stay NoCollision and tagged.
class UMars_AutoTest_Vine_UncollidingVineCarriesTheJoltNoBakeTag : UMars_AutoTestRig_Vine
{
    default _Slot = 12;
    private AMars_Vine _Vine;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("the floor and the ceiling", n"Step_Room");
        Add_Step_WaitFrames("let the slab bodies register", 2);
        Add_Step("a root", n"Step_Vine");
        Add_Step("an uncolliding root is tagged out of the bake", n"Step_AssertOff");
        Add_Step("a colliding root bakes its segments", n"Step_AssertOn");
        Add_Step("cleanup", n"Step_Cleanup");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Room(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto O = Get_Origin();
        SpawnFloor(O, O.Z, FVector(1200.0, 1200.0, 50.0));
        SpawnCeiling(O, O.Z + 500.0, FVector(1200.0, 1200.0, 50.0));
    }

    UFUNCTION()
    private void Step_Vine(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Spawn = Make_Spawn(Make_Profile(EMars_VinePreset::GiantRoot), EMars_VineLayout::Drop, EMars_VineEnd::Ground);
        Spawn.Location = Get_Origin() + FVector(0.0, 0.0, 400.0);
        _Vine = SpawnVine(Spawn);
    }

    UFUNCTION()
    private void Step_AssertOff(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        if (ck::Is_NOT_Valid(_Vine))
        { return; }

        Assert_True(_Vine.Tags.Contains(utils_vine::JoltNoBakeTag), "the actor carries Ck.Jolt.NoBake");
        TArray<UPrimitiveComponent> Emitted;
        _Vine.Get_EmittedComponents(Emitted);
        Assert_True(Emitted.Num() > 0, f"the root emitted components ({_Vine.Status})");
        int32 Wrong = 0;
        for (auto Component : Emitted)
        {
            const auto Tagged = Component.ComponentTags.Contains(utils_vine::JoltNoBakeTag);
            const auto NoCollision = Component.GetCollisionProfileName() == collision::profile::NoCollision;
            if (Tagged == false || NoCollision == false)
            { ++Wrong; }
        }
        Assert_Equals_Int(Wrong, 0, "every emitted component is NoCollision and tagged");
    }

    UFUNCTION()
    private void Step_AssertOn(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        if (ck::Is_NOT_Valid(_Vine))
        { return; }

        _Vine.Collision = EMars_VineCollision::On;
        _Vine.Rebuild();
        Assert_False(_Vine.Tags.Contains(utils_vine::JoltNoBakeTag), "a colliding actor drops the tag");
        TArray<UPrimitiveComponent> Emitted;
        _Vine.Get_EmittedComponents(Emitted);
        int32 Segments = 0;
        int32 Wrong = 0;
        for (auto Component : Emitted)
        {
            const auto Tagged = Component.ComponentTags.Contains(utils_vine::JoltNoBakeTag);
            const auto Profile = Component.GetCollisionProfileName();
            if (ck::IsValid(Cast<USplineMeshComponent>(Component)))
            {
                ++Segments;
                if (Tagged || Profile != collision::profile::BlockAll)
                { ++Wrong; }
            }
            else if (Tagged == false || Profile != collision::profile::NoCollision)
            { ++Wrong; }
        }
        Assert_True(Segments > 0, "the root has segments");
        Assert_Equals_Int(Wrong, 0, "segments are BlockAll and untagged, the rest NoCollision and tagged");
    }
}
