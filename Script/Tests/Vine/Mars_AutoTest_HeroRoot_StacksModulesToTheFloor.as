// A hero root at the ceiling of an 1100 cm room, built from engine-cylinder stand-ins whose module heights are all
// 100 cm: it traces the floor, stacks round((1100 - 100 - 100) / 100) = 9 mid modules at zScale 1.0 and covers the room
// from its top (the ceiling contact) to the floor within 1 cm. Two roots with one seed flip their mids alike. The
// modules collide by default (BlockAll). A 230 cm height would stretch its single mid by 0.3, which Validate() rejects
// naming the height.
class UMars_AutoTest_HeroRoot_StacksModulesToTheFloor : UMars_AutoTestRig_Vine
{
    default _Slot = 13;
    private AMars_HeroRoot _A;
    private AMars_HeroRoot _B;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("the floor and the ceiling", n"Step_Room");
        Add_Step_WaitFrames("let the slab bodies register", 2);
        Add_Step("two hero roots with one seed", n"Step_Roots");
        Add_Step("the stack covers the room", n"Step_Assert");
        Add_Step("an impossible height is rejected", n"Step_AssertRejected");
        Add_Step("cleanup", n"Step_Cleanup");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Room(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto O = Get_Origin();
        SpawnFloor(O, O.Z, FVector(1200.0, 1200.0, 50.0));
        SpawnCeiling(O, O.Z + 1100.0, FVector(1200.0, 1200.0, 50.0));
    }

    private AMars_HeroRoot SpawnRoot(FVector InLocation)
    {
        auto Root = Cast<AMars_HeroRoot>(SpawnActor(AMars_HeroRoot, InLocation, FRotator::ZeroRotator, NAME_None, true));
        if (ck::Is_NOT_Valid(Root))
        {
            FinishFailure("the hero root did not spawn");
            return nullptr;
        }
        auto Cylinder = engine::load::Cylinder();
        Root.TopMesh = Cylinder;
        Root.MidMeshes.Add(Cylinder);
        Root.MidMeshes.Add(engine::load::Cube());
        Root.FlareMeshes.Add(Cylinder);
        Root.Heights.TopCm = 100.0f;
        Root.Heights.MidCm = 100.0f;
        Root.Heights.FlareCm = 100.0f;
        Root.Seed = 321;
        FinishSpawningActor(Root);
        _Spawned.Add(Root);
        return Root;
    }

    UFUNCTION()
    private void Step_Roots(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto O = Get_Origin();
        _A = SpawnRoot(O + FVector(-200.0, 0.0, 1100.0));
        _B = SpawnRoot(O + FVector(200.0, 0.0, 1100.0));
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        if (ck::Is_NOT_Valid(_A) || ck::Is_NOT_Valid(_B))
        { return; }

        const auto O = Get_Origin();
        const auto Stack = _A.Get_Stack();
        Assert_Equals_Int(Stack.Mids, 9, f"nine mid modules ({_A.Status})");
        Assert_Equals_Float(Stack.ZScale, 1.0, 0.001, "the mids keep their height");
        Assert_True(Stack.ZScale >= 0.8 && Stack.ZScale <= 1.25, "zScale stays in [0.8, 1.25]");
        const auto Coverage = _A.Get_CoverageZ();
        Assert_Equals_Float(Coverage.X, O.Z + 1100.0, 1.0, "the stack starts at the ceiling contact");
        Assert_Equals_Float(Coverage.Y, O.Z, 1.0, "the stack reaches the floor");

        const auto FlipsA = _A.Get_Flips();
        const auto FlipsB = _B.Get_Flips();
        bool Same = FlipsA.Num() == FlipsB.Num() && FlipsA.Num() == 9;
        for (int32 Index = 0; Same && Index < FlipsA.Num(); ++Index)
        { Same = FlipsA[Index] == FlipsB[Index]; }
        Assert_True(Same, "one seed flips the mids alike");

        int32 Hisms = 0;
        int32 Wrong = 0;
        for (auto Component : _A.GetComponentsByClass(UHierarchicalInstancedStaticMeshComponent))
        {
            auto Hism = Cast<UHierarchicalInstancedStaticMeshComponent>(Component);
            if (ck::Is_NOT_Valid(Hism))
            { continue; }
            ++Hisms;
            if (Hism.GetCollisionProfileName() != collision::profile::BlockAll)
            { ++Wrong; }
        }
        Assert_True(Hisms >= 2, f"one HISM per module mesh ({Hisms})");
        Assert_Equals_Int(Wrong, 0, "the modules collide by default");
    }

    UFUNCTION()
    private void Step_AssertRejected(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        FMars_HeroRoot_Heights Heights;
        Heights.TopCm = 100.0f;
        Heights.MidCm = 100.0f;
        Heights.FlareCm = 100.0f;
        const auto Stack = utils_vine::Plan_HeroStack(Heights, 230.0);
        const auto Result = Stack.Validate();
        Assert_False(Result.IsValid(), f"a 0.3 stretch is rejected (zScale {Stack.ZScale :.2})");
        Assert_True(Result.Get_Error().Contains("height"), f"the error names the height ({Result.Get_Error()})");
    }
}
