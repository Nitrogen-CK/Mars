// The navigator's request drain. A MoveTo resolves its route once, here: a provider route, a straight line when no
// provider covers the start or its ground is not built yet, or Failed(NoPath). Only the last queued MoveTo is resolved,
// so a superseded one never queries a path or fails. The state is fully written before any broadcast.
class UMars_Processor_SurfaceNavigator_HandleRequests : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Fragment_SurfaceNavigator_Requests;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_SurfaceNavigator);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_Fragment_SurfaceNavigator_Requests& InRequests)
    {
        auto Self = InHandle.As_SurfaceNavigator();

        TArray<FMars_Request_SurfaceNavigator_Stop> StopRequests = InRequests.StopRequests;
        TArray<FMars_Request_SurfaceNavigator_MoveTo> MoveToRequests = InRequests.MoveToRequests;

        // InRequests is invalid past this line; removing before broadcasting lets re-entrant requests survive.
        Self.Request_TryRemove(FMars_Fragment_SurfaceNavigator_Requests);

        // Request_Stop cancelled every MoveTo queued before it, so Stop -> last MoveTo is arrival order.
        if (StopRequests.Num() > 0)
        { HandleStop(Self); }

        if (MoveToRequests.Num() > 0)
        { HandleMoveTo(Self, MoveToRequests.Last()); }
    }

    private void HandleStop(FCk_Handle_SurfaceNavigator& InSelf)
    {
        auto& State = InSelf.Get_Fragment(FMars_Fragment_SurfaceNavigator);
        ClearSteering(State);
        State.Status = EMars_SurfaceNavigator_Status::Idle;
        State.FailReason = EMars_SurfaceNavigator_FailReason::None;
        State.Route.Waypoints.Empty();
        State.Route.WaypointIndex = 0;
    }

    private void HandleMoveTo(FCk_Handle_SurfaceNavigator& InSelf, FMars_Request_SurfaceNavigator_MoveTo InRequest)
    {
        const auto Spec = InSelf.Get_Spec();
        const auto Start = utils_transform::Get_EntityCurrentLocation(InSelf.As_Transform());

        auto Query = FCk_NavSurface_PathQuery(Start, InRequest.Goal);
        Query.Set_AgentRadiusUu(Spec.AgentRadius);
        const auto Result = utils_nav_surface::Try_FindPathSync(Query);
        const auto Status = Result.Get_Status();

        auto Route = FMars_SurfaceNavigator_Route();
        Route.Goal = InRequest.Goal;

        if (Status == ECk_NavSurface_QueryStatus::Success)
        {
            Route.PathMode = EMars_SurfaceNavigator_PathMode::Provider;
            Route.Waypoints = Result.Get_Waypoints();
            if (Route.Waypoints.Num() == 0 || (Route.Waypoints.Last() - InRequest.Goal).Size2D() > Spec.AcceptanceRadius)
            { Route.Waypoints.Add(InRequest.Goal); }
        }
        else if (Status == ECk_NavSurface_QueryStatus::NoProvider || Status == ECk_NavSurface_QueryStatus::Unbuilt)
        {
            Route.PathMode = EMars_SurfaceNavigator_PathMode::StraightLine;
            Route.Waypoints.Add(InRequest.Goal);
        }
        else
        {
            auto& FailedState = InSelf.Get_Fragment(FMars_Fragment_SurfaceNavigator);
            ClearSteering(FailedState);
            FailedState.Status = EMars_SurfaceNavigator_Status::Failed;
            FailedState.FailReason = EMars_SurfaceNavigator_FailReason::NoPath;
            FailedState.Route = Route;

            ck::Trace(f"[SurfaceNavigator] [{InSelf.ToString()}] no path to [{InRequest.Goal.ToString()}]: [{Status :n}]");

            if (InSelf.Has_Fragment(FMars_Fragment_SurfaceNavigator_Signals))
            { InSelf.Get_Fragment(FMars_Fragment_SurfaceNavigator_Signals).OnFailed.Broadcast(InSelf, InRequest.Goal, EMars_SurfaceNavigator_FailReason::NoPath); }
            return;
        }

        auto& State = InSelf.Get_Fragment(FMars_Fragment_SurfaceNavigator);
        State.Status = EMars_SurfaceNavigator_Status::Moving;
        State.FailReason = EMars_SurfaceNavigator_FailReason::None;
        State.Route = Route;
        State.Watchdog.StuckTimer = 0.0f;
        State.Watchdog.StuckAnchor = Start;
        // The tick's first steer always goes out, whatever was steered before this move.
        State.Steering.Speed.Reset();
    }

    // A zero steer always goes out (the tick processor dedupes only non-zero steering).
    private void ClearSteering(FMars_Fragment_SurfaceNavigator& InOutState)
    {
        InOutState.Steering.Direction = FVector::ZeroVector;
        InOutState.Steering.Speed = TOptional<float32>(0.0f);
        utils_surface_motion::Request_Steering(InOutState.Motion, FCk_Request_SurfaceMotion_Steering(FVector::ZeroVector, 0.0f));
    }
}
