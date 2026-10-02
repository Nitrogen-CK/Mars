// A destroyed operator releases: the reserve arms a destroy watch on the operator, so destroying the operator entity (no
// release request anywhere) frees the station with OnReleased(A, OperatorLost), and the Use prompt goes back from
// Prompt.OccupiedText to Prompt.Text with the Use target enabled again. Uses the real reserve path (a direct Operator stamp would
// bypass the watch under test).
class UMars_AutoTest_Station_OperatorDestroyedReleases : UCk_AutoTest_Base
{
    private FCk_Handle_Station _Station;
    private FCk_Handle _Operator;
    private FMars_Station_Spec _Spec;

    private int32 _ReservedCount = 0;
    private TArray<FCk_Handle> _Released;
    private TArray<EMars_Station_ReleaseReason> _ReleaseReasons;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Spec = FMars_Station_Spec();
        _Spec.Prompt = FMars_Station_PromptSpec(FText::FromString("Use test station"), FText::FromString("Test station in use"));

        auto StationEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto Root = utils_transform::Add(StationEntity, FTransform::Identity, ECk_Replication::DoesNotReplicate);
        _Station = utils_station::Add(Root, _Spec, FMars_Station_Setup());

        _Operator = utils_entity_lifetime::Request_CreateEntity(InHandle);
        utils_operator::Add(_Operator);

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

    UFUNCTION()
    private void OnReserved(FCk_Handle_Station InStation, FCk_Handle InOperator)
    {
        _ReservedCount += 1;
    }

    UFUNCTION()
    private void OnReleased(FCk_Handle_Station InStation, FCk_Handle InOperator, EMars_Station_ReleaseReason InReason)
    {
        _Released.Add(InOperator);
        _ReleaseReasons.Add(InReason);
    }

    private FString Get_PromptText() const
    {
        auto Target = _Station.Get_UseTarget();
        if (ck::Is_NOT_Valid(Target))
        { return ""; }

        auto Prompt = FCk_Handle(Target).As_InteractPrompt(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Prompt))
        { return ""; }

        return Prompt.Get_PromptText().ToString();
    }

    UFUNCTION()
    private void Step_Reserve(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(ck::IsValid(_Station), "the station composed");
        Assert_True(ck::IsValid(_Station.Get_UseTarget()), "the station has a Use target");
        _Station.Request_Reserve(FMars_Request_Station_Reserve(_Operator));
    }

    UFUNCTION()
    private void Check_ReservedAndOccupied(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_ReservedCount > 0 && Get_PromptText() == _Spec.Prompt.OccupiedText.ToString());
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
    private void Check_Released(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Released.Num() > 0);
    }

    UFUNCTION()
    private void Step_AssertReleased(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Released.Num(), 1, "OnReleased fired once");
        Assert_True(_Released[0] == _Operator, "OnReleased carries the destroyed operator's handle");
        Assert_True(_ReleaseReasons[0] == EMars_Station_ReleaseReason::OperatorLost,
            f"the release reason is OperatorLost (got {_ReleaseReasons[0] :n})");
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
