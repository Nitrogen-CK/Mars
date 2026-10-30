// A ThinRoot Drop with End = Ground, hung from a ceiling 1050 cm above the floor: the stem reaches the floor (its
// lowest point sits no higher than its radius plus 2 cm above the floor top), fillets onto it and creeps along it
// within its CreepCm range (20 - 60 cm, plus the 15 cm fillet and 25 % slack), every floor point resting on the floor
// (centreline 0 .. R0 + 3 cm above it), and it forks into 2 - 3 floor fingers.
class UMars_AutoTest_Vine_GroundedDropReachesAndCreepsAlongTheFloor : UMars_AutoTestRig_Vine
{
    default _Slot = 0;
    private AMars_Vine _Vine;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("the floor and the ceiling", n"Step_Room");
        Add_Step_WaitFrames("let the slab bodies register", 2);
        Add_Step("a grounded thin root", n"Step_Vine");
        Add_Step("it reaches the floor and creeps along it", n"Step_Assert");
        Add_Step("cleanup", n"Step_Cleanup");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Room(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto O = Get_Origin();
        SpawnFloor(O, O.Z, FVector(1200.0, 1200.0, 50.0));
        SpawnCeiling(O, O.Z + 1050.0, FVector(1200.0, 1200.0, 50.0));
    }

    UFUNCTION()
    private void Step_Vine(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Spawn = Make_Spawn(Make_Profile(EMars_VinePreset::ThinRoot), EMars_VineLayout::Drop, EMars_VineEnd::Ground);
        Spawn.Location = Get_Origin() + FVector(0.0, 0.0, 900.0);
        _Vine = SpawnVine(Spawn);
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        if (ck::Is_NOT_Valid(_Vine))
        { return; }

        const auto FloorTop = Get_Origin().Z;
        const auto Stems = Get_WorldPaths(_Vine, EMars_VinePathKind::Stem);
        Assert_Equals_Int(Stems.Num(), 1, f"one stem ({_Vine.Status})");
        if (Stems.Num() != 1)
        { return; }

        const auto& Stem = Stems[0];
        Assert_True(Stem.Grounded, "the stem reached the floor");
        const auto Lowest = Get_LowestZ(Stem) - FloorTop;
        Assert_True(Lowest >= -1.0 && Lowest <= Stem.RadiusCm.X + 2.0,
            f"the lowest point rests on the floor ({Lowest :.1} cm above it, R0 {Stem.RadiusCm.X :.1})");

        int32 FloorPoints = 0;
        float Creep = 0.0;
        bool AllOnFloor = true;
        for (int32 Index = 0; Index < Stem.Points.Num(); ++Index)
        {
            if (Stem.Normals[Index].Z < 0.7)
            { continue; }
            const auto Height = Stem.Points[Index].Z - FloorTop;
            if (Height < -1.0 || Height > Stem.RadiusCm.X + 3.0)
            { AllOnFloor = false; }
            if (FloorPoints > 0)
            { Creep += Stem.Points[Index].Distance(Stem.Points[Index - 1]); }
            ++FloorPoints;
        }
        Assert_True(FloorPoints >= 2, f"the stem lies along the floor ({FloorPoints} floor points)");
        Assert_True(AllOnFloor, "every floor point rests on the floor");
        Assert_True(Creep >= 15.0 && Creep <= 95.0, f"the floor creep is within its range ({Creep :.1} cm)");

        int32 Fingers = 0;
        for (auto Finger : Get_WorldPaths(_Vine, EMars_VinePathKind::Finger))
        {
            if (Finger.Grounded)
            { ++Fingers; }
        }
        Assert_True(Fingers >= 2 && Fingers <= 3, f"2 - 3 floor fingers (got {Fingers})");
    }
}
