// A reserve whose grip never lands gives the station up. The operator rig's carrier holds a rock in both gloves (stowed into
// bag slot 0), so no reach but a Place can resolve; the station's Use refuses full hands, so the bare station is reserved
// for the carrier by request (what the reserve interaction would issue). The carrier's state machine enters Operating, whose
// Grip task starts the grip interaction; the gloves refuse its reach (OutOfReach), and the Grip task gives the station up
// (Request_Leave): the station releases the carrier once, at the operator's request, within the grip's landing bound
// (utils_fphands::Get_GripLandSeconds), and is free. The carrier's state machine is back in Roam with no grip interaction,
// no leave row and the rock still in both gloves. Isolated origin (175000, -70000, -30000).
class UMars_AutoTest_Station_AReserveWhoseGripNeverLandsGivesUp : UMars_AutoTestRig_Operator
{
    private const FVector k_Origin = FVector(175000.0, -70000.0, -30000.0);
    // The station's root, in front of the carrier.
    private const FVector k_StationLocal = FVector(120.0, 0.0, 0.0);

    private FCk_Handle_Inventory_DataOnly _RockHolder;
    private FCk_Handle_Item _Rock;
    // The gloves' refusals of the station's grip reach, in order.
    private TArray<EMars_FPHands_ReachRefusal> _GripRefusals;
    private float64 _ReservedSeconds = -1.0;
    private float64 _ReleasedSeconds = -1.0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Build_Operator(InHandle, k_Origin);
        Build_BareStation(InHandle, k_StationLocal);
        _Hands.BindTo_OnReachRefused(FMars_Delegate_FPHands_OnReachRefused(this, n"OnGripReachRefused"));
        _Station.BindTo_OnReserved(FMars_Delegate_Station_OnReserved(this, n"OnReservedAt"));
        _Station.BindTo_OnReleased(FMars_Delegate_Station_OnReleased(this, n"OnReleasedAt"));
        _RockHolder = MakeSeededHolder(InHandle, mars_items::Rock());

        Add_Steps_UntilReady();
        Add_Step_WaitUntil("the rock's holder is seeded", n"Check_RockSeeded", 0, 0);
        Add_Step("stow the rock into bag slot 0", n"Step_StowTheRock");
        Add_Step_WaitUntil("the gloves hold the rock in both hands", n"Check_HoldsTheRock", 0, 0);
        Add_Step("reserve the station for the carrier, as its reserve interaction would", n"Step_Reserve");
        Add_Step_WaitUntil("the station names the carrier its operator", n"Check_Reserved", 0, 0);
        Add_Step_WaitUntil("the station released the carrier", n"Check_Released", 0, 0);
        Add_Step_WaitUntil("the carrier's state machine is back in Roam", n"Check_BackInRoam", 0, 0);
        Add_Step("the grip was refused, the station given up within the bound and free, the rock still held", n"Step_AssertGaveUp");
        Run_Steps(InHandle);
    }

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

    // The Use target refuses full hands (RequiresFreeHands), so a press could not reserve: the request stands in for the
    // reserve interaction's.
    UFUNCTION()
    private void Step_Reserve(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(utils_interactable::Get_HandsAreFree(_Carrier), "the carrier holding the rock has full hands");
        _Station.Request_Reserve(FMars_Request_Station_Reserve(_Carrier));
    }

    UFUNCTION()
    private void Check_Reserved(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Reserved.Num() == 1);
    }

    UFUNCTION()
    private void Check_Released(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_ReleaseReasons.Num() > 0);
    }

    UFUNCTION()
    private void Check_BackInRoam(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Operator.Get_IsOperating() == false && Get_HasHint("leave") == false
            && ck::Is_NOT_Valid(utils_interact_target::TryGet_Interaction(_Station.Get_GripTarget(), _Carrier)));
    }

    UFUNCTION()
    private void Step_AssertGaveUp(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Reserved.Num() == 1 && _Reserved[0] == _Carrier, f"the station was reserved once, for the carrier ({_Reserved.Num()} reserves)");
        Assert_True(_GripRefusals.Num() >= 1 && _GripRefusals[0] == EMars_FPHands_ReachRefusal::OutOfReach,
            f"the gloves refused the grip's reach as out of reach ({_GripRefusals.Num()} refusals)");
        Assert_True(_ReleaseReasons.Num() == 1 && _ReleaseReasons[0] == EMars_Station_ReleaseReason::OperatorRequested,
            f"the station released the carrier once, at the operator's request ({_ReleaseReasons.Num()} releases)");

        const auto Bound = float64(utils_fphands::Get_GripLandSeconds(_Hands));
        const auto GaveUpAfter = _ReleasedSeconds - _ReservedSeconds;
        Assert_True(GaveUpAfter >= 0.0 && GaveUpAfter <= Bound,
            f"the station was given up within the grip's landing bound of {Bound} s (after {GaveUpAfter} s)");

        Assert_False(_Station.Get_IsOperated(), "the station has no operator");
        Assert_False(_Operator.Get_IsOperating(), "the carrier's operator holds no station");
        Assert_False(_Station.Get_Interactable().Get_IsDisabledFor(EMars_Interactable_DisableReason::Operated),
            "the station's Use interactable dropped the Operated claim");
        Assert_Invalid(utils_interact_target::TryGet_Interaction(_Station.Get_GripTarget(), _Carrier), "the grip interaction ended");
        Assert_False(_Hands.Get_IsReachTarget(_Station.Get_GripTarget()), "the gloves never took the grip");
        Assert_True(_HeldItem.Get_CurrentItem() == _Rock && _Hands.Get_Hold().Kind == EMars_FPHands_HoldKind::TwoHanded,
            "the rock stays in both gloves");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Handlers
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnGripReachRefused(FCk_Handle_FPHands InHands, FCk_Handle_InteractTarget InTarget, EMars_FPHands_ReachKind InKind,
        EMars_FPHands_ReachRefusal InReason)
    {
        if (InTarget == _Station.Get_GripTarget())
        { _GripRefusals.Add(InReason); }
    }

    UFUNCTION()
    private void OnReservedAt(FCk_Handle_Station InStation, FCk_Handle InOperator)
    {
        _ReservedSeconds = System::GetGameTimeInSeconds();
    }

    UFUNCTION()
    private void OnReleasedAt(FCk_Handle_Station InStation, FCk_Handle InOperator, EMars_Station_ReleaseReason InReason)
    {
        _ReleasedSeconds = System::GetGameTimeInSeconds();
    }
}
