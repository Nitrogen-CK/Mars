// Back leaves the station. The operator rig's carrier takes a bare station through its Use interaction (its gloves on the
// station's grip), then presses Back: the Operating state's LeaveIntent asks the station to release it, the station
// releases the carrier (OperatorRequested) and clears both ends of the link, the carrier's state machine leaves Operating
// (its Grip task cancels the grip interaction and closes the Operate intent), and the gloves let go and return to rest.
// The Use interactable drops its Operated claim and the "leave" row goes. Isolated origin (171000, -70000, -30000).
class UMars_AutoTest_Station_BackLeavesTheStation : UMars_AutoTestRig_Operator
{
    private const FVector k_Origin = FVector(171000.0, -70000.0, -30000.0);
    // The station's root, in front of the carrier.
    private const FVector k_StationLocal = FVector(120.0, 0.0, 0.0);

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Build_Operator(InHandle, k_Origin);
        Build_BareStation(InHandle, k_StationLocal);

        Add_Steps_UntilReady();
        Add_Steps_TakeTheStationThroughUse();
        Add_Step("press Back", n"Step_PressBack");
        Add_Step_WaitUntil("the station released the carrier", n"Check_Released", 0, 0);
        Add_Step_WaitUntil("the gloves let go of the grip and rest", n"Check_GlovesRest", 0, 0);
        Add_Step("release Back", n"Step_ReleaseBack");
        Add_Step_WaitUntil("Back is released", n"Check_BackReleased", 0, 0);
        Add_Step("the operator is cleared, the station is free and the gloves are back", n"Step_AssertLeft");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_PressBack(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(Get_IsGlovesOnTheGrip(), "the gloves hold the station's grip before the press");
        Press_Row(GameplayTags::Mars_Intent_Back);
    }

    UFUNCTION()
    private void Check_Released(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_ReleaseReasons.Num() > 0);
    }

    UFUNCTION()
    private void Check_GlovesRest(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Hands.Get_Phase() == EMars_FPHands_Phase::None);
    }

    UFUNCTION()
    private void Step_ReleaseBack(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Release_Row(GameplayTags::Mars_Intent_Back);
    }

    UFUNCTION()
    private void Check_BackReleased(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsRowHeld(GameplayTags::Mars_Intent_Back) == false);
    }

    UFUNCTION()
    private void Step_AssertLeft(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_ReleaseReasons.Num() == 1 && _ReleaseReasons[0] == EMars_Station_ReleaseReason::OperatorRequested,
            f"the station released the carrier once, at its request ({_ReleaseReasons.Num()} releases)");
        Assert_False(_Station.Get_IsOperated(), "the station has no operator");
        Assert_False(_Operator.Get_IsOperating(), "the carrier's operator holds no station");
        Assert_False(_Station.Get_Interactable().Get_IsDisabledFor(EMars_Interactable_DisableReason::Operated),
            "the station's Use interactable dropped the Operated claim");
        Assert_Invalid(utils_interact_target::TryGet_Interaction(_Station.Get_GripTarget(), _Carrier), "the grip interaction ended");
        Assert_False(_Hands.Get_ReachInteractTarget().IsSet(), "the gloves forgot the grip");
        Assert_False(Get_HasHint("leave"), "the leave row is gone");
    }
}
