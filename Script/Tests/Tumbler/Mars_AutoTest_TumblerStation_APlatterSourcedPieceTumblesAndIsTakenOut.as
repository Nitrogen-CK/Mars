// A piece sourced from a docked platter tumbles in the real tumbler station and the operator's take-out key puts it on the
// tray. A box loaded onto the large raw platter (its body from the platter's drop) and an empty small tray dock on the
// station; the operator rig's carrier takes the station through its Use interaction. Every look and every hatch or lever
// press is the carrier's own (look deltas on its intents, its Use key), read by the station's input task. The hatch is
// opened (a Use press on the hovered tab), and one add-food key press carries the box into the drum: while the feed carries
// it the hatch and the lever refuse the operator, and the drum adopts the box itself. The hatch is shut, the gripped lever
// rocked by the look until the box's coverage reaches the spec's TakeOutCoverage (0.1 here, at a hundredth per cm) and let
// go by releasing Use; the take-out key hands the box back onto the docked tray, its cook state's Crumb above 0 and the drum empty. Isolated origin (188000,
// -70000, -30000).
class UMars_AutoTest_TumblerStation_APlatterSourcedPieceTumblesAndIsTakenOut : UMars_AutoTestRig_Operator
{
    default _TimeoutSeconds = 60.0f;

    private const FVector k_StationOrigin = FVector(188000.0, -70000.0, -30000.0);
    // Behind the stand, facing the counter.
    private const FVector k_CarrierLocal = FVector(-115.0, 0.0, 0.0);
    private const FVector k_RawOffset = FVector(0.0, -300.0, 0.0);
    private const FVector k_TrayOffset = FVector(0.0, 300.0, 0.0);
    // A poll budget, not a ceiling: platters construct and settle, a transfer carries and the drum rocks.
    private const int32 k_SlowPolls = 900;
    private const float32 k_CoveragePerCm = 1.0f / 100.0f;
    private const float32 k_TakeOutCoverage = 0.1f;
    // Degrees of look pitch per rocking frame (down is +), alternating every k_RockHalfCycleFrames frames.
    private const float32 k_RockDegrees = 4.0f;
    private const int32 k_RockHalfCycleFrames = 20;

    private UMars_AutoTestHelper_HeatStation _Fixture;
    private FCk_Handle_Tumbler _Tumbler;
    private FCk_Handle_CookingFeed _Feed;
    private FCk_Handle_PlatterDock _InputDock;
    private FCk_Handle_PlatterDock _OutputDock;
    private FCk_Handle _Raw;
    private FCk_Handle _Tray;
    private FCk_Handle_FoodPiece _Box;
    private TArray<FCk_Handle_FoodPiece> _TakenOut;
    // Whether the hatch and the lever refused the operator in the frame the feed was first seen carrying.
    private TOptional<bool> _GateShutWhileCarrying;
    private int32 _RockedFrames = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Build_Operator(InHandle, k_StationOrigin + k_CarrierLocal);
        _Fixture = Cast<UMars_AutoTestHelper_HeatStation>(NewObject(this, UMars_AutoTestHelper_HeatStation));

        auto Spec = FMars_Tumbler_Spec();
        Spec.Coating.CoveragePerCm = k_CoveragePerCm;
        Spec.Coating.TakeOutCoverage = k_TakeOutCoverage;
        auto Pending = _Fixture.Spawn_Tumbler(InHandle, k_StationOrigin, Spec);
        utils_pending_entity_script::Promise_OnConstructed(Pending, FCk_Delegate_EntityScript_Constructed(this, n"OnTumblerStationConstructed"));

        _Raw = _Fixture.Spawn_EmptyPlatter(InHandle, k_StationOrigin + k_RawOffset, mars_items::Platter_Large());
        _Tray = _Fixture.Spawn_EmptyPlatter(InHandle, k_StationOrigin + k_TrayOffset, mars_items::Platter());
        _Box = _Fixture.Build_Box(FTransform(FRotator::ZeroRotator, k_StationOrigin + k_RawOffset + FVector(0.0, 0.0, 60.0)), GameplayTags::Food_Meat_Beef);
        FCk_Handle BoxEntity = _Box;
        Track_ForCleanup(BoxEntity);

