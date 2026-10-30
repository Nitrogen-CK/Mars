// A HangingMoss Patch of radius 90 cm under a ceiling 600 cm above the floor hangs about density x area strands
// (6 / m2 x pi x 0.9 m^2 = 15, +-30 %), each card's top 2 cm inside the underside (within 3 cm of it) and none longer
// than the floor distance less the 40 cm minimum clearance.
class UMars_AutoTest_Vine_PatchHangsStrandsFromTheUnderside : UMars_AutoTestRig_Vine
{
    default _Slot = 9;
    private AMars_Vine _Vine;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("a ceiling over a floor", n"Step_Room");
        Add_Step_WaitFrames("let the slab bodies register", 2);
        Add_Step("a moss patch", n"Step_Vine");
        Add_Step("the strands hang from the underside", n"Step_Assert");
        Add_Step("cleanup", n"Step_Cleanup");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Room(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto O = Get_Origin();
        SpawnCeiling(O, O.Z + 400.0, FVector(800.0, 800.0, 50.0));
        SpawnFloor(O, O.Z - 200.0, FVector(800.0, 800.0, 50.0));
    }

    UFUNCTION()
    private void Step_Vine(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Spawn = Make_Spawn(Make_Profile(EMars_VinePreset::HangingMoss), EMars_VineLayout::Patch, EMars_VineEnd::Air);
        Spawn.Shape.PatchRadiusCm = 90.0f;
        _Vine = SpawnVine(Spawn);
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        if (ck::Is_NOT_Valid(_Vine))
        { return; }

        const auto O = Get_Origin();
        const auto Underside = O.Z + 400.0;
        const auto FloorTop = O.Z - 200.0;
        int32 Count = 0;
        for (auto Strand : Get_WorldPaths(_Vine, EMars_VinePathKind::Strand))
        {
            if (Strand.Group < 0 || Strand.Points.Num() < 2)
            { continue; }
            ++Count;
            const auto TopGap = Strand.Points[0].Z - Underside;
            Assert_True(TopGap >= -1.0 && TopGap <= 3.0, f"a strand top sits in the underside ({TopGap :.1} cm)");
            const auto Clearance = Strand.Points[1].Z - FloorTop;
            Assert_True(Clearance >= 39.0, f"a strand stops above the clearance ({Clearance :.1} cm)");
        }
        Assert_True(Count >= 10 && Count <= 20, f"density x area strands ({Count}, expected 15)");
        Assert_Equals_Int(_Vine.Get_Report().Cards, Count, "one card per strand");
    }
}
