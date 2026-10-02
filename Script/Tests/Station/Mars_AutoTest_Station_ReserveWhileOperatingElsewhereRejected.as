// One station per operator: while operator A holds station S1, S2's reserve for A is rejected AlreadyOperating and S1
// keeps A. Once S1 releases A, S2's reserve for A is confirmed and A's back-ref moves to S2.
class UMars_AutoTest_Station_ReserveWhileOperatingElsewhereRejected : UCk_AutoTest_Base
{
    private FCk_Handle_Station _StationOne;
    private FCk_Handle_Station _StationTwo;
    private FCk_Handle_Operator _Operator;

    private int32 _OneReservedCount = 0;
    private int32 _OneReleasedCount = 0;
    private int32 _TwoReservedCount = 0;
    private TArray<EMars_Station_RejectReason> _TwoRejectReasons;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        // Each station on its own child entity: composing both on one entity would alias them.
        auto OneEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto OneRoot = utils_transform::Add(OneEntity, FTransform::Identity, ECk_Replication::DoesNotReplicate);
        _StationOne = utils_station::Add(OneRoot, FMars_Station_Spec(), FMars_Station_Setup());

        auto TwoEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto TwoRoot = utils_transform::Add(TwoEntity, FTransform::Identity, ECk_Replication::DoesNotReplicate);
        _StationTwo = utils_station::Add(TwoRoot, FMars_Station_Spec(), FMars_Station_Setup());

        auto OperatorEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        _Operator = utils_operator::Add(OperatorEntity);

        _StationOne.BindTo_OnReserved(FMars_Delegate_Station_OnReserved(this, n"OnOneReserved"));
        _StationOne.BindTo_OnReleased(FMars_Delegate_Station_OnReleased(this, n"OnOneReleased"));
        _StationTwo.BindTo_OnReserved(FMars_Delegate_Station_OnReserved(this, n"OnTwoReserved"));
        _StationTwo.BindTo_OnReserveRejected(FMars_Delegate_Station_OnReserveRejected(this, n"OnTwoRejected"));

        Add_Step("S1 reserves for the operator", n"Step_ReserveOne");
        Add_Step_WaitUntil("S1 is reserved", n"Check_OneReserved", 0, 2.0f);
        Add_Step("S2 reserves for the same operator", n"Step_ReserveTwo");
        Add_Step_WaitUntil("S2 rejects the operator", n"Check_TwoRejected", 0, 2.0f);
        Add_Step("S2 rejected AlreadyOperating and S1 kept the operator; S1 releases", n"Step_AssertRejectedThenReleaseOne");
        Add_Step_WaitUntil("S1 is released", n"Check_OneReleased", 0, 2.0f);
        Add_Step("S2 reserves for the operator again", n"Step_ReserveTwo");
        Add_Step_WaitUntil("S2 is reserved", n"Check_TwoReserved", 0, 2.0f);
        Add_Step("S2 holds the operator and the back-ref moved", n"Step_AssertMoved");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnOneReserved(FCk_Handle_Station InStation, FCk_Handle InOperator)
    {
        _OneReservedCount += 1;
    }

    UFUNCTION()
    private void OnOneReleased(FCk_Handle_Station InStation, FCk_Handle InOperator, EMars_Station_ReleaseReason InReason)
    {
        _OneReleasedCount += 1;
    }

    UFUNCTION()
    private void OnTwoReserved(FCk_Handle_Station InStation, FCk_Handle InOperator)
    {
        _TwoReservedCount += 1;
    }

    UFUNCTION()
    private void OnTwoRejected(FCk_Handle_Station InStation, FCk_Handle InOperator, EMars_Station_RejectReason InReason)
    {
        _TwoRejectReasons.Add(InReason);
    }

    UFUNCTION()
    private void Step_ReserveOne(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(ck::IsValid(_StationOne) && ck::IsValid(_StationTwo), "both stations composed");
        _StationOne.Request_Reserve(FMars_Request_Station_Reserve(FCk_Handle(_Operator)));
    }

    UFUNCTION()
    private void Check_OneReserved(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_OneReservedCount > 0);
    }

    UFUNCTION()
    private void Step_ReserveTwo(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _StationTwo.Request_Reserve(FMars_Request_Station_Reserve(FCk_Handle(_Operator)));
    }

    UFUNCTION()
    private void Check_TwoRejected(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_TwoRejectReasons.Num() > 0);
    }

    UFUNCTION()
    private void Step_AssertRejectedThenReleaseOne(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_TwoRejectReasons[0] == EMars_Station_RejectReason::AlreadyOperating,
            f"S2 rejected the operator AlreadyOperating (got {_TwoRejectReasons[0] :n})");
        Assert_Equals_Int(_TwoReservedCount, 0, "S2 did not reserve");
        Assert_False(_StationTwo.Get_IsOperated(), "S2 stayed free");
        Assert_True(_StationOne.Get_IsOperatedBy(FCk_Handle(_Operator)), "S1 still holds the operator");
        Assert_True(FCk_Handle(_Operator.Get_Station()) == FCk_Handle(_StationOne), "the operator's back-ref still names S1");

        _StationOne.Request_Release(FMars_Request_Station_Release(FCk_Handle(_Operator), EMars_Station_ReleaseReason::OperatorRequested));
    }

    UFUNCTION()
    private void Check_OneReleased(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_OneReleasedCount > 0);
    }

    UFUNCTION()
    private void Check_TwoReserved(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_TwoReservedCount > 0);
    }

    UFUNCTION()
    private void Step_AssertMoved(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_TwoRejectReasons.Num(), 1, "S2 rejected only the first reserve");
        Assert_True(_StationTwo.Get_IsOperatedBy(FCk_Handle(_Operator)), "S2 holds the operator");
        Assert_False(_StationOne.Get_IsOperated(), "S1 is free");
        Assert_True(FCk_Handle(_Operator.Get_Station()) == FCk_Handle(_StationTwo), "the operator's back-ref names S2");
    }
}
