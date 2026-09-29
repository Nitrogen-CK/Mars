namespace utils_player_viewpoint
{
    FCk_Handle_PlayerViewpoint Add(FCk_Handle& InHandle, FTransform InInitialView, FMars_PlayerViewpoint_Spec InParams)
    {
        auto State = FMars_Fragment_PlayerViewpoint();
        State.Viewpoint = utils_target_point::Create(InHandle, InInitialView);
        utils_handle::Set_DebugName(State.Viewpoint, n"PlayerViewpoint");

        auto TraceSettings = FCk_Probe_RayCastPersistent_Settings(
            State.Viewpoint,
            FVector(InParams.InteractionTraceDistance, 0.0, 0.0),
            GameplayTag::MakeGameplayTagContainerFromTag(GameplayTags::Probe_Mars_Interact));
        TraceSettings.Set_TracePolicy(ECk_ProbeTrace_Policy::Multi);
        State.InteractionTrace = utils_probe_trace::Create_LineTrace_Persistent(TraceSettings);
        utils_handle::Set_DebugName(State.InteractionTrace, n"PlayerViewpoint.InteractionTrace");

        InHandle.Add_Fragment(FMars_Feature_PlayerViewpoint());
        InHandle.Add_Fragment(State);
        return InHandle.As_PlayerViewpoint();
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

mixin FCk_Handle_Transform Get_Viewpoint(const FCk_Handle_PlayerViewpoint& Self)
{
    return Self.Get_Fragment(FMars_Fragment_PlayerViewpoint).Viewpoint;
}

mixin FCk_Handle_ProbeTrace Get_InteractionTrace(const FCk_Handle_PlayerViewpoint& Self)
{
    return Self.Get_Fragment(FMars_Fragment_PlayerViewpoint).InteractionTrace;
}

//--------------------------------------------------------------------------------------------------------------------------
// Operations
//--------------------------------------------------------------------------------------------------------------------------

mixin void Request_SetView(FCk_Handle_PlayerViewpoint& Self, FVector InLocation, FRotator InRotation)
{
    auto Viewpoint = Self.Get_Viewpoint();
    auto Request = FCk_Request_Transform_SetLocationAndRotation(InLocation, InRotation);
    Request.Set_LocalWorld(ECk_LocalWorld::World);
    Viewpoint.Request_SetLocationAndRotation(Request);
}
