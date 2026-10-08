// Two pieces shut in the drum gain coverage while the gripped lever rocks it (every reported step non-decreasing) and slide
// relative to the drum as it turns; held still the coverage does not move; let go, the return adds more. A piece added later
// starts at 0 and the others keep theirs. Rocked long enough, the first two reach exactly 1.0 and stay there.
class UMars_AutoTest_Tumbler_CoverageGrowsOnlyWithDrumTravelAndNeverFalls : UMars_AutoTestRig_Tumbler
{
    default _TimeoutSeconds = 50.0f;

    private const int32 k_LongRockCycles = 20;
    private const int32 k_RockHalfCycleFrames = 20;
    private const float32 k_StillTolerance = 0.0001f;

    private float32 _Orbit0BeforeRock = 0.0f;
    private float32 _Orbit1BeforeRock = 0.0f;
    private float32 _Coverage0Held = 0.0f;
    private float32 _Coverage1Held = 0.0f;
    private float32 _Coverage0BeforeRelease = 0.0f;
    private float32 _LastReturningCoverage = 0.0f;
    private bool _RoseWhileReturning = false;
    private float32 _Coverage0AtHome = 0.0f;
    private float32 _Coverage1AtHome = 0.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        BuildStation(InHandle, Make_TestSpec());

        Add_Step_WaitUntil("the station's nodes are posed", n"Check_NodesPosed", 0, 2.0f);
        Add_Steps_OpenHatch();
        Add_Step("load pieces 0 and 1", n"Step_AddTwo");
        Add_Step_WaitUntil("both are answered", n"Check_Answered2", 0, 1.0f);
        Add_Steps_CloseHatch();
        Add_Step("both are in, uncoated; remember their orbits", n"Step_SampleBeforeRock");
        Add_Steps_Grip();
        Add_Step_Rock("rock down for 60 frames", k_RockDegrees, 60);
        Add_Step_Rock("rock up for 40 frames", -k_RockDegrees, 40);
        Add_Step("both gained coverage and slid in the drum", n"Step_AssertRocked");
        Add_Step_Rock("rock down to the end of the arc", k_RockDegrees, 60);
        Add_Step_WaitSeconds("the lever settles against the end stop", 0.5f);
        Add_Step("remember the held coverage", n"Step_SampleHeld");
        Add_Step_WaitSeconds("hold the grip still", 1.0f);
        Add_Step("held still, the coverage did not move", n"Step_AssertHeld");
        Add_Step("let go", n"Step_ReleaseSampled");
        Add_Step_WaitUntil("the drum returns home", n"Check_HomeSampling", 0, 2.0f);
        Add_Step("the return added coverage", n"Step_AssertReturnCoated");
        Add_Steps_OpenHatch();
        Add_Step("load piece 2", n"Step_AddThird");
        Add_Step_WaitUntil("it is answered", n"Check_Answered3", 0, 1.0f);
        Add_Step("the new piece starts uncoated, the others keep theirs", n"Step_AssertThird");
        Add_Steps_CloseHatch();
        Add_Steps_Grip();
        for (int32 Cycle = 0; Cycle < k_LongRockCycles; ++Cycle)
        {
            Add_Step_Rock(f"long rock {Cycle + 1} down", k_RockDegrees, k_RockHalfCycleFrames);
            Add_Step_Rock(f"long rock {Cycle + 1} up", -k_RockDegrees, k_RockHalfCycleFrames);
        }

        Add_Step("the first two are fully coated", n"Step_AssertFull");
        Add_Step_Rock("rock on down", k_RockDegrees, k_RockHalfCycleFrames);
        Add_Step_Rock("rock on up", -k_RockDegrees, k_RockHalfCycleFrames);
        Add_Step("they stay fully coated and no coverage ever fell", n"Step_AssertStaysFull");
        Add_Step("let go", n"Step_Release");
        Add_Step_WaitUntil("the drum returns home", n"Check_DrumHome", 0, 2.0f);
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AddTwo(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        AddPiece(0);
        AddPiece(1);
    }

    UFUNCTION()
    private void Step_AddThird(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Coverage0AtHome = _Tumbler.Get_PieceCoverage(Make_Id(0));
        _Coverage1AtHome = _Tumbler.Get_PieceCoverage(Make_Id(1));
        AddPiece(2);
    }

