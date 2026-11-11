// The station arbiter, on the authority only. Drains Release -> Reserve, each kind in arrival order (an Act joins its
// kind behind the direct requests: Leave as an OperatorRequested Release, Reserve as a Reserve), so a release and a
// reserve in one drain re-seat the station and the second of two same-drain reserves is rejected Occupied. A machine
// without authority drops every request: the answer replicates from the authority in the ledger.
//
// It writes BOTH ends of the link: FMars_Fragment_Station.Operator here and FMars_Fragment_Operator.Station on the
// operator, in the same call, and marks each replicated fragment dirty. This is the one documented exception to "only a
// feature's processors write its fragments" (the Operator feature has no processor; its back-ref is the station's to
// keep): with both ends changing synchronously, a second station reserving the same operator in the same drain sees the
// first station's write and rejects AlreadyOperating, and two operators reserving one station see Operator and get
// Occupied. A rejected reserve advances the ledger's refusal serial naming the operator; it never ensures (two machines
// racing for one station is legitimate).
//
// A reserve arms two destroy watches: the operator dying releases the station (OperatorLost), the station dying clears the
// operator's back-ref (StationDestroyed). Every release is cleared on both ends, and its serial advanced, BEFORE OnReleased
// broadcasts. A dying end is not marked dirty: its destruction replicates instead.
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

        TArray<FMars_Request_Station_Release> ReleaseRequests = InRequests.ReleaseRequests;
        TArray<FMars_Request_Station_Reserve> ReserveRequests = InRequests.ReserveRequests;
        TArray<FMars_Request_Station_Act> ActRequests = InRequests.ActRequests;

        // InRequests is invalid past this line; removing before broadcasting lets re-entrant requests survive.
        Self.Request_TryRemove(FMars_Fragment_Station_Requests);

        if (utils_net::Get_HasAuthority(InHandle) == false)
        { return; }

        for (const auto& Request : ActRequests)
        {
            if (Request.Verb == EMars_Station_Verb::Leave)
            { ReleaseRequests.Add(FMars_Request_Station_Release(Request.Operator, EMars_Station_ReleaseReason::OperatorRequested)); }
            else
            { ReserveRequests.Add(FMars_Request_Station_Reserve(Request.Operator)); }
        }

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

        // The holder re-reserving: nothing changes, and OnReserved answers it again.
        if (InState.Operator == Operator)
        {
            BroadcastReserved(InStation, Operator);
            return;
        }

        if (ck::IsValid(InState.Operator))
        {
            Reject(InStation, InState, Operator, EMars_Station_RejectReason::Occupied);
            return;
        }

        // Both ends are written together: an operator holding a station here holds another one.
        auto& OperatorState = Operator.Get_Fragment(FMars_Fragment_Operator);
        if (ck::IsValid(OperatorState.Station))
        {
            Reject(InStation, InState, Operator, EMars_Station_RejectReason::AlreadyOperating);
            return;
        }

        InState.Operator = Operator;
        InState.Occupancy = EMars_Station_Occupancy::Operated;
        OperatorState.Station = InStation;
        OperatorState.Occupancy = EMars_Station_Occupancy::Operated;
        InStation.H().Request_MarkReplicationDirty(FMars_Fragment_Station);
        Operator.Request_MarkReplicationDirty(FMars_Fragment_Operator);

        // Unbind first keeps each watch single across re-reserves.
        Operator.UnbindFrom_OnBeginDestroy(FCk_Delegate_OnBeginDestroy(this, n"OnOperatorBeginDestroy"));
        Operator.BindTo_OnBeginDestroy(FCk_Delegate_OnBeginDestroy(this, n"OnOperatorBeginDestroy"));

        InStation.H().UnbindFrom_OnBeginDestroy(FCk_Delegate_OnBeginDestroy(this, n"OnStationBeginDestroy"));
        InStation.H().BindTo_OnBeginDestroy(FCk_Delegate_OnBeginDestroy(this, n"OnStationBeginDestroy"));

        BroadcastReserved(InStation, Operator);
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
            {
                Clear_BackRef(OperatorState);
                Operator.Request_MarkReplicationDirty(FMars_Fragment_Operator);
            }
        }

        Record_Release(InState, InRequest.Reason);
        InStation.H().Request_MarkReplicationDirty(FMars_Fragment_Station);

        Operator.UnbindFrom_OnBeginDestroy(FCk_Delegate_OnBeginDestroy(this, n"OnOperatorBeginDestroy"));
        InStation.H().UnbindFrom_OnBeginDestroy(FCk_Delegate_OnBeginDestroy(this, n"OnStationBeginDestroy"));

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

        Clear_BackRef(OperatorState);
        Record_Release(StationState, EMars_Station_ReleaseReason::OperatorLost);
        Station.H().Request_MarkReplicationDirty(FMars_Fragment_Station);

        Station.H().UnbindFrom_OnBeginDestroy(FCk_Delegate_OnBeginDestroy(this, n"OnStationBeginDestroy"));

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
            {
                Clear_BackRef(OperatorState);
                Operator.Request_MarkReplicationDirty(FMars_Fragment_Operator);
            }
        }

        Record_Release(StationState, EMars_Station_ReleaseReason::StationDestroyed);
        Operator.UnbindFrom_OnBeginDestroy(FCk_Delegate_OnBeginDestroy(this, n"OnOperatorBeginDestroy"));

        auto Station = StationEntity.As_Station();
        BroadcastReleased(Station, Operator, EMars_Station_ReleaseReason::StationDestroyed);
    }

    private void Clear_BackRef(FMars_Fragment_Operator& InOperatorState)
    {
        InOperatorState.Station = FCk_Handle_Station();
        InOperatorState.Occupancy = EMars_Station_Occupancy::Free;
    }

    private void Record_Release(FMars_Fragment_Station& InState, EMars_Station_ReleaseReason InReason)
    {
        InState.Operator = FCk_Handle();
        InState.Occupancy = EMars_Station_Occupancy::Free;
        InState.LastReleaseReason = InReason;
        InState.ReleaseSerial += 1;
    }

    private void Reject(FCk_Handle_Station& InStation, FMars_Fragment_Station& InState, FCk_Handle InOperator,
                        EMars_Station_RejectReason InReason)
    {
        InState.RefusalSerial += 1;
        InState.LastRefusal = InReason;
        InState.LastRefused = InOperator;
        InStation.H().Request_MarkReplicationDirty(FMars_Fragment_Station);

        BroadcastRejected(InStation, InOperator, InReason);
    }

    private void BroadcastReserved(FCk_Handle_Station& InStation, FCk_Handle InOperator)
    {
        if (InStation.Has_Fragment(FMars_Fragment_Station_Signals))
        { InStation.Get_Fragment(FMars_Fragment_Station_Signals).OnReserved.Broadcast(InStation, InOperator); }
    }

    private void BroadcastRejected(FCk_Handle_Station& InStation, FCk_Handle InOperator, EMars_Station_RejectReason InReason)
    {
        if (InStation.Has_Fragment(FMars_Fragment_Station_Signals))
        { InStation.Get_Fragment(FMars_Fragment_Station_Signals).OnReserveRejected.Broadcast(InStation, InOperator, InReason); }
    }

    private void BroadcastReleased(FCk_Handle_Station& InStation, FCk_Handle InOperator, EMars_Station_ReleaseReason InReason)
    {
        if (InStation.Has_Fragment(FMars_Fragment_Station_Signals))
        { InStation.Get_Fragment(FMars_Fragment_Station_Signals).OnReleased.Broadcast(InStation, InOperator, InReason); }
    }
}
