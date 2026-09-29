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

mixin void Request_TrackSource(FCk_Handle_MechanismDriver& Self, FCk_Handle_MechanismSource InSource)
{
    if (ck::Is_NOT_Valid(InSource))
    { return; }

    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_MechanismDriver_Requests);
    Requests.TrackSources.Add(InSource);
}

mixin void Request_UntrackSource(FCk_Handle_MechanismDriver& Self, FCk_Handle_MechanismSource InSource)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_MechanismDriver_Requests);
    Requests.UntrackSources.Add(InSource);
}

mixin void Request_TrackSink(FCk_Handle_MechanismDriver& Self, FCk_Handle_MechanismSink InSink)
{
    if (ck::Is_NOT_Valid(InSink))
    { return; }

    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_MechanismDriver_Requests);
    Requests.TrackSinks.Add(InSink);
}

mixin void Request_UntrackSink(FCk_Handle_MechanismDriver& Self, FCk_Handle_MechanismSink InSink)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_MechanismDriver_Requests);
    Requests.UntrackSinks.Add(InSink);
}

// Coalesces: any number of calls before the drain produce one full recompute.
mixin void Request_Recompute(FCk_Handle_MechanismDriver& Self)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_MechanismDriver_Requests);
    Requests.Recompute = true;
}
