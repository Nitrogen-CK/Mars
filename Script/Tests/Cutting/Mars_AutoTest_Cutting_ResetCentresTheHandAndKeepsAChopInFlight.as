// Reset returns the hand (and the lateral node the cleaver hangs from) to the board centre and never touches the chop clock.
// The hand is nudged off centre; a chop and a reset then arrive in one drain: the hand is back at 0 and the chop still
// starts and lands. Nudged again and chopping, a reset mid-chop centres the hand and that chop lands too.
class UMars_AutoTest_Cutting_ResetCentresTheHandAndKeepsAChopInFlight : UMars_AutoTestRig_Cutting
{
    private const float32 k_NudgeCm = 5.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        BuildStation(InHandle, FMars_Cutting_Spec());

        _Cutting.BindTo_OnChopStarted(FMars_Delegate_Cutting_OnChopStarted(this, n"OnChopStarted"));
        _Cutting.BindTo_OnChopLanded(FMars_Delegate_Cutting_OnChopLanded(this, n"OnChopLanded"));

        Add_Step("nudge the hand off centre", n"Step_Nudge");
        Add_Step_WaitUntil("the hand is off centre", n"Check_HandNudged", 0, 0);
        Add_Step("chop and reset in one drain", n"Step_ChopAndReset");
        Add_Step_WaitUntil("the chop landed and the cleaver is back up", n"Check_FirstChopDone", 0, 0);
        Add_Step("the hand is centred and the chop landed; nudge again and chop", n"Step_AssertCentredAndChopAgain");
        Add_Step_WaitUntil("the hand is off centre and the cleaver is down", n"Check_NudgedAndChopping", 0, 0);
        Add_Step("reset mid-chop", n"Step_Reset");
        Add_Step_WaitUntil("the second chop landed", n"Check_SecondChopDone", 0, 0);
        Add_Step("the hand is centred and the chop in flight landed", n"Step_AssertSecondChop");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Nudge(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(ck::IsValid(_Cutting), "the feature composed");
        _Cutting.Request_Nudge(FMars_Request_Cutting_Nudge(k_NudgeCm));
    }

    UFUNCTION()
    private void Check_HandNudged(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Math::IsNearlyEqual(_Cutting.Get_HandLateral(), k_NudgeCm, 0.001f));
    }

    UFUNCTION()
    private void Step_ChopAndReset(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(Math::IsNearlyEqual(Get_NodeLateral(), k_NudgeCm, 0.001f), f"the lateral node follows the hand (got {Get_NodeLateral()})");
        _Cutting.Request_Chop(FMars_Request_Cutting_Chop());
        _Cutting.Request_Reset(FMars_Request_Cutting_Reset());
    }

    UFUNCTION()
    private void Step_AssertCentredAndChopAgain(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_ChopsStarted, 1, "the chop queued beside the reset started");
        Assert_Equals_Int(_ChopsLanded, 1, "and landed");
        Assert_True(Math::IsNearlyEqual(_Cutting.Get_HandLateral(), 0.0f, 0.001f), f"the reset centred the hand (got {_Cutting.Get_HandLateral()})");
        Assert_True(Math::IsNearlyEqual(Get_NodeLateral(), 0.0f, 0.001f), f"the lateral node is centred (got {Get_NodeLateral()})");

        _Cutting.Request_Nudge(FMars_Request_Cutting_Nudge(-k_NudgeCm));
        _Cutting.Request_Chop(FMars_Request_Cutting_Chop());
    }

    UFUNCTION()
    private void Check_NudgedAndChopping(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Cutting.Get_IsChopping() && Math::IsNearlyEqual(_Cutting.Get_HandLateral(), -k_NudgeCm, 0.001f));
    }

    UFUNCTION()
    private void Step_Reset(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Cutting.Request_Reset(FMars_Request_Cutting_Reset());
    }

    UFUNCTION()
    private void Check_SecondChopDone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_ChopsLanded >= 2 && _Cutting.Get_IsChopping() == false);
    }

    UFUNCTION()
    private void Step_AssertSecondChop(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_ChopsStarted, 2, "two chops started");
        Assert_Equals_Int(_ChopsLanded, 2, "the chop in flight at the reset landed");
        Assert_True(Math::IsNearlyEqual(_Cutting.Get_HandLateral(), 0.0f, 0.001f), f"the reset centred the hand (got {_Cutting.Get_HandLateral()})");
        Assert_True(Math::IsNearlyEqual(Get_NodeLateral(), 0.0f, 0.001f), f"the lateral node is centred (got {Get_NodeLateral()})");
    }

    private float64 Get_NodeLateral() const
    {
        auto Node = _Spec.Nodes.LateralNode;
        return utils_scene_node::Get_Offset_Location(Node).Y;
    }
}
