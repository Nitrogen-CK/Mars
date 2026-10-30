// A GiantRoot solved once reuses its cached solve: a second Rebuild() traces nothing and lays the same root, and so
// does one after the floor and the ceiling are gone (the cache never silently re-solves against a changed room). Only
// Reattach traces again.
class UMars_AutoTest_Vine_UnchangedInputsReuseTheSolveWithoutTracing : UMars_AutoTestRig_Vine
{
    default _Slot = 4;
    private AMars_Vine _Vine;
    private TArray<FVector> _First;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("the floor and the ceiling", n"Step_Room");
        Add_Step_WaitFrames("let the slab bodies register", 2);
        Add_Step("a root", n"Step_Vine");
        Add_Step("a rebuild reuses the solve", n"Step_RebuildCached");
        Add_Step("the room goes and the root stays", n"Step_RoomGone");
        Add_Step_WaitFrames("let the slab bodies leave", 2);
        Add_Step("a rebuild still reuses the solve", n"Step_RebuildWithoutRoom");
        Add_Step("Reattach traces again", n"Step_Reattach");
        Add_Step("cleanup", n"Step_Cleanup");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Room(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto O = Get_Origin();
        SpawnFloor(O, O.Z, FVector(1600.0, 1600.0, 50.0));
        SpawnCeiling(O, O.Z + 1050.0, FVector(1600.0, 1600.0, 50.0));
    }

    UFUNCTION()
    private void Step_Vine(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Spawn = Make_Spawn(Make_Profile(EMars_VinePreset::GiantRoot), EMars_VineLayout::Drop, EMars_VineEnd::Ground);
        Spawn.Location = Get_Origin() + FVector(0.0, 0.0, 900.0);
        _Vine = SpawnVine(Spawn);
        if (ck::IsValid(_Vine))
        {
            Assert_True(_Vine.Get_Report().Traces > 0 && _Vine.Get_Report().Cached == false, f"the first build solves ({_Vine.Status})");
            _Vine.Get_PathPoints(0, _First);
        }
    }

    private void Assert_SameRoot(const FString& InWhen)
    {
        TArray<FVector> Now;
        _Vine.Get_PathPoints(0, Now);
        bool Same = Now.Num() == _First.Num() && Now.Num() > 0;
        for (int32 Index = 0; Same && Index < Now.Num(); ++Index)
        { Same = Now[Index].Distance(_First[Index]) < 0.01; }
        Assert_True(Same, f"{InWhen}: the same root is laid");
    }

    UFUNCTION()
    private void Step_RebuildCached(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        if (ck::Is_NOT_Valid(_Vine))
        { return; }
        _Vine.Rebuild();
        Assert_True(_Vine.Get_Report().Cached, f"the rebuild reuses the solve ({_Vine.Status})");
        Assert_Equals_Int(_Vine.Get_Report().Traces, 0, "the rebuild traces nothing");
        Assert_SameRoot("after a rebuild");
    }

    UFUNCTION()
    private void Step_RoomGone(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        for (auto Actor : _Spawned)
        {
            if (ck::IsValid(Actor) && Actor != _Vine)
            { Actor.DestroyActor(); }
        }
    }

    UFUNCTION()
    private void Step_RebuildWithoutRoom(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        if (ck::Is_NOT_Valid(_Vine))
        { return; }
        _Vine.Rebuild();
        Assert_Equals_Int(_Vine.Get_Report().Traces, 0, "without the room the rebuild still traces nothing");
        Assert_SameRoot("without the room");
    }

    UFUNCTION()
    private void Step_Reattach(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        if (ck::Is_NOT_Valid(_Vine))
        { return; }
        _Vine.Reattach();
        Assert_True(_Vine.Get_Report().Traces > 0 && _Vine.Get_Report().Cached == false, f"Reattach re-solves ({_Vine.Status})");
    }
}
