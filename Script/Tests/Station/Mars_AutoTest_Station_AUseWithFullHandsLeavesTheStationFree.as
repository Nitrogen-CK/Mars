// A Use with full hands leaves the station free. The operator rig's carrier holds a rock in both gloves (stowed into bag
// slot 0) and looks at a bare station's Use probe: it focuses the station, whose Use target needs free hands
// (RequiresFreeHands), so the target refuses the carrier and its prompt reads the hands-full reason. A Use press starts no
// interaction: the station is never reserved and no reserve is even rejected, the carrier's operator holds nothing, so its
// state machine stays in Roam (no "leave" row, no grip interaction), and the rock stays in both gloves. With the hands
// emptied, the same press reserves the station inside the window the refusal was watched for, which is what makes that
// window long enough. Isolated origin (174000, -70000, -30000).
class UMars_AutoTest_Station_AUseWithFullHandsLeavesTheStationFree : UMars_AutoTestRig_Operator
{
    private const FVector k_Origin = FVector(174000.0, -70000.0, -30000.0);
    // The station's root, in front of the carrier.
    private const FVector k_StationLocal = FVector(120.0, 0.0, 0.0);
    // The processor passes a refused press is watched for. The free-hands press at the end must reserve the station
    // within this many frames, so a reserve the refused press had started would have landed inside the window.
    private const int32 k_RefusalWindowFrames = 30;

    private FCk_Handle_Inventory_DataOnly _RockHolder;
    private FCk_Handle_Item _Rock;
    private TArray<EMars_Station_RejectReason> _Rejections;
    private int64 _FreePressFrame = -1;
    private int64 _ReservedSeenFrame = -1;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Build_Operator(InHandle, k_Origin);
        Build_BareStation(InHandle, k_StationLocal);
        _Station.BindTo_OnReserveRejected(FMars_Delegate_Station_OnReserveRejected(this, n"OnStationReserveRejected"));
        _RockHolder = MakeSeededHolder(InHandle, mars_items::Rock());

