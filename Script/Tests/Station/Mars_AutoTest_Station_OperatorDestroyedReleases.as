// A destroyed operator releases: the reserve arms a destroy watch on the operator, so destroying the operator entity (no
// release request anywhere) frees the station with OnReleased(A, OperatorLost), and the Use prompt goes back from
// Prompt.OccupiedText to Prompt.Text with the Use target enabled again. Uses the real reserve path (a direct Operator stamp would
// bypass the watch under test).
class UMars_AutoTest_Station_OperatorDestroyedReleases : UMars_AutoTestRig_Station
{
    private FCk_Handle_Station _Station;
    private FCk_Handle _Operator;
    private FMars_Station_Spec _Spec;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Spec = FMars_Station_Spec();
        _Spec.Prompt = FMars_Station_PromptSpec(FText::FromString("Use test station"), FText::FromString("Test station in use"));
        _Station = AddStation(InHandle, _Spec);
        _Operator = AddOperator(InHandle);

        _Station.BindTo_OnReserved(FMars_Delegate_Station_OnReserved(this, n"OnReserved"));
        _Station.BindTo_OnReleased(FMars_Delegate_Station_OnReleased(this, n"OnReleased"));

        Add_Step("reserve for the operator", n"Step_Reserve");
        Add_Step_WaitUntil("the station is reserved and its prompt reads the occupied text", n"Check_ReservedAndOccupied", 0, 2.0f);
        Add_Step("the Use target is disabled; destroy the operator entity", n"Step_DestroyOperator");
        Add_Step_WaitUntil("the station is released", n"Check_Released", 0, 2.0f);
        Add_Step("the release was OperatorLost and the station is free", n"Step_AssertReleased");
        Add_Step_WaitUntil("the prompt reads the prompt text again", n"Check_PromptRestored", 0, 2.0f);
        Add_Step("the Use target is enabled again", n"Step_AssertEnabled");
        Run_Steps(InHandle);
    }

    // The Use target and its prompt are composed with the station, so their absence fails the test.
    private FString Get_PromptText()
    {
        auto Target = _Station.Get_UseTarget();
        if (ck::Is_NOT_Valid(Target))
        {
            FinishFailure("the station has no Use target");
            return "";
        }

        return Target.As_InteractPrompt().Get_PromptText().ToString();
    }

    UFUNCTION()
    private void Step_Reserve(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Valid(_Station, "utils_station::Add composed the station");
        Assert_Valid(_Station.Get_UseTarget(), "the station has a Use target");
        _Station.Request_Reserve(FMars_Request_Station_Reserve(_Operator));
    }

    UFUNCTION()
    private void Check_ReservedAndOccupied(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Reserved.Num() > 0 && Get_PromptText() == _Spec.Prompt.OccupiedText.ToString());
    }

    UFUNCTION()
    private void Step_DestroyOperator(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Station.Get_IsOperatedBy(_Operator), "the operator holds the station");
        Assert_True(utils_interact_target::Get_Enabled(_Station.Get_UseTarget()) == ECk_EnableDisable::Disable,
            "the Use target is disabled while reserved");

        utils_entity_lifetime::Request_DestroyEntity(_Operator);
    }

    UFUNCTION()
    private void Step_AssertReleased(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Released.Num(), 1, "OnReleased fired once");
        if (_Released.Num() == 1)
        {
            Assert_True(_Released[0] == _Operator, "OnReleased carries the destroyed operator's handle");
            Assert_True(_ReleaseReasons[0] == EMars_Station_ReleaseReason::OperatorLost,
                f"the release reason is OperatorLost (got {_ReleaseReasons[0] :n})");
        }

        Assert_False(_Station.Get_IsOperated(), "the station is free");
    }

    UFUNCTION()
    private void Check_PromptRestored(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_PromptText() == _Spec.Prompt.Text.ToString());
    }

    UFUNCTION()
    private void Step_AssertEnabled(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(utils_interact_target::Get_Enabled(_Station.Get_UseTarget()) == ECk_EnableDisable::Enable,
            "the Use target is enabled again");
    }
}
