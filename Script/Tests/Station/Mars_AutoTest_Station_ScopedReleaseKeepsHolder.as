// Releases are scoped: with operator A holding the station, a release naming operator B (a rejected or stale caller) is
// a no-op - no OnReleased, A keeps it. A release naming A frees the station with OnReleased(A, OperatorRequested) and
// clears both ends of the link.
class UMars_AutoTest_Station_ScopedReleaseKeepsHolder : UCk_AutoTest_Base
{
    private FCk_Handle_Station _Station;
    private FCk_Handle_Operator _OperatorA;
    private FCk_Handle_Operator _OperatorB;

    private int32 _ReservedCount = 0;
    private TArray<FCk_Handle> _Released;
    private TArray<EMars_Station_ReleaseReason> _ReleaseReasons;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto StationEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto Root = utils_transform::Add(StationEntity, FTransform::Identity, ECk_Replication::DoesNotReplicate);
        _Station = utils_station::Add(Root, FMars_Station_Spec(), TOptional<FMars_Interactable_ProbeInfo>());

        auto OperatorAEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        _OperatorA = utils_operator::Add(OperatorAEntity);
        auto OperatorBEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        _OperatorB = utils_operator::Add(OperatorBEntity);

        _Station.BindTo_OnReserved(FMars_Delegate_Station_OnReserved(this, n"OnReserved"));
        _Station.BindTo_OnReleased(FMars_Delegate_Station_OnReleased(this, n"OnReleased"));

        Add_Step("reserve for operator A", n"Step_ReserveA");
        Add_Step_WaitUntil("the station is reserved", n"Check_Reserved", 0, 2.0f);
        Add_Step("release scoped to operator B", n"Step_ReleaseB");
        Add_Step_WaitSeconds("let the scoped release drain", 0.3f);
        Add_Step("operator A still holds the station; release scoped to operator A", n"Step_AssertKeptThenReleaseA");
        Add_Step_WaitUntil("the station is released", n"Check_Released", 0, 2.0f);
        Add_Step("A's release freed the station and cleared both ends", n"Step_AssertReleased");
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

    UFUNCTION()
    private void Step_ReserveA(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(ck::IsValid(_Station), "the station composed");
        _Station.Request_Reserve(FMars_Request_Station_Reserve(FCk_Handle(_OperatorA)));
    }

    UFUNCTION()
    private void Check_Reserved(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_ReservedCount > 0);
    }

    UFUNCTION()
    private void Step_ReleaseB(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Station.Get_IsOperatedBy(FCk_Handle(_OperatorA)), "operator A holds the station");
        _Station.Request_Release(FMars_Request_Station_Release(FCk_Handle(_OperatorB), EMars_Station_ReleaseReason::OperatorRequested));
    }

    UFUNCTION()
    private void Step_AssertKeptThenReleaseA(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Released.Num(), 0, "the release scoped to operator B fired no OnReleased");
        Assert_True(_Station.Get_Operator() == FCk_Handle(_OperatorA), "operator A still holds the station");
        Assert_True(FCk_Handle(_OperatorA.Get_Station()) == FCk_Handle(_Station), "operator A's back-ref is intact");

        _Station.Request_Release(FMars_Request_Station_Release(FCk_Handle(_OperatorA), EMars_Station_ReleaseReason::OperatorRequested));
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
        Assert_True(_Released[0] == FCk_Handle(_OperatorA), "OnReleased carries operator A");
        Assert_True(_ReleaseReasons[0] == EMars_Station_ReleaseReason::OperatorRequested,
            f"the release reason is OperatorRequested (got {_ReleaseReasons[0] :n})");
        Assert_False(_Station.Get_IsOperated(), "the station is free");
        Assert_False(_OperatorA.Get_IsOperating(), "operator A's back-ref is clear");
        Assert_False(_OperatorB.Get_IsOperating(), "operator B never operated");
    }
}
