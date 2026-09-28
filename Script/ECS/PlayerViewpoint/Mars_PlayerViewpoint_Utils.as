namespace utils_player_viewpoint
{
    FCk_Handle_PlayerViewpoint Add(FCk_Handle& InHandle, FTransform InInitialView, FMars_Fragment_PlayerViewpoint_Params InParams)
    {
        auto Current = FMars_Fragment_PlayerViewpoint_Current();
        Current.Viewpoint = utils_target_point::Create(InHandle, InInitialView);
        utils_handle::Set_DebugName(Current.Viewpoint, n"PlayerViewpoint");

        auto TraceSettings = FCk_Probe_RayCastPersistent_Settings(
            Current.Viewpoint,
            FVector(InParams.InteractionTraceDistance, 0.0, 0.0),
            GameplayTag::MakeGameplayTagContainerFromTag(GameplayTags::Probe_Mars_Interact));
        TraceSettings.Set_TracePolicy(ECk_ProbeTrace_Policy::Multi);
        Current.InteractionTrace = utils_probe_trace::Create_LineTrace_Persistent(TraceSettings);
        utils_handle::Set_DebugName(Current.InteractionTrace, n"PlayerViewpoint.InteractionTrace");

        InHandle.Add_Fragment(FMars_Feature_PlayerViewpoint());
        InHandle.Add_Fragment(InParams);
        InHandle.Add_Fragment(Current);
        return InHandle.As_PlayerViewpoint();
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

mixin FCk_Handle_Transform Get_Viewpoint(const FCk_Handle_PlayerViewpoint& Self)
{
    return Self.Get_Fragment(FMars_Fragment_PlayerViewpoint_Current).Viewpoint;
}

mixin FCk_Handle_ProbeTrace Get_InteractionTrace(const FCk_Handle_PlayerViewpoint& Self)
{
    return Self.Get_Fragment(FMars_Fragment_PlayerViewpoint_Current).InteractionTrace;
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
