// A take-out the tray refuses goes back to the drum (Request_Readopt): the hand-off is never left ledger-less. Box 0 is
// admitted and tumbled past the spec's TakeOutCoverage (0.05 here). In one frame boxes 1-4 are loaded onto the empty
// four-place tray and a take-out onto it hands box 0 back; the tray is full, refuses it, and the drum readopts it: box 0 is
// in the drum again under its own id, its coverage seeded from the crumb the take-out wrote, the drum its holder, its body
// Dynamic. It never reached the tray.
class UMars_AutoTest_Tumbler_AReadoptPutsThePieceBackOnTheBooks : UMars_AutoTestRig_Tumbler
{
    default _TimeoutSeconds = 30.0f;

    private const float32 k_TakeOutCoverage = 0.05f;
    // The tray lies on a floor this far from the origin, clear of the drum.
    private const FVector k_TrayLocal = FVector(0.0, -300.0, 0.0);
    private const int32 k_RockHalfCycleFrames = 20;
    // The tray's places, filled by boxes 1..k_FillerCount.
    private const int32 k_FillerCount = 4;

    private FCk_Handle _TrayEntity;
    private int32 _RockedFrames = 0;
    private float32 _CoverageAtTakeOut = 0.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Spec = Make_TestSpec();
        Spec.Coating.TakeOutCoverage = k_TakeOutCoverage;
        BuildStation(InHandle, Spec);
        Build_Boxes(1 + k_FillerCount);
        _TrayEntity = _Fixture.Spawn_EmptyPlatter(InHandle, k_Origin + k_TrayLocal, mars_items::Platter());

        Add_Steps_StationReady();
        Add_Step_WaitUntil("the tray is constructed", n"Check_TrayReady", k_SlowPolls, 0);
        Add_Steps_OpenHatch();
        Add_Step("release box 0", n"Step_Admit");
        Add_Step_WaitUntil("it rests inside the shell", n"Check_AllAtRest", k_SlowPolls, 0);
        Add_Steps_CloseHatch();
        Add_Steps_Grip();
        Add_Step_WaitUntil("the lever rocks until the box is tumbled", n"Check_RockedUntilTumbled", k_SlowPolls, 0);
        Add_Step("let go", n"Step_Release");
        Add_Step_WaitUntil("the drum is home", n"Check_DrumHome", 0, 0);
        Add_Step("the tray fills and a take-out onto it hands box 0 back in the same frame", n"Step_FillTheTrayAndTakeOut");
        Add_Step_WaitUntil("the tray refused box 0 and the drum has it again", n"Check_Readopted", k_SlowPolls, 0);
        Add_Step("box 0 is back on the drum's books; never on the tray", n"Step_AssertReadopted");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_TrayReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Fixture.Get_IsPlatterReady(_TrayEntity, 0));
    }

    UFUNCTION()
    private void Step_Admit(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Admit(0);
    }

    // Looks k_RockDegrees down for k_RockHalfCycleFrames frames, then up as long, and so on, until the readout lists the box.
    UFUNCTION()
    private void Check_RockedUntilTumbled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        if (utils_cooking_feed::Get_Takeable(_StationEntity).Num() == 1)
        {
            Res.Set(true);
            return;
        }

        const auto Down = Math::IntegerDivisionTrunc(_RockedFrames, k_RockHalfCycleFrames) % 2 == 0;
        Look(FVector(0.0, float64(Down ? k_RockDegrees : -k_RockDegrees), 0.0));
        _RockedFrames += 1;
        Res.Set(false);
    }

    // The fillers queue ahead of the take-out's load on the tray's next drain, so the tray is full when box 0 arrives.
    UFUNCTION()
    private void Step_FillTheTrayAndTakeOut(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _CoverageAtTakeOut = _Tumbler.Get_PieceCoverage(Make_Id(0));
        Assert_True(_CoverageAtTakeOut >= k_TakeOutCoverage, f"box 0 is tumbled ({_CoverageAtTakeOut :.4})");

        auto Tray = _TrayEntity.As_Platter();
        for (int32 Index = 1; Index <= k_FillerCount; ++Index)
        { Tray.Request_Load(FMars_Request_Platter_Load(_Boxes[Index])); }

        auto Station = _StationEntity;
        utils_cooking_feed::Request_StationTakeOut(Station, FMars_Request_StationTakeOut(1, Tray));
    }

    UFUNCTION()
    private void Check_Readopted(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_TakenOut.Num() == 1 && _Tumbler.Get_HasPiece(Make_Id(0)));
    }

    UFUNCTION()
    private void Step_AssertReadopted(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Box = _Boxes[0];
        FCk_Handle BoxEntity = Box;
        const auto Tray = _TrayEntity.As_Platter();

        Assert_Equals_Int(Tray.Get_Capacity(), k_FillerCount, "the tray takes four");
        Assert_True(_TakenOut.Num() == 1 && _TakenOut[0] == Box, "the take-out handed box 0 back once");
        Assert_True(ck::Is_NOT_Valid(Box.TryGet_Platter()), "box 0 never reached the tray");

        Assert_Equals_Int(_Tumbler.Get_PieceCount(), 1, "the drum holds one piece");
        Assert_True(_Tumbler.Get_PieceHandle(Make_Id(0)) == Box, "box 0, under its own id");
        FCk_Handle TumblerEntity = _Tumbler;
        Assert_True(Box.TryGet_Holder() == TumblerEntity, "the drum holds box 0 again");

        // The take-out wrote the coverage as the crumb; the readopt seeds the coverage from it.
        const auto Crumb = Box.Get_CookState().Crumb;
        const auto Coverage = _Tumbler.Get_PieceCoverage(Make_Id(0));
        Assert_True(Crumb >= _CoverageAtTakeOut && Crumb <= 1.0f, f"the crumb is the coverage at the take-out ({_CoverageAtTakeOut :.4} at the press, {Crumb :.4} written)");
        Assert_True(Coverage >= Crumb && Coverage <= 1.0f, f"the coverage restarts from the crumb ({Crumb :.4}), never below it (got {Coverage :.4})");

        Assert_True(BoxEntity.Is_JoltBody() && utils_jolt_body::Get_MotionType(BoxEntity.As_JoltBody()) == ECk_MotionType::Dynamic,
            "its body is Dynamic again");
    }
}
