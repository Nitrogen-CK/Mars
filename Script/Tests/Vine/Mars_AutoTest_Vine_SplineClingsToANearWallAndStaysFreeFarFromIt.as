// An ivy Spline guide runs 20 cm off a wall face (inside half the 60 cm ClingRadius, so its samples cling fully), then
// 200 cm off it (beyond the radius). The near stretch lies at the stem's radius (0.6 - 1.2 cm) plus the 0.5 cm stand-off
// from the wall (+-3 cm); the far stretch, away from its corner and its end, is the guide itself (within 1 cm). The guide
// points are linear, so the guide is the polyline through them. The air end hangs below the guide and is not measured.
class UMars_AutoTest_Vine_SplineClingsToANearWallAndStaysFreeFarFromIt : UMars_AutoTestRig_Vine
{
    default _Slot = 2;
    private AMars_Vine _Vine;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("the wall and the floor", n"Step_Room");
        Add_Step_WaitFrames("let the slab bodies register", 2);
        Add_Step("an ivy along a guide", n"Step_Vine");
        Add_Step("near samples cling, far ones stay", n"Step_Assert");
        Add_Step("cleanup", n"Step_Cleanup");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Room(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto O = Get_Origin();
        // The wall face is at x = O.X + 25.
        SpawnSlab(O, FVector(0.5, 6.0, 6.0));
        SpawnFloor(O, O.Z - 300.0, FVector(1200.0, 1200.0, 50.0));
    }

    UFUNCTION()
    private void Step_Vine(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto O = Get_Origin();
        auto Vine = Cast<AMars_Vine>(SpawnActor(AMars_Vine, O + FVector(45.0, 0.0, 0.0), FRotator::ZeroRotator, NAME_None, true));
        if (ck::Is_NOT_Valid(Vine))
        {
            FinishFailure("the vine did not spawn");
            return;
        }
        Vine.Profile = Make_Profile(EMars_VinePreset::Ivy);
        Vine.Layout = EMars_VineLayout::Spline;
        Vine.End = EMars_VineEnd::Air;
        Vine.Seed = 11;
        Vine.Guide.ClearSplinePoints(false);
        Vine.Guide.AddSplinePoint(FVector(0.0, -200.0, 0.0), ESplineCoordinateSpace::Local, false);
        Vine.Guide.AddSplinePoint(FVector(0.0, 0.0, 0.0), ESplineCoordinateSpace::Local, false);
        Vine.Guide.AddSplinePoint(FVector(180.0, 100.0, 0.0), ESplineCoordinateSpace::Local, false);
        Vine.Guide.AddSplinePoint(FVector(180.0, 250.0, 0.0), ESplineCoordinateSpace::Local, false);
        // Linear points: the guide is the polyline itself, so "unchanged" is measured against straight runs.
        for (int32 Point = 0; Point < 4; ++Point)
        { Vine.Guide.SetSplinePointType(Point, ESplinePointType::Linear, false); }
        Vine.Guide.UpdateSpline();
        FinishSpawningActor(Vine);
        _Spawned.Add(Vine);
        _Vine = Vine;
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        if (ck::Is_NOT_Valid(_Vine))
        { return; }

        const auto O = Get_Origin();
        const auto Face = O.X + 25.0;
        const auto Stems = Get_WorldPaths(_Vine, EMars_VinePathKind::Stem);
        Assert_Equals_Int(Stems.Num(), 1, f"one stem ({_Vine.Status})");
        if (Stems.Num() != 1)
        { return; }

        int32 Near = 0;
        int32 Far = 0;
        for (int32 Index = 0; Index < Stems[0].Points.Num(); ++Index)
        {
            const auto P = Stems[0].Points[Index];
            if (Math::Abs(P.Z - O.Z) > 5.0)
            { continue; }

            const auto LocalY = P.Y - O.Y;
            if (LocalY > -180.0 && LocalY < -20.0)
            {
                ++Near;
                const auto Gap = P.X - Face;
                Assert_True(Gap >= 0.6 + 0.5 - 3.0 && Gap <= 1.2 + 0.5 + 3.0,
                    f"a near sample clings at the stand-off (gap {Gap :.2} cm at y {LocalY :.0})");
            }
            else if (LocalY > 180.0 && LocalY < 235.0)
            {
                ++Far;
                const auto Off = P.X - (O.X + 45.0 + 180.0);
                Assert_True(Math::Abs(Off) <= 1.0 && Math::Abs(P.Z - O.Z) <= 1.0,
                    f"a far sample keeps the guide (off {Off :.2} cm at y {LocalY :.0})");
            }
        }
        Assert_True(Near >= 5, f"near samples were measured ({Near})");
        Assert_True(Far >= 3, f"far samples were measured ({Far})");
    }
}
