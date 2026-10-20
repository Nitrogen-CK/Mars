// A destroyed station releases its operator: the reserve arms a destroy watch on the station, so destroying the station
// entity (no release request anywhere) clears the operator's back-ref and broadcasts OnReleased(A, StationDestroyed)
// once. Uses the real reserve path (a direct back-ref stamp would bypass the watch under test).
class UMars_AutoTest_Station_StationDestroyedReleasesTheOperator : UMars_AutoTestRig_Station
{
    private FCk_Handle_Station _Station;
    private FCk_Handle_Operator _Operator;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Station = AddStation(InHandle, FMars_Station_Spec());
        _Operator = AddOperator(InHandle);

        _Station.BindTo_OnReserved(FMars_Delegate_Station_OnReserved(this, n"OnReserved"));
        _Station.BindTo_OnReleased(FMars_Delegate_Station_OnReleased(this, n"OnReleased"));

        Add_Step("reserve for the operator", n"Step_Reserve");
        Add_Step_WaitUntil("the station is reserved", n"Check_Reserved", 0, 0);
        Add_Step("the operator holds the station; destroy the station entity", n"Step_DestroyStation");
        Add_Step_WaitUntil("the station is released", n"Check_Released", 0, 0);
        Add_Step("the release was StationDestroyed and the operator is free", n"Step_AssertReleased");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Reserve(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Valid(_Station, "utils_station::Add composed the station");
        _Station.Request_Reserve(FMars_Request_Station_Reserve(_Operator));
    }

    UFUNCTION()
    private void Step_DestroyStation(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Station.Get_IsOperatedBy(_Operator), "the station names the operator");
        Assert_True(_Operator.Get_Station() == _Station, "the operator's back-ref names the station");

        utils_entity_lifetime::Request_DestroyEntity(_Station);
    }

    UFUNCTION()
    private void Step_AssertReleased(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Released.Num(), 1, "OnReleased fired once");
        if (_Released.Num() == 1)
        {
            Assert_True(_Released[0] == _Operator, "OnReleased carries the operator");
            Assert_True(_ReleaseReasons[0] == EMars_Station_ReleaseReason::StationDestroyed,
                f"the release reason is StationDestroyed (got {_ReleaseReasons[0] :n})");
        }

        Assert_False(_Operator.Get_IsOperating(), "the operator's back-ref is cleared");
    }
}
