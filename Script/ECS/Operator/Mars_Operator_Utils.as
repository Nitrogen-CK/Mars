// The operator half of the station link. No processor and no signals: the station arbiter keeps the back-ref, and
// consumers bind the held station's OnReserved / OnReleased.
namespace utils_operator
{
    FCk_Handle_Operator Add(FCk_Handle& InHandle)
    {
        InHandle.Add_Fragment(FMars_Feature_Operator());
        InHandle.Add_Fragment(FMars_Fragment_Operator());
        return InHandle.As_Operator();
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

mixin FCk_Handle_Station Get_Station(const FCk_Handle_Operator& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Operator).Station;
}

mixin bool Get_IsOperating(const FCk_Handle_Operator& Self)
{
    return ck::IsValid(Self.Get_Fragment(FMars_Fragment_Operator).Station);
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

// Asks the held station to release this operator (scoped to it); a no-op when not operating. The back-ref clears when the
// station drains the release, not here.
mixin void Request_Leave(FCk_Handle_Operator& Self)
{
    auto Station = Self.Get_Fragment(FMars_Fragment_Operator).Station;
    if (ck::Is_NOT_Valid(Station))
    { return; }

    Station.Request_Release(FMars_Request_Station_Release(FCk_Handle(Self), EMars_Station_ReleaseReason::OperatorRequested));
}
