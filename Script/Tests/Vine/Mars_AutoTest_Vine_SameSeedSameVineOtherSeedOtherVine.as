// Two GiantRoot drops with the same seed and transform solve and emit the same root: the same paths point for point,
// the same segment count and the same knot instances. A third with another seed solves a different root (its main
// stem ends more than 5 cm from the first one's, or it has a different number of paths).
class UMars_AutoTest_Vine_SameSeedSameVineOtherSeedOtherVine : UMars_AutoTestRig_Vine
{
    default _Slot = 3;
    private AMars_Vine _A;
    private AMars_Vine _B;
    private AMars_Vine _C;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("the floor and the ceiling", n"Step_Room");
        Add_Step_WaitFrames("let the slab bodies register", 2);
        Add_Step("two roots with one seed, one with another", n"Step_Vines");
        Add_Step("one seed one root, another seed another root", n"Step_Assert");
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
    private void Step_Vines(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Spawn = Make_Spawn(Make_Profile(EMars_VinePreset::GiantRoot), EMars_VineLayout::Drop, EMars_VineEnd::Ground);
        Spawn.Location = Get_Origin() + FVector(0.0, 0.0, 900.0);
        Spawn.Seed = 1234;
        _A = SpawnVine(Spawn);
        _B = SpawnVine(Spawn);
        Spawn.Seed = 98765;
        _C = SpawnVine(Spawn);
    }

    private TArray<FTransform> Get_Instances(AMars_Vine InVine)
    {
        TArray<FTransform> Out;
        TArray<UPrimitiveComponent> Emitted;
        InVine.Get_EmittedComponents(Emitted);
        for (auto Component : Emitted)
        {
            auto Hism = Cast<UHierarchicalInstancedStaticMeshComponent>(Component);
            if (ck::Is_NOT_Valid(Hism))
            { continue; }
            for (int32 Index = 0; Index < Hism.GetInstanceCount(); ++Index)
            {
                FTransform T;
                Hism.GetInstanceTransform(Index, T, false);
                Out.Add(T);
            }
        }
        return Out;
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        if (ck::Is_NOT_Valid(_A) || ck::Is_NOT_Valid(_B) || ck::Is_NOT_Valid(_C))
        { return; }

        Assert_True(_A.Get_PathCount() > 0, f"the root solved ({_A.Status})");
        Assert_Equals_Int(_B.Get_PathCount(), _A.Get_PathCount(), "the same seed lays the same number of paths");
        Assert_Equals_Int(_B.Get_Report().Segments, _A.Get_Report().Segments, "the same seed lays the same segments");

        float Worst = 0.0;
        for (int32 Path = 0; Path < Math::Min(_A.Get_PathCount(), _B.Get_PathCount()); ++Path)
        {
            TArray<FVector> PA;
            TArray<FVector> PB;
            _A.Get_PathPoints(Path, PA);
            _B.Get_PathPoints(Path, PB);
            if (PA.Num() != PB.Num())
            {
                Worst = 1.0e6;
                break;
            }
            for (int32 Index = 0; Index < PA.Num(); ++Index)
            { Worst = Math::Max(Worst, PA[Index].Distance(PB[Index])); }
        }
        Assert_True(Worst < 0.01, f"the same seed lays the same points (worst gap {Worst :.3} cm)");

        const auto IA = Get_Instances(_A);
        const auto IB = Get_Instances(_B);
        Assert_Equals_Int(IB.Num(), IA.Num(), "the same seed places the same instances");
        bool Same = IA.Num() == IB.Num();
        for (int32 Index = 0; Same && Index < IA.Num(); ++Index)
        { Same = IA[Index].GetLocation().Distance(IB[Index].GetLocation()) < 0.01; }
        Assert_True(Same, "the instances sit at the same places");

        TArray<FVector> MainA;
        TArray<FVector> MainC;
        int32 StemA = -1;
        int32 StemC = -1;
        for (int32 Path = 0; Path < _A.Get_PathCount(); ++Path)
        {
            FMars_Vine_Path P;
            _A.Get_Path(Path, P);
            if (P.Kind == EMars_VinePathKind::Stem && StemA < 0)
            { StemA = Path; }
        }
        for (int32 Path = 0; Path < _C.Get_PathCount(); ++Path)
        {
            FMars_Vine_Path P;
            _C.Get_Path(Path, P);
            if (P.Kind == EMars_VinePathKind::Stem && StemC < 0)
            { StemC = Path; }
        }
        _A.Get_PathPoints(StemA, MainA);
        _C.Get_PathPoints(StemC, MainC);
        const auto Differs = _C.Get_PathCount() != _A.Get_PathCount() || MainA.Num() == 0 || MainC.Num() == 0
            || MainA.Last().Distance(MainC.Last()) > 5.0;
        Assert_True(Differs, "another seed lays another root");
    }
}
