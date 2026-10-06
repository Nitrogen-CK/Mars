// Releases are scoped: with operator A holding the station, a release naming operator B (a rejected or stale caller) is
// a no-op - no OnReleased, A keeps it. A release naming A frees the station with OnReleased(A, OperatorRequested) and
// clears both ends of the link.
class UMars_AutoTest_Station_ScopedReleaseKeepsHolder : UMars_AutoTestRig_Station
{
    private FCk_Handle_Station _Station;
    private FCk_Handle_Operator _OperatorA;
    private FCk_Handle_Operator _OperatorB;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Station = AddStation(InHandle, FMars_Station_Spec());
        _OperatorA = AddOperator(InHandle);
        _OperatorB = AddOperator(InHandle);

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
    private void Step_ReserveA(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Valid(_Station, "utils_station::Add composed the station");
        _Station.Request_Reserve(FMars_Request_Station_Reserve(_OperatorA));
    }

    UFUNCTION()
    private void Step_ReleaseB(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Station.Get_IsOperatedBy(_OperatorA), "operator A holds the station");
        _Station.Request_Release(FMars_Request_Station_Release(_OperatorB, EMars_Station_ReleaseReason::OperatorRequested));
    }

    UFUNCTION()
    private void Step_AssertKeptThenReleaseA(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Released.Num(), 0, "the release scoped to operator B fired no OnReleased");
        Assert_True(_OperatorA == _Station.Get_Operator(), "operator A still holds the station");
        Assert_True(_OperatorA.Get_Station() == _Station, "operator A's back-ref is intact");

        _Station.Request_Release(FMars_Request_Station_Release(_OperatorA, EMars_Station_ReleaseReason::OperatorRequested));
    }

    UFUNCTION()
    private void Step_AssertReleased(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Released.Num(), 1, "OnReleased fired once");
        if (_Released.Num() == 1)
        {
            Assert_True(_OperatorA == _Released[0], "OnReleased carries operator A");
            Assert_True(_ReleaseReasons[0] == EMars_Station_ReleaseReason::OperatorRequested,
                f"the release reason is OperatorRequested (got {_ReleaseReasons[0] :n})");
        }

        Assert_False(_Station.Get_IsOperated(), "the station is free");
        Assert_False(_OperatorA.Get_IsOperating(), "operator A's back-ref is clear");
        Assert_False(_OperatorB.Get_IsOperating(), "operator B never operated");
    }
}