    UFUNCTION()
    private void Check_Answered2(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Admissions.Num() >= 2);
    }

    UFUNCTION()
    private void Check_Answered3(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Admissions.Num() >= 3);
    }

    UFUNCTION()
    private void Step_SampleBeforeRock(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Tumbler.Get_PieceCount(), 2, "two pieces in the drum");
        Assert_Equals_Float(_Tumbler.Get_PieceCoverage(Make_Id(0)), 0.0, 0.0, "piece 0 starts uncoated");
        Assert_Equals_Float(_Tumbler.Get_PieceCoverage(Make_Id(1)), 0.0, 0.0, "piece 1 starts uncoated");
        _Orbit0BeforeRock = _Tumbler.Get_PieceOrbitDegrees(Make_Id(0));
        _Orbit1BeforeRock = _Tumbler.Get_PieceOrbitDegrees(Make_Id(1));
    }

    UFUNCTION()
    private void Step_AssertRocked(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Coverage0 = _Tumbler.Get_PieceCoverage(Make_Id(0));
        const auto Coverage1 = _Tumbler.Get_PieceCoverage(Make_Id(1));
        Assert_True(Coverage0 > 0.0f, f"piece 0 gained coverage ({Coverage0 :.4})");
        Assert_True(Coverage1 > 0.0f, f"piece 1 gained coverage ({Coverage1 :.4})");
        Assert_True(Get_IsMonotonic(Make_Id(0)), "every coverage step of piece 0 is non-decreasing");
        Assert_True(Get_IsMonotonic(Make_Id(1)), "every coverage step of piece 1 is non-decreasing");

        const auto Moved0 = Math::Abs(_Tumbler.Get_PieceOrbitDegrees(Make_Id(0)) - _Orbit0BeforeRock);
        const auto Moved1 = Math::Abs(_Tumbler.Get_PieceOrbitDegrees(Make_Id(1)) - _Orbit1BeforeRock);
        Assert_True(Moved0 > 1.0f, f"piece 0 slid relative to the drum ({Moved0 :.2} degrees)");
        Assert_True(Moved1 > 1.0f, f"piece 1 slid relative to the drum ({Moved1 :.2} degrees)");
    }

    UFUNCTION()
    private void Step_SampleHeld(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(Check_HandMode(EMars_Tumbler_HandMode::Gripped), "still gripped");
        _Coverage0Held = _Tumbler.Get_PieceCoverage(Make_Id(0));
        _Coverage1Held = _Tumbler.Get_PieceCoverage(Make_Id(1));
    }

    UFUNCTION()
    private void Step_AssertHeld(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Float(_Tumbler.Get_PieceCoverage(Make_Id(0)), _Coverage0Held, k_StillTolerance, "piece 0 held its coverage");
        Assert_Equals_Float(_Tumbler.Get_PieceCoverage(Make_Id(1)), _Coverage1Held, k_StillTolerance, "piece 1 held its coverage");
    }

    UFUNCTION()
    private void Step_ReleaseSampled(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Coverage0BeforeRelease = _Tumbler.Get_PieceCoverage(Make_Id(0));
        _LastReturningCoverage = _Coverage0BeforeRelease;
        Release();
    }

    // Watches piece 0's coverage while the drum returns.
    UFUNCTION()
    private void Check_HomeSampling(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Coverage = _Tumbler.Get_PieceCoverage(Make_Id(0));
        if (Check_Drum(EMars_Tumbler_Drum::Returning) && Coverage > _LastReturningCoverage)
        { _RoseWhileReturning = true; }

        _LastReturningCoverage = Coverage;
        auto Res = OutResult;
        Res.Set(Check_Drum(EMars_Tumbler_Drum::Home));
    }

    UFUNCTION()
    private void Step_AssertReturnCoated(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_RoseWhileReturning, "piece 0's coverage rose while the drum returned");
        const auto After = _Tumbler.Get_PieceCoverage(Make_Id(0));
        Assert_True(After > _Coverage0BeforeRelease, f"the return added coverage ({_Coverage0BeforeRelease :.4} -> {After :.4})");
    }

    UFUNCTION()
    private void Step_AssertThird(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Admissions.Last() == EMars_CookingFeed_Admission::Accepted, f"piece 2 is accepted (reason: {_AdmissionReasons.Last()})");
        Assert_Equals_Float(_Tumbler.Get_PieceCoverage(Make_Id(2)), 0.0, 0.0, "piece 2 starts uncoated");
        Assert_Equals_Float(_Tumbler.Get_PieceCoverage(Make_Id(0)), _Coverage0AtHome, 0.0, "piece 0 kept its coverage");
        Assert_Equals_Float(_Tumbler.Get_PieceCoverage(Make_Id(1)), _Coverage1AtHome, 0.0, "piece 1 kept its coverage");
    }

    UFUNCTION()
    private void Step_AssertFull(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Tumbler.Get_PieceCoverage(Make_Id(0)) == 1.0f, f"piece 0 is fully coated ({_Tumbler.Get_PieceCoverage(Make_Id(0)) :.6})");
        Assert_True(_Tumbler.Get_PieceCoverage(Make_Id(1)) == 1.0f, f"piece 1 is fully coated ({_Tumbler.Get_PieceCoverage(Make_Id(1)) :.6})");
    }

    UFUNCTION()
    private void Step_AssertStaysFull(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Tumbler.Get_PieceCoverage(Make_Id(0)) == 1.0f, "piece 0 stays fully coated");
        Assert_True(_Tumbler.Get_PieceCoverage(Make_Id(1)) == 1.0f, "piece 1 stays fully coated");
        for (int32 Slot = 0; Slot < 3; ++Slot)
        { Assert_True(Get_IsMonotonic(Make_Id(Slot)), f"no coverage of piece {Slot} ever fell or passed 1"); }
    }

    // Every OnCoverageChanged for InPieceId is at least the one before it and at most 1.
    private bool Get_IsMonotonic(const FMars_CookingFeed_PieceId& InPieceId) const
    {
        auto Last = 0.0f;
        for (int32 Index = 0; Index < _CoverageIds.Num(); ++Index)
        {
            if (_CoverageIds[Index].Get_IsSame(InPieceId) == false)
            { continue; }

            const auto Coverage = _Coverages[Index];
            if (Coverage < Last || Coverage > 1.0f)
            { return false; }

            Last = Coverage;
        }

        return true;
    }
}
