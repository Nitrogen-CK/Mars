// An operator takes a station through its Use interaction, as the player does. The operator rig's carrier looks at a bare
// station's Use probe and presses Use: the merged intent task starts the carrier's interaction on the station's Use target,
// whose interaction sub-SM reserves the station for the initiator (UMars_SmTask_Station_RequestReserve). The station names
// the carrier its operator once, the Use interaction ends with that answer and the Use interactable holds the Operated
// claim; the carrier's state machine enters Operating, whose Grip task starts the grip interaction under the Operate intent,
// and the gloves reach for the station's grip and hold it; the Hints task shows "leave". Isolated origin
// (170000, -70000, -30000).
class UMars_AutoTest_Station_AnOperatorReservesThroughTheUseInteraction : UMars_AutoTestRig_Operator
{
    private const FVector k_Origin = FVector(170000.0, -70000.0, -30000.0);
    // The station's root, in front of the carrier.
    private const FVector k_StationLocal = FVector(120.0, 0.0, 0.0);

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Build_Operator(InHandle, k_Origin);
        Build_BareStation(InHandle, k_StationLocal);

        Add_Steps_UntilReady();
        Add_Steps_TakeTheStationThroughUse();
        Add_Step("the carrier operates the station its Use interaction reserved, and the gloves hold its grip", n"Step_AssertOperating");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AssertOperating(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Station.Get_IsOperated() && _Station.Get_Operator() == _Carrier, "the station's operator is the carrier");
        Assert_True(_Operator.Get_IsOperating() && _Operator.Get_Station() == _Station, "the carrier's operator holds the station");
        Assert_True(_Reserved.Num() == 1 && _Reserved[0] == _Carrier, f"the station was reserved once, for the carrier ({_Reserved.Num()} reserves)");
        Assert_True(Get_IsUseInteractionOver(), "the Use interaction ended with the reserve's answer");
        Assert_True(_Station.Get_Interactable().Get_IsDisabledFor(EMars_Interactable_DisableReason::Operated),
            "the station's Use interactable holds the Operated claim");
        Assert_True(Get_IsGlovesOnTheGrip(), f"the gloves hold the station's grip (phase {_Hands.Get_Phase() :n})");
        Assert_Valid(utils_interact_target::TryGet_Interaction(_Station.Get_GripTarget(), _Carrier), "the carrier's grip interaction is live");
        Assert_True(Get_HasHint("leave"), "the operator's legend reads leave");
    }
}
