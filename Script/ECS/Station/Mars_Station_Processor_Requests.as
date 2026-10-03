// The station arbiter. Drains SetEngagement -> Release -> Reserve, each kind in arrival order, so a release and a reserve
// in one drain re-seat the station and the second of two same-drain reserves is rejected Occupied.
//
// It writes BOTH ends of the link: FMars_Fragment_Station.Operator here and FMars_Fragment_Operator.Station on the
// operator, in the same call. This is the one documented exception to "only a feature's processors write its fragments"
// (the Operator feature has no processor; its back-ref is the station's to keep): with both ends changing synchronously, a
// second station reserving the same operator in the same drain sees the first station's write and rejects
// AlreadyOperating, and two operators reserving one station see Operator and get Occupied.
//
// A reserve arms two destroy watches: the operator dying releases the station (OperatorLost), the station dying clears the
// operator's back-ref (StationDestroyed). Every release is cleared on both ends BEFORE OnReleased broadcasts.
class UMars_Processor_Station_HandleRequests : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Fragment_Station_Requests;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Station);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle,
                       FMars_Fragment_Station_Requests& InRequests,
                       FMars_Fragment_Station& InState)
    {
        auto Self = InHandle.As_Station();

        TArray<FMars_Request_Station_SetEngagement> SetEngagementRequests = InRequests.SetEngagementRequests;
        TArray<FMars_Request_Station_Release> ReleaseRequests = InRequests.ReleaseRequests;
        TArray<FMars_Request_Station_Reserve> ReserveRequests = InRequests.ReserveRequests;

        // InRequests is invalid past this line; removing before broadcasting lets re-entrant requests survive.
        Self.Request_TryRemove(FMars_Fragment_Station_Requests);

        for (const auto& Request : SetEngagementRequests)
        { InState.Engagement = Request.Engagement; }

        for (const auto& Request : ReleaseRequests)
        { HandleRelease(Self, InState, Request); }

        for (const auto& Request : ReserveRequests)
        { HandleReserve(Self, InState, Request); }
    }

    private void HandleReserve(FCk_Handle_Station& InStation, FMars_Fragment_Station& InState, const FMars_Request_Station_Reserve& InRequest)
    {
        auto Operator = InRequest.Operator;
        if (ck::Is_NOT_Valid(Operator))
        { return; }

        if (ck::EnsureIfNot(Operator.Is_Operator(),
            f"[Station] [{Operator.ToString()}] reserved [{InStation.ToString()}] without the Operator feature - compose utils_operator::Add first"))
        { return; }

        if (InState.Engagement == ECk_EnableDisable::Disable)
        {
            BroadcastRejected(InStation, Operator, EMars_Station_RejectReason::Disabled);
            return;
        }

        if (ck::IsValid(InState.Operator))
        {
            BroadcastRejected(InStation, Operator, EMars_Station_RejectReason::Occupied);
            return;
        }

        auto& OperatorState = Operator.Get_Fragment(FMars_Fragment_Operator);
        if (ck::IsValid(OperatorState.Station) && OperatorState.Station != InStation)
        {
            BroadcastRejected(InStation, Operator, EMars_Station_RejectReason::AlreadyOperating);
            return;
        }

        InState.Operator = Operator;
        OperatorState.Station = InStation;

        // Unbind first keeps each watch single across re-reserves.
        Operator.UnbindFrom_OnBeginDestroy(FCk_Delegate_OnBeginDestroy(this, n"OnOperatorBeginDestroy"));
        Operator.BindTo_OnBeginDestroy(FCk_Delegate_OnBeginDestroy(this, n"OnOperatorBeginDestroy"));

        InStation.H().UnbindFrom_OnBeginDestroy(FCk_Delegate_OnBeginDestroy(this, n"OnStationBeginDestroy"));
        InStation.H().BindTo_OnBeginDestroy(FCk_Delegate_OnBeginDestroy(this, n"OnStationBeginDestroy"));

        ck::Trace(f"[Station] [{InStation.ToString()}] reserved by [{Operator.ToString()}]");

        if (InStation.Has_Fragment(FMars_Fragment_Station_Signals))
        { InStation.Get_Fragment(FMars_Fragment_Station_Signals).OnReserved.Broadcast(InStation, Operator); }
    }

    // Scoped: a release naming anyone but the current holder is a no-op (a rejected or stale caller cannot evict them).
    private void HandleRelease(FCk_Handle_Station& InStation, FMars_Fragment_Station& InState, const FMars_Request_Station_Release& InRequest)
    {
        auto Operator = InState.Operator;
        if (ck::Is_NOT_Valid(Operator) || Operator != InRequest.Operator)
        { return; }

        if (Operator.Has_Fragment(FMars_Fragment_Operator))
        {
            auto& OperatorState = Operator.Get_Fragment(FMars_Fragment_Operator);
            if (OperatorState.Station == InStation)
            { OperatorState.Station = FCk_Handle_Station(); }
        }

        InState.Operator = FCk_Handle();

        Operator.UnbindFrom_OnBeginDestroy(FCk_Delegate_OnBeginDestroy(this, n"OnOperatorBeginDestroy"));
        InStation.H().UnbindFrom_OnBeginDestroy(FCk_Delegate_OnBeginDestroy(this, n"OnStationBeginDestroy"));

        ck::Trace(f"[Station] [{InStation.ToString()}] released by [{Operator.ToString()}] ({InRequest.Reason :n})");
        BroadcastReleased(InStation, Operator, InRequest.Reason);
    }

    UFUNCTION()
    private void OnOperatorBeginDestroy(FCk_Handle InOperator)
    {
        if (InOperator.Has_Fragment(FMars_Fragment_Operator) == false)
        { return; }

        auto OperatorEntity = InOperator;
        auto& OperatorState = OperatorEntity.Get_Fragment(FMars_Fragment_Operator);
        auto Station = OperatorState.Station;
        if (ck::Is_NOT_Valid(Station) || Station.Has_Fragment(FMars_Fragment_Station) == false)
        { return; }

        auto& StationState = Station.Get_Fragment(FMars_Fragment_Station);
        if (StationState.Operator != InOperator)
        { return; }

        OperatorState.Station = FCk_Handle_Station();
        StationState.Operator = FCk_Handle();

        Station.H().UnbindFrom_OnBeginDestroy(FCk_Delegate_OnBeginDestroy(this, n"OnStationBeginDestroy"));

        ck::Trace(f"[Station] [{Station.ToString()}] released: its operator [{InOperator.ToString()}] was destroyed");
        BroadcastReleased(Station, InOperator, EMars_Station_ReleaseReason::OperatorLost);
    }

    UFUNCTION()
    private void OnStationBeginDestroy(FCk_Handle InStation)
    {
        if (InStation.Has_Fragment(FMars_Fragment_Station) == false)
        { return; }

        auto StationEntity = InStation;
        auto& StationState = StationEntity.Get_Fragment(FMars_Fragment_Station);
        auto Operator = StationState.Operator;
        if (ck::Is_NOT_Valid(Operator))
        { return; }

        if (Operator.Has_Fragment(FMars_Fragment_Operator))
        {
            auto& OperatorState = Operator.Get_Fragment(FMars_Fragment_Operator);
            if (OperatorState.Station == InStation)
            { OperatorState.Station = FCk_Handle_Station(); }
        }

        StationState.Operator = FCk_Handle();
        Operator.UnbindFrom_OnBeginDestroy(FCk_Delegate_OnBeginDestroy(this, n"OnOperatorBeginDestroy"));

        auto Station = StationEntity.As_Station();
        ck::Trace(f"[Station] [{Station.ToString()}] destroyed while [{Operator.ToString()}] operated it");
        BroadcastReleased(Station, Operator, EMars_Station_ReleaseReason::StationDestroyed);
    }

    private void BroadcastRejected(FCk_Handle_Station& InStation, FCk_Handle InOperator, EMars_Station_RejectReason InReason)
    {
        ck::Trace(f"[Station] [{InStation.ToString()}] rejected [{InOperator.ToString()}] ({InReason :n})");

        if (InStation.Has_Fragment(FMars_Fragment_Station_Signals))
        { InStation.Get_Fragment(FMars_Fragment_Station_Signals).OnReserveRejected.Broadcast(InStation, InOperator, InReason); }
    }

    private void BroadcastReleased(FCk_Handle_Station& InStation, FCk_Handle InOperator, EMars_Station_ReleaseReason InReason)
    {
        if (InStation.Has_Fragment(FMars_Fragment_Station_Signals))
        { InStation.Get_Fragment(FMars_Fragment_Station_Signals).OnReleased.Broadcast(InStation, InOperator, InReason); }
    }
}
