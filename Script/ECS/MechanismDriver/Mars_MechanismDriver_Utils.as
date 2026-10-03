namespace utils_mechanism_driver
{
    FCk_Handle_MechanismDriver Add(FCk_Handle& InHandle)
    {
        InHandle.Add_Fragment(FMars_Feature_MechanismDriver());
        InHandle.Add_Fragment(FMars_Fragment_MechanismDriver());
        return InHandle.As_MechanismDriver();
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

mixin const TSet<FCk_Handle_MechanismSource>& Get_Sources(const FCk_Handle_MechanismDriver& Self)
{
    return Self.Get_Fragment(FMars_Fragment_MechanismDriver).Sources;
}

mixin const TSet<FCk_Handle_MechanismSink>& Get_Sinks(const FCk_Handle_MechanismDriver& Self)
{
    return Self.Get_Fragment(FMars_Fragment_MechanismDriver).Sinks;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

mixin void Request_TrackSource(FCk_Handle_MechanismDriver& Self, const FMars_Request_MechanismDriver_TrackSource& InRequest)
{
    if (ck::EnsureIfNot(ck::IsValid(InRequest.Source), f"[MechanismDriver] [{Self.ToString()}] was asked to track an invalid source"))
    { return; }

    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_MechanismDriver_Requests);
    Requests.TrackSourceRequests.Add(InRequest);
}

mixin void Request_UntrackSource(FCk_Handle_MechanismDriver& Self, const FMars_Request_MechanismDriver_UntrackSource& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_MechanismDriver_Requests);
    Requests.UntrackSourceRequests.Add(InRequest);
}

mixin void Request_TrackSink(FCk_Handle_MechanismDriver& Self, const FMars_Request_MechanismDriver_TrackSink& InRequest)
{
    if (ck::EnsureIfNot(ck::IsValid(InRequest.Sink), f"[MechanismDriver] [{Self.ToString()}] was asked to track an invalid sink"))
    { return; }

    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_MechanismDriver_Requests);
    Requests.TrackSinkRequests.Add(InRequest);
}

mixin void Request_UntrackSink(FCk_Handle_MechanismDriver& Self, const FMars_Request_MechanismDriver_UntrackSink& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_MechanismDriver_Requests);
    Requests.UntrackSinkRequests.Add(InRequest);
}

mixin void Request_Recompute(FCk_Handle_MechanismDriver& Self)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_MechanismDriver_Requests);
    Requests.RecomputeRequests.Add(FMars_Request_MechanismDriver_Recompute());
}
