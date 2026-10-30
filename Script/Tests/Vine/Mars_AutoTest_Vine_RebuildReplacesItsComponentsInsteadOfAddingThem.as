// An ivy drop (instanced chords and leaves) and a GiantRoot (spline segments and knots) each rebuilt in place: the
// emitted component count and the HISM instance count are the same before and after a second Rebuild(), because the
// tagged components of the last build are destroyed first.
class UMars_AutoTest_Vine_RebuildReplacesItsComponentsInsteadOfAddingThem : UMars_AutoTestRig_Vine
{
    default _Slot = 5;
    private AMars_Vine _Ivy;
    private AMars_Vine _Root;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("the floor and the ceiling", n"Step_Room");
        Add_Step_WaitFrames("let the slab bodies register", 2);
        Add_Step("an ivy and a root", n"Step_Vines");
        Add_Step("a rebuild replaces their components", n"Step_Assert");
        Add_Step("cleanup", n"Step_Cleanup");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Room(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto O = Get_Origin();
        SpawnFloor(O, O.Z, FVector(1600.0, 1600.0, 50.0));
        SpawnCeiling(O, O.Z + 500.0, FVector(1600.0, 1600.0, 50.0));
    }

    UFUNCTION()
    private void Step_Vines(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Spawn = Make_Spawn(Make_Profile(EMars_VinePreset::Ivy), EMars_VineLayout::Drop, EMars_VineEnd::Ground);
        Spawn.Location = Get_Origin() + FVector(-300.0, 0.0, 400.0);
        _Ivy = SpawnVine(Spawn);
        Spawn = Make_Spawn(Make_Profile(EMars_VinePreset::GiantRoot), EMars_VineLayout::Drop, EMars_VineEnd::Ground);
        Spawn.Location = Get_Origin() + FVector(300.0, 0.0, 400.0);
        _Root = SpawnVine(Spawn);
    }

    private void Assert_Idempotent(AMars_Vine InVine, const FString& InName)
    {
        if (ck::Is_NOT_Valid(InVine))
        { return; }

        TArray<UPrimitiveComponent> Before;
        InVine.Get_EmittedComponents(Before);
        const auto InstancesBefore = Get_InstanceCount(InVine);
        Assert_True(Before.Num() > 0, f"the {InName} emitted components ({InVine.Status})");
        InVine.Rebuild();
        TArray<UPrimitiveComponent> After;
        InVine.Get_EmittedComponents(After);
        Assert_Equals_Int(After.Num(), Before.Num(), f"the {InName} rebuild keeps its component count");
        Assert_Equals_Int(Get_InstanceCount(InVine), InstancesBefore, f"the {InName} rebuild keeps its instance count");
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Idempotent(_Ivy, "ivy");
        Assert_True(ck::IsValid(_Ivy) && Get_InstanceCount(_Ivy) > 0, "the ivy laid chord and leaf instances");
        Assert_Idempotent(_Root, "root");
    }
}
