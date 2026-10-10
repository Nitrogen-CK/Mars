// A tumbled piece taken out carries its crumb. Box 0 is admitted, the hatch shut and the gripped lever rocked until its
// coverage reaches the spec's TakeOutCoverage (0.05 here): the station's take-out readout lists it. A take-out with no tray
// is refused NoRoom and the drum keeps it. A take-out onto an empty platter hands it back (OnPieceTakenOut names the box)
// and it lands on the platter: its cook state's Crumb is its coverage (above 0), the platter is its holder, its body is
// Kinematic and the drum holds nothing.
class UMars_AutoTest_Tumbler_ATakeOutWritesCrumb : UMars_AutoTestRig_Tumbler
{
    default _TimeoutSeconds = 30.0f;

    private const float32 k_TakeOutCoverage = 0.05f;
    // The platter lies on a floor this far from the origin, clear of the drum.
    private const FVector k_PlatterLocal = FVector(0.0, -300.0, 0.0);
    private const int32 k_RockHalfCycleFrames = 20;

    private FCk_Handle _PlatterEntity;
    private int32 _RockedFrames = 0;
    private float32 _CoverageAtTakeOut = 0.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Spec = Make_TestSpec();
        Spec.Coating.TakeOutCoverage = k_TakeOutCoverage;
        BuildStation(InHandle, Spec);
        Build_Boxes(1);
        _PlatterEntity = _Fixture.Spawn_EmptyPlatter(InHandle, k_Origin + k_PlatterLocal, mars_items::Platter());

        Add_Steps_StationReady();
        Add_Step_WaitUntil("the platter is constructed", n"Check_PlatterReady", k_SlowPolls, 0);
        Add_Steps_OpenHatch();
        Add_Step("release box 0", n"Step_Admit");
        Add_Step_WaitUntil("it rests inside the shell", n"Check_AllAtRest", k_SlowPolls, 0);
        Add_Steps_CloseHatch();
        Add_Steps_Grip();
        Add_Step_WaitUntil("the lever rocks until the box is tumbled", n"Check_RockedUntilTumbled", k_SlowPolls, 0);
        Add_Step("let go", n"Step_Release");
        Add_Step_WaitUntil("the drum is home", n"Check_DrumHome", 0, 0);
        Add_Step("a take-out with no tray", n"Step_TakeOutNoTray");
        Add_Step_WaitUntil("it is refused", n"Check_Refused", 0, 0);
        Add_Step("refused NoRoom, the drum keeps the box", n"Step_AssertKept");
        Add_Step("a take-out onto the platter", n"Step_TakeOut");
        Add_Step_WaitUntil("the box landed on the platter", n"Check_OnPlatter", k_SlowPolls, 0);
        Add_Step("the box carries its crumb", n"Step_AssertCrumb");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_PlatterReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Fixture.Get_IsPlatterReady(_PlatterEntity, 0));
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

    UFUNCTION()
    private void Step_TakeOutNoTray(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Station = _StationEntity;
        utils_cooking_feed::Request_StationTakeOut(Station, FMars_Request_StationTakeOut(1, FCk_Handle_Platter()));
    }

    UFUNCTION()
    private void Check_Refused(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_TakeOutRefusals.Num() >= 1);
    }

    UFUNCTION()
    private void Step_AssertKept(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_TakeOutRefusals[0] == EMars_CookingFeed_TakeOutRefusal::NoRoom, f"refused NoRoom (got {_TakeOutRefusals[0] :n})");
        Assert_Equals_Int(_TakenOut.Num(), 0, "nothing handed back");
        Assert_True(_Tumbler.Get_HasPiece(Make_Id(0)), "the drum keeps the box");
        Assert_True(_Tumbler.Get_PieceCoverage(Make_Id(0)) >= k_TakeOutCoverage, "it is tumbled");
    }

    UFUNCTION()
    private void Step_TakeOut(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _CoverageAtTakeOut = _Tumbler.Get_PieceCoverage(Make_Id(0));
        auto Station = _StationEntity;
        utils_cooking_feed::Request_StationTakeOut(Station, FMars_Request_StationTakeOut(1, _PlatterEntity.As_Platter()));
    }

    UFUNCTION()
    private void Check_OnPlatter(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_PlatterEntity.As_Platter().Get_HeldCount() == 1);
    }

    UFUNCTION()
    private void Step_AssertCrumb(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Box = _Boxes[0];
        FCk_Handle BoxEntity = Box;
        Assert_True(_TakenOut.Num() == 1 && _TakenOut[0] == Box, "OnPieceTakenOut named the box once");
        Assert_False(_Tumbler.Get_HasPiece(Make_Id(0)), "the drum holds nothing");
        Assert_Equals_Int(_Tumbler.Get_PieceCount(), 0, "the drum is empty");

        // The press is sampled a frame before the drain that hands the box back, and the hatch is shut: the crumb is the
        // coverage at the press or a little more.
        const auto Crumb = Box.Get_CookState().Crumb;
        Log(f"[Mars_AutoTest_Tumbler_ATakeOutWritesCrumb] coverage at the press {_CoverageAtTakeOut :.4}, crumb {Crumb :.4}");
        Assert_True(Crumb > 0.0f, f"the crumb is written ({Crumb :.4})");
        Assert_True(Crumb >= _CoverageAtTakeOut && Crumb <= 1.0f, f"the crumb is the box's coverage ({_CoverageAtTakeOut :.4} at the press, {Crumb :.4} written)");
        Assert_True(Box.TryGet_Platter() == _PlatterEntity.As_Platter(), "the box is on the platter");
        Assert_True(Box.TryGet_Holder() == _PlatterEntity, "the platter holds the box");
        Assert_True(BoxEntity.Is_JoltBody() && utils_jolt_body::Get_MotionType(BoxEntity.As_JoltBody()) == ECk_MotionType::Kinematic, "its body is Kinematic");
    }
}
