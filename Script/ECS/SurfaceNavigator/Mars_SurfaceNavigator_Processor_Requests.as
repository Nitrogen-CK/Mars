// The navigator's request drain. Applies Stop -> MoveTo, each kind in arrival order (so a Stop and a MoveTo in one drain
// leave the MoveTo running, and the last MoveTo stands).
//
// MoveTo resolves its route here, once: utils_nav_surface::Try_FindPathSync from the body's current location.
//   Success              -> the provider's waypoints (the goal appended when the route stops short of it), PathMode Provider
//   NoProvider / Unbuilt -> one waypoint, the goal, PathMode StraightLine (no field covers the start, or not baked yet)
//   NoSurface / Blocked  -> Failed(NoPath), steering cleared, OnFailed
// The tick processor follows the waypoints; the state is fully written before any broadcast.
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

        // Swap-and-pop - InRequests is dead past this line. Removing before broadcasting lets re-entrant requests survive.
        Self.Request_TryRemove(FMars_Fragment_SurfaceNavigator_Requests);

        if (StopRequests.Num() > 0)
        { HandleStop(Self); }

        for (const auto& Request : MoveToRequests)
        { HandleMoveTo(Self, Request); }
    }

    private void HandleStop(FCk_Handle_SurfaceNavigator& InSelf)
    {
        auto& State = InSelf.Get_Fragment(FMars_Fragment_SurfaceNavigator);
        utils_surface_navigator::Steer(State, FVector::ZeroVector, 0.0f);
        State.Status = EMars_SurfaceNavigator_Status::Idle;
        State.FailReason = EMars_SurfaceNavigator_FailReason::None;
        State.Route.Waypoints.Empty();
        State.Route.WaypointIndex = 0;
    }

    private void HandleMoveTo(FCk_Handle_SurfaceNavigator& InSelf, const FMars_Request_SurfaceNavigator_MoveTo& InRequest)
    {
        const auto Spec = InSelf.Get_Spec();
        const auto Motion = InSelf.Get_Motion();
        const auto Start = utils_transform::Get_EntityCurrentLocation(utils_transform::DoCastChecked(FCk_Handle(Motion)));

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
            utils_surface_navigator::Steer(FailedState, FVector::ZeroVector, 0.0f);
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
        State.Steering.Speed = -1.0f;
    }
}
