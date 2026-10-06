// Single-slot contract: while operator A holds the station, operator B's reserve is rejected Occupied, and A keeps the
// station on BOTH ends of the link while B stays free.
class UMars_AutoTest_Station_ReserveRejectsSecondOperator : UMars_AutoTestRig_Station
{
    private FCk_Handle_Station _Station;
    private FCk_Handle_Operator _OperatorA;
    private FCk_Handle_Operator _OperatorB;

    private TArray<FCk_Handle> _Rejected;
    private TArray<EMars_Station_RejectReason> _RejectReasons;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Station = AddStation(InHandle, FMars_Station_Spec());
        _OperatorA = AddOperator(InHandle);
        _OperatorB = AddOperator(InHandle);

        _Station.BindTo_OnReserved(FMars_Delegate_Station_OnReserved(this, n"OnReserved"));
        _Station.BindTo_OnReserveRejected(FMars_Delegate_Station_OnReserveRejected(this, n"OnReserveRejected"));

        Add_Step("reserve for operator A", n"Step_ReserveA");
        Add_Step_WaitUntil("the station is reserved", n"Check_Reserved", 0, 2.0f);
        Add_Step("operator A holds the station; reserve for operator B", n"Step_ReserveB");
        Add_Step_WaitUntil("operator B is rejected", n"Check_Rejected", 0, 2.0f);
        Add_Step("B was rejected Occupied and A still holds the station", n"Step_AssertRejected");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnReserveRejected(FCk_Handle_Station InStation, FCk_Handle InOperator, EMars_Station_RejectReason InReason)
    {
        _Rejected.Add(InOperator);
        _RejectReasons.Add(InReason);
    }

    UFUNCTION()
    private void Step_ReserveA(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Valid(_Station, "utils_station::Add composed the station");
        _Station.Request_Reserve(FMars_Request_Station_Reserve(_OperatorA));
    }

    UFUNCTION()
    private void Step_ReserveB(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Reserved.Num(), 1, "OnReserved fired once");
        if (_Reserved.Num() == 1)
        { Assert_True(_OperatorA == _Reserved[0], "OnReserved carries operator A"); }

        Assert_True(_Station.Get_IsOperatedBy(_OperatorA), "the station names operator A");
        Assert_True(_OperatorA.Get_Station() == _Station, "operator A's back-ref names the station");

        _Station.Request_Reserve(FMars_Request_Station_Reserve(_OperatorB));
    }

    UFUNCTION()
    private void Check_Rejected(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Rejected.Num() > 0);
    }

    UFUNCTION()
    private void Step_AssertRejected(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Rejected.Num(), 1, "OnReserveRejected fired once");
        if (_Rejected.Num() == 1)
        {
            Assert_True(_OperatorB == _Rejected[0], "the rejection carries operator B");
            Assert_True(_RejectReasons[0] == EMars_Station_RejectReason::Occupied, f"B was rejected Occupied (got {_RejectReasons[0] :n})");
        }

        Assert_Equals_Int(_Reserved.Num(), 1, "OnReserved did not fire for operator B");
        Assert_True(_OperatorA == _Station.Get_Operator(), "operator A still holds the station");
        Assert_True(_OperatorA.Get_Station() == _Station, "operator A's back-ref is intact");
        Assert_False(_OperatorB.Get_IsOperating(), "operator B stayed free");
    }
}
