// The holder re-reserving the station it holds changes nothing: OnReserved answers it again, nothing is rejected or
// released, and both ends of the link still name each other.
class UMars_AutoTest_Station_AHolderReReservingIsANoOp : UMars_AutoTestRig_Station
{
    private FCk_Handle_Station _Station;
    private FCk_Handle_Operator _Operator;

    private TArray<EMars_Station_RejectReason> _RejectReasons;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Station = AddStation(InHandle, FMars_Station_Spec());
        _Operator = AddOperator(InHandle);

        _Station.BindTo_OnReserved(FMars_Delegate_Station_OnReserved(this, n"OnReserved"));
        _Station.BindTo_OnReleased(FMars_Delegate_Station_OnReleased(this, n"OnReleased"));
        _Station.BindTo_OnReserveRejected(FMars_Delegate_Station_OnReserveRejected(this, n"OnReserveRejected"));

        Add_Step("reserve for the operator", n"Step_Reserve");
        Add_Step_WaitUntil("the station is reserved", n"Check_Reserved", 0, 0);
        Add_Step("the operator holds the station; it reserves it again", n"Step_ReReserve");
        Add_Step_WaitUntil("OnReserved answers the re-reserve", n"Check_ReservedTwice", 0, 0);
        Add_Step("nothing was rejected or released and the link is intact", n"Step_AssertNoOp");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnReserveRejected(FCk_Handle_Station InStation, FCk_Handle InOperator, EMars_Station_RejectReason InReason)
    {
        _RejectReasons.Add(InReason);
    }

    UFUNCTION()
    private void Step_Reserve(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Valid(_Station, "utils_station::Add composed the station");
        _Station.Request_Reserve(FMars_Request_Station_Reserve(_Operator));
    }

    UFUNCTION()
    private void Step_ReReserve(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Reserved.Num(), 1, "OnReserved fired once for the first reserve");
        Assert_True(_Station.Get_IsOperatedBy(_Operator), "the operator holds the station");
        _Station.Request_Reserve(FMars_Request_Station_Reserve(_Operator));
    }

    UFUNCTION()
    private void Check_ReservedTwice(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Reserved.Num() >= 2 || _RejectReasons.Num() > 0);
    }

    UFUNCTION()
    private void Step_AssertNoOp(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_RejectReasons.Num(), 0, "the holder's re-reserve was not rejected");
        Assert_Equals_Int(_Reserved.Num(), 2, "OnReserved answered the re-reserve once");
        if (_Reserved.Num() == 2)
        { Assert_True(_Reserved[1] == _Operator, "the second OnReserved carries the holder"); }

        Assert_Equals_Int(_Released.Num(), 0, "nothing was released");
        Assert_True(_Station.Get_IsOperatedBy(_Operator), "the operator still holds the station");
        Assert_True(_Operator.Get_Station() == _Station, "the operator's back-ref still names the station");
    }
}