        Add_Steps_UntilReady();
        Add_Step_WaitUntil("the station composed its Tumbler, feed and docks and its shell is in the simulation", n"Check_TumblerStationReady", k_SlowPolls, 0);
        Add_Step_WaitUntil("both platters are constructed and the box is Ready", n"Check_PlattersAndBoxReady", k_SlowPolls, 0);
        Add_Step("load the box onto the raw platter", n"Step_Load");
        Add_Step_WaitUntil("the box landed", n"Check_Loaded", k_SlowPolls, 0);
        Add_Step("dock the raw platter and the empty tray", n"Step_Dock");
        Add_Step_WaitUntil("both platters are docked and arrived", n"Check_Docked", k_SlowPolls, 0);
        Add_Steps_TakeTheStationThroughUse();
        Add_Step_WaitUntil("the station's state machine is Operated and the feed draws the box", n"Check_OperatedAndSourced", 0, 0);
        Add_Step("look at the hatch", n"Step_LookToHatch");
        Add_Step_WaitUntil("the hatch is hovered", n"Check_HoveredHatch", 0, 0);
        Add_Step("press Use on the hatch", n"Step_PressUse");
        Add_Step_WaitUntil("the hatch is open", n"Check_HatchOpen", 0, 0);
        Add_Step("release Use", n"Step_ReleaseUse");
        Add_Step_WaitUntil("Use is released", n"Check_UseReleased", 0, 0);
        Add_Step("press the add-food key", n"Step_PressAddFood");
        Add_Step_WaitUntil("the feed carries the box", n"Check_Carrying", k_SlowPolls, 0);
        Add_Step_WaitUntil("the drum adopted the box", n"Check_Admitted", k_SlowPolls, 0);
        Add_Step("release the add-food key", n"Step_ReleaseAddFood");
        Add_Step_WaitUntil("the feed's hand is back at rest and the key is released", n"Check_FeedIdle", k_SlowPolls, 0);
        Add_Step("look at the open hatch", n"Step_LookToHatch");
        Add_Step_WaitUntil("the hatch is hovered", n"Check_HoveredHatch", 0, 0);
        Add_Step("press Use on the hatch", n"Step_PressUse");
        Add_Step_WaitUntil("the hatch is closed", n"Check_HatchClosed", 0, 0);
        Add_Step("release Use", n"Step_ReleaseUse");
        Add_Step_WaitUntil("Use is released", n"Check_UseReleased", 0, 0);
        Add_Step("look at the lever", n"Step_LookToLever");
        Add_Step_WaitUntil("the lever is hovered", n"Check_HoveredLever", 0, 0);
        Add_Step("press Use on the lever", n"Step_PressUse");
        Add_Step_WaitUntil("the lever is gripped", n"Check_Gripped", k_SlowPolls, 0);
        Add_Step_WaitUntil("the lever rocks until the box is tumbled", n"Check_RockedUntilTumbled", k_SlowPolls, 0);
        Add_Step("let go of the lever by releasing Use", n"Step_ReleaseUse");
        Add_Step_WaitUntil("the drum is home", n"Check_DrumHome", 0, 0);
        Add_Step("press the take-out key", n"Step_PressTakeOut");
        Add_Step_WaitUntil("the box landed on the tray", n"Check_OnTheTray", k_SlowPolls, 0);
        Add_Step("release the take-out key", n"Step_ReleaseTakeOut");
        Add_Step("the box rides the tray with its crumb and the drum is empty", n"Step_AssertOnTray");
        Run_Steps(InHandle);
    }

    // One look on the carrier's intents that puts the kernel's cursor on InAnchor's projection on the reach plane.
    private void LookToAnchor(const FCk_Handle_Transform& InAnchor)
    {
        const auto Spec = _Tumbler.Get_Spec();
        const auto AnchorLocal = _Tumbler.Get_RootWorld().InverseTransformPosition(utils_transform::Get_EntityCurrentLocation(InAnchor));
        const auto Centre = Spec.Hand.WorkspaceCentreLocal;
        const auto Delta = FVector2D(AnchorLocal.Y - Centre.Y, AnchorLocal.Z - Centre.Z) - _Tumbler.Get_Cursor();
        const auto Step = float64(Spec.Hand.CmPerLookDegree);
        Add_LookDelta(FVector(Delta.X / Step, -Delta.Y / Step, 0.0));
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Steps
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void Step_Load(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Raw = _Raw.As_Platter();
        Raw.Request_Load(FMars_Request_Platter_Load(_Box));
    }

    UFUNCTION()
    private void Step_Dock(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Fixture.Dock(_InputDock, _Raw);
        _Fixture.Dock(_OutputDock, _Tray);
    }

    UFUNCTION()
    private void Step_LookToHatch(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        LookToAnchor(_Tumbler.Get_Spec().Nodes.HatchTab);
    }

    UFUNCTION()
    private void Step_LookToLever(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        LookToAnchor(_Tumbler.Get_Spec().Nodes.LeverGrip);
    }

    UFUNCTION()
    private void Step_PressAddFood(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Press_Row(GameplayTags::Mars_Intent_StationAddFood);
    }

    UFUNCTION()
    private void Step_ReleaseAddFood(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Release_Row(GameplayTags::Mars_Intent_StationAddFood);
    }

    UFUNCTION()
    private void Step_PressTakeOut(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Press_Row(GameplayTags::Mars_Intent_Interact_Secondary);
    }

    UFUNCTION()
    private void Step_ReleaseTakeOut(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Release_Row(GameplayTags::Mars_Intent_Interact_Secondary);
    }

    UFUNCTION()
    private void Step_AssertOnTray(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_GateShutWhileCarrying.IsSet() && _GateShutWhileCarrying.GetValue(), "while the feed carried, the hatch and the lever refused the operator");

        const auto Tray = _Tray.As_Platter();
        FCk_Handle BoxEntity = _Box;
        Assert_True(_TakenOut.Num() == 1 && _TakenOut[0] == _Box, f"the take-out handed back the box ({_TakenOut.Num()} handed back)");
        Assert_True(_Box.TryGet_Platter() == Tray, "the box is on the tray");
        Assert_True(_Box.TryGet_Holder() == _Tray, "the tray holds the box");
        Assert_True(BoxEntity.Is_JoltBody() && utils_jolt_body::Get_MotionType(BoxEntity.As_JoltBody()) == ECk_MotionType::Kinematic, "its body is Kinematic");

        const auto Crumb = _Box.Get_CookState().Crumb;
        Log(f"[Mars_AutoTest_TumblerStation_APlatterSourcedPieceTumblesAndIsTakenOut] crumb {Crumb :.4}");
        Assert_True(Crumb >= k_TakeOutCoverage && Crumb <= 1.0f, f"the box carries its crumb ({Crumb :.4}, at least {k_TakeOutCoverage})");
        Assert_Equals_Int(_Tumbler.Get_PieceCount(), 0, "the drum is empty");
        Assert_Equals_Int(_Raw.As_Platter().Get_Occupancy(), 0, "the raw platter is spent");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Checks
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void Check_TumblerStationReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::IsValid(_Tumbler) && ck::IsValid(_Feed) && ck::IsValid(_InputDock) && ck::IsValid(_OutputDock)
            && utils_jolt_body::Get_IsBodyAdded(_Tumbler.Get_Spec().Nodes.DrumBody));
    }

    UFUNCTION()
    private void Check_PlattersAndBoxReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Fixture.Get_IsPlatterReady(_Raw, 0) && _Fixture.Get_IsPlatterReady(_Tray, 0) && _Box.Get_Status() == EMars_FoodPiece_Status::Ready);
    }

    UFUNCTION()
    private void Check_Loaded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Fixture.Get_IsPlatterReady(_Raw, 1));
    }

    UFUNCTION()
    private void Check_Docked(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Fixture.Get_IsDocked(_InputDock, _Raw) && _Fixture.Get_IsDocked(_OutputDock, _Tray));
    }

    UFUNCTION()
    private void Check_OperatedAndSourced(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto StateClass = utils_state_machine::Get_CurrentStateClass(_Station.Get_MinigameSm());
        auto Res = OutResult;
        Res.Set(StateClass == UMars_SmState_Tumbler_Operated && _Feed.Get_Source() == _Raw.As_Platter() && _Feed.Get_Available() == 1);
    }

    UFUNCTION()
    private void Check_HoveredHatch(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Tumbler.Get_Hovered() == EMars_Tumbler_Target::Hatch);
    }

    UFUNCTION()
    private void Check_HoveredLever(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Tumbler.Get_Hovered() == EMars_Tumbler_Target::Lever);
    }

    UFUNCTION()
    private void Check_HatchOpen(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Tumbler.Get_Hatch() == EMars_Tumbler_Hatch::Open);
    }

    UFUNCTION()
    private void Check_HatchClosed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Tumbler.Get_Hatch() == EMars_Tumbler_Hatch::Closed);
    }

    // The first frame the feed is seen mid-transfer: the kernel reads it, so neither the hatch nor the lever may be worked.
    UFUNCTION()
    private void Check_Carrying(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        if (_Feed.Get_IsBusy() == false)
        {
            Res.Set(false);
            return;
        }

        _GateShutWhileCarrying = TOptional<bool>(_Tumbler.Get_CanToggleHatch() == false && _Tumbler.Get_CanGrip() == false);
        Res.Set(true);
    }

    UFUNCTION()
    private void Check_Admitted(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto PieceIds = _Tumbler.Get_PieceIds();
        auto Res = OutResult;
        Res.Set(PieceIds.Num() == 1 && _Tumbler.Get_PieceHandle(PieceIds[0]) == _Box && _Raw.As_Platter().Get_Occupancy() == 0);
    }

    UFUNCTION()
    private void Check_FeedIdle(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Feed.Get_Phase() == EMars_CookingFeed_Phase::Idle && Get_IsRowHeld(GameplayTags::Mars_Intent_StationAddFood) == false);
    }

    UFUNCTION()
    private void Check_Gripped(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Tumbler.Get_HandMode() == EMars_Tumbler_HandMode::Gripped && _Tumbler.Get_Drum() == EMars_Tumbler_Drum::Gripped);
    }

    // Looks k_RockDegrees down for k_RockHalfCycleFrames frames, then up as long, and so on, until the readout lists the box.
    UFUNCTION()
    private void Check_RockedUntilTumbled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        FCk_Handle Station = _Tumbler;
        if (utils_cooking_feed::Get_Takeable(Station).Num() == 1)
        {
            Res.Set(true);
            return;
        }

        const auto Down = Math::IntegerDivisionTrunc(_RockedFrames, k_RockHalfCycleFrames) % 2 == 0;
        Add_LookDelta(FVector(0.0, float64(Down ? k_RockDegrees : -k_RockDegrees), 0.0));
        _RockedFrames += 1;
        Res.Set(false);
    }

    UFUNCTION()
    private void Check_DrumHome(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Tumbler.Get_Drum() == EMars_Tumbler_Drum::Home);
    }

    UFUNCTION()
    private void Check_OnTheTray(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Tray.As_Platter().Get_HeldCount() == 1);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Handlers
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnTumblerStationConstructed(FCk_Handle_EntityScript InEntityScriptHandle)
    {
        // Outside the test's own lifetime subtree: the runner's cascade would leave the station alive into later tests.
        Track_ForCleanup(InEntityScriptHandle);
        Watch_Station(InEntityScriptHandle.As_Station());
        _Tumbler = InEntityScriptHandle.As_Tumbler();
        _Feed = InEntityScriptHandle.As_CookingFeed();
        _InputDock = utils_platter_dock::Find_OnStation(InEntityScriptHandle, EMars_PlatterDock_Role::Input);
        _OutputDock = utils_platter_dock::Find_OnStation(InEntityScriptHandle, EMars_PlatterDock_Role::Output);
        _Tumbler.BindTo_OnPieceTakenOut(FMars_Delegate_Tumbler_OnPieceTakenOut(this, n"OnPieceTakenOut"));
    }

    UFUNCTION()
    private void OnPieceTakenOut(FCk_Handle_Tumbler InTumbler, FMars_CookingFeed_PieceId InPieceId, FCk_Handle_FoodPiece InPiece)
    {
        _TakenOut.Add(InPiece);
    }
}
