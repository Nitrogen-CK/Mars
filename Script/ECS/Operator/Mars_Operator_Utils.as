// The operator half of the station link. No processor and no signals: the station arbiter keeps the back-ref, and
// consumers bind the held station's OnReserved / OnReleased.
namespace utils_operator
{
    // The back-ref replicates (unless it already arrived on a client's copy, where it stands).
    FCk_Handle_Operator Add(FCk_Handle& InHandle)
    {
        InHandle.Add_Fragment(FMars_Feature_Operator());
        if (InHandle.Has_Fragment(FMars_Fragment_Operator) == false)
        { InHandle.Add_Fragment(FMars_Fragment_Operator(), ECk_Replication::Replicates); }

        return InHandle.As_Operator();
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

mixin FCk_Handle_Station Get_Station(const FCk_Handle_Operator& Self)
{
    const auto& State = Self.Get_Fragment(FMars_Fragment_Operator);
    if (State.Occupancy == EMars_Station_Occupancy::Free)
    { return FCk_Handle_Station(); }

    return State.Station;
}

mixin bool Get_IsOperating(const FCk_Handle_Operator& Self)
{
    return ck::IsValid(Self.Get_Station());
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

// Asks the held station's authority to release this operator (its Act cue, scoped to it); a no-op when not operating. The
// back-ref clears when the authority drains the release, not here.
mixin void Request_Leave(FCk_Handle_Operator& Self, const FMars_Request_Operator_Leave& InRequest)
{
    auto Station = Self.Get_Station();
    if (ck::Is_NOT_Valid(Station))
    { return; }

    utils_station::Request_ActFor(Station, Self, EMars_Station_Verb::Leave);
}
