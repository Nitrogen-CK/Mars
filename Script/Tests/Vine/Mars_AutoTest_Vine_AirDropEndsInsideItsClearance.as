// A ThinRoot Drop with End = Air under a ceiling 1050 cm above the floor ends inside its clearance band: the lowest
// stem point is 40 - 180 cm (+-2) above the floor top (the curled tip is lengthened so the curl lands it there), and no
// point of any path is below the floor.
class UMars_AutoTest_Vine_AirDropEndsInsideItsClearance : UMars_AutoTestRig_Vine
{
    default _Slot = 1;
    private AMars_Vine _Vine;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("the floor and the ceiling", n"Step_Room");
        Add_Step_WaitFrames("let the slab bodies register", 2);
        Add_Step("an air thin root", n"Step_Vine");
        Add_Step("it stops inside the clearance band", n"Step_Assert");
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
        auto Spawn = Make_Spawn(Make_Profile(EMars_VinePreset::ThinRoot), EMars_VineLayout::Drop, EMars_VineEnd::Air);
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

        Assert_False(Stems[0].Grounded, "an air stem never reaches the floor");
        const auto Clearance = Get_LowestZ(Stems[0]) - FloorTop;
        Assert_True(Clearance >= 38.0 && Clearance <= 182.0, f"the tip stops 40 - 180 cm above the floor ({Clearance :.1} cm)");

        for (int32 Index = 0; Index < _Vine.Get_PathCount(); ++Index)
        {
            TArray<FVector> Points;
            _Vine.Get_PathPoints(Index, Points);
            for (auto Point : Points)
            {
                if (Point.Z < FloorTop - 1.0)
                {
                    Assert_True(false, f"path {Index} dips below the floor at {Point.ToString()}");
                    return;
                }
            }
        }
    }
}