        Add_Steps_UntilReady();
        Add_Step_WaitUntil("the rock's holder is seeded", n"Check_RockSeeded", 0, 0);
        Add_Step("stow the rock into bag slot 0", n"Step_StowTheRock");
        Add_Step_WaitUntil("the gloves hold the rock in both hands", n"Check_HoldsTheRock", 0, 0);
        Add_Step("turn the view onto the station's Use probe", n"Step_AimAtTheStation");
        Add_Step_WaitUntil("the carrier focuses the station and its prompt reads the hands-full reason", n"Check_FocusedWithFullHands", 0, 0);
        Add_Step("the Use target refuses full hands; press Use", n"Step_PressUseWithFullHands");
        Add_Step_WaitUntil("Use is held", n"Check_UseHeld", 0, 0);
        Add_Step_WaitFrames("a reserve the press had started would land in this window", k_RefusalWindowFrames);
        Add_Step("no reserve, the station is free, the carrier stays in Roam and the rock stays in its hands", n"Step_AssertTheStationIsFree");
        Add_Step("release Use", n"Step_ReleaseUse");
        Add_Step_WaitUntil("Use is released", n"Check_UseReleased", 0, 0);
        Add_Step("select the empty bag slot 1", n"Step_SelectEmptySlot");
        Add_Step_WaitUntil("the hands are empty and the prompt reads its text again", n"Check_HandsFreeAndUnblocked", 0, 0);
        Add_Step("press Use with free hands", n"Step_PressUseWithFreeHands");
        Add_Step_WaitUntil("the station names the carrier its operator", n"Check_ReservedForTheCarrier", 0, 0);
        Add_Step("the free-hands press reserved the station inside the refusal's window; release Use", n"Step_AssertReservedInsideTheWindow");
        Add_Step_WaitUntil("the gloves hold the station's grip", n"Check_GlovesOnTheGrip", 0, 0);
        Run_Steps(InHandle);
    }

    private FCk_Handle_InteractPrompt Get_UsePrompt() const
    { return _Station.Get_UseTarget().As_InteractPrompt(); }

    //----------------------------------------------------------------------------------------------------------------------
    // Steps
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void Check_RockSeeded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Seeded = _RockHolder.Get_NumItems() == 1;
        if (Seeded && ck::Is_NOT_Valid(_Rock))
        {
            auto Items = _RockHolder.Get_Items();
            _Rock = Items[0];
        }

        auto Res = OutResult;
        Res.Set(Seeded);
    }

    UFUNCTION()
    private void Step_StowTheRock(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        StowFrom(_RockHolder);
    }

    UFUNCTION()
    private void Check_HoldsTheRock(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_HeldItem.Get_CurrentItem() == _Rock && _Hands.Get_Hold().Kind == EMars_FPHands_HoldKind::TwoHanded);
    }

    UFUNCTION()
    private void Check_FocusedWithFullHands(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Prompt = Get_UsePrompt();
        auto Res = OutResult;
        Res.Set(_Station.Get_Interactable().Get_CurrentFocuser() == _Carrier
            && utils_state_machine::Get_CurrentStateClass(_Station.Get_UseTarget().As_StateMachine()) == UMars_SmState_Interactable_Focused
            && Prompt.Get_IsBlocked()
            && Prompt.Get_DisplayText().ToString() == utils_interactable::Get_HandsFullText().ToString());
    }

    UFUNCTION()
    private void Step_PressUseWithFullHands(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(utils_interactable::Get_HandsAreFree(_Carrier), "the carrier holding the rock has full hands");

        const auto CanUse = utils_interact_target::Get_CanInteractWith(_Station.Get_UseTarget(), _Carrier);
        Assert_True(CanUse == ECk_CanInteractWithResult::CustomValidationFailed,
            f"the station's Use target refuses full hands (got [{CanUse :n}])");

        _UseKey.Press();
    }

    UFUNCTION()
    private void Step_AssertTheStationIsFree(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Reserved.Num(), 0, "the station was never reserved");
        Assert_Equals_Int(_Rejections.Num(), 0, "no reserve was requested (none was rejected)");
        Assert_False(_Station.Get_IsOperated(), "the station has no operator");
        Assert_False(_Station.Get_Interactable().Get_IsDisabledFor(EMars_Interactable_DisableReason::Operated),
            "the station's Use interactable holds no Operated claim");
        Assert_Invalid(utils_interact_target::TryGet_Interaction(_Station.Get_UseTarget(), _Carrier), "the press started no Use interaction");
        Assert_False(_Operator.Get_IsOperating(), "the carrier's operator holds no station, so its state machine stays in Roam");
        Assert_False(Get_HasHint("leave"), "the Operating state's leave row never showed");
        Assert_Invalid(utils_interact_target::TryGet_Interaction(_Station.Get_GripTarget(), _Carrier), "no grip interaction began");
        Assert_True(_HeldItem.Get_CurrentItem() == _Rock && _Hands.Get_Hold().Kind == EMars_FPHands_HoldKind::TwoHanded,
            "the rock stays in both gloves");
        Assert_True(Get_UsePrompt().Get_IsBlocked(), "the prompt still reads the hands-full reason");
    }

    UFUNCTION()
    private void Check_HandsFreeAndUnblocked(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(utils_interactable::Get_HandsAreFree(_Carrier)
            && _Hands.Get_Hold().Kind == EMars_FPHands_HoldKind::Empty
            && Get_UsePrompt().Get_IsBlocked() == false);
    }

    UFUNCTION()
    private void Step_PressUseWithFreeHands(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Reserved.Num(), 0, "the station is still free before the free-hands press");
        _FreePressFrame = utils_time::Get_FrameCounter();
        _UseKey.Press();
    }

    UFUNCTION()
    private void Check_ReservedForTheCarrier(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Reserved = _Station.Get_IsOperatedBy(_Carrier) && _Operator.Get_Station() == _Station;
        if (Reserved && _ReservedSeenFrame < 0)
        { _ReservedSeenFrame = utils_time::Get_FrameCounter(); }

        auto Res = OutResult;
        Res.Set(Reserved);
    }

    UFUNCTION()
    private void Step_AssertReservedInsideTheWindow(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Frames = _ReservedSeenFrame - _FreePressFrame;
        Assert_True(Frames <= k_RefusalWindowFrames,
            f"the free-hands press reserved the station within {k_RefusalWindowFrames} frames (took {Frames})");
        Assert_True(_Reserved.Num() == 1 && _Reserved[0] == _Carrier, f"the station was reserved once, for the carrier ({_Reserved.Num()} reserves)");
        Assert_Equals_Int(_Rejections.Num(), 0, "no reserve was rejected");
        _UseKey.Release();
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Handlers
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnStationReserveRejected(FCk_Handle_Station InStation, FCk_Handle InOperator, EMars_Station_RejectReason InReason)
    {
        _Rejections.Add(InReason);
    }
}
