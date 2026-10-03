// Follows a Moving navigator's waypoints (horizontal distances only) and runs the stuck watchdog. Steering goes through
// SurfaceMotion only; the navigator never writes the transform.
class UMars_Processor_SurfaceNavigator_Tick : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_SurfaceNavigator);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_Fragment_SurfaceNavigator& InState)
    {
        if (InState.Status != EMars_SurfaceNavigator_Status::Moving)
        { return; }

        auto Self = InHandle.As_SurfaceNavigator();
        const auto& Spec = InHandle.Get_Fragment(FMars_Fragment_SurfaceNavigator_Params).Spec;
        const auto Location = utils_transform::Get_EntityCurrentLocation(InHandle.As_Transform());

        auto ToTarget = FVector::ZeroVector;
        auto& Route = InState.Route;
        while (Route.WaypointIndex < Route.Waypoints.Num())
        {
            ToTarget = Route.Waypoints[Route.WaypointIndex] - Location;
            ToTarget.Z = 0.0;
            if (ToTarget.Size() > Spec.AcceptanceRadius)
            { break; }

            ++Route.WaypointIndex;
        }

        if (Route.WaypointIndex >= Route.Waypoints.Num())
        {
            Steer(InState, FVector::ZeroVector, 0.0f);
            InState.Status = EMars_SurfaceNavigator_Status::Arrived;
            const auto Goal = Route.Goal;

            if (Self.Has_Fragment(FMars_Fragment_SurfaceNavigator_Signals))
            { Self.Get_Fragment(FMars_Fragment_SurfaceNavigator_Signals).OnArrived.Broadcast(Self, Goal); }
            return;
        }

        Steer(InState, ToTarget.GetSafeNormal(), Spec.Speed);

        auto& Watchdog = InState.Watchdog;
        if ((Location - Watchdog.StuckAnchor).Size2D() > Spec.StuckDistance)
        {
            Watchdog.StuckAnchor = Location;
            Watchdog.StuckTimer = 0.0f;
            return;
        }

        Watchdog.StuckTimer += float32(InDeltaT.Get_Seconds());
        if (Watchdog.StuckTimer <= Spec.StuckSeconds)
        { return; }

        Steer(InState, FVector::ZeroVector, 0.0f);
        InState.Status = EMars_SurfaceNavigator_Status::Failed;
        InState.FailReason = EMars_SurfaceNavigator_FailReason::Stuck;
        const auto FailedGoal = Route.Goal;

        ck::Trace(f"[SurfaceNavigator] [{Self.ToString()}] stuck at [{Location.ToString()}] on the way to [{FailedGoal.ToString()}]");

        if (Self.Has_Fragment(FMars_Fragment_SurfaceNavigator_Signals))
        { Self.Get_Fragment(FMars_Fragment_SurfaceNavigator_Signals).OnFailed.Broadcast(Self, FailedGoal, EMars_SurfaceNavigator_FailReason::Stuck); }
    }

    // Steering is sticky in SurfaceMotion, so a non-zero steer goes out only when the direction turns by more than ~1
    // degree or the speed changes; a zero steer always goes out.
    private void Steer(FMars_Fragment_SurfaceNavigator& InOutState, FVector InDirection, float32 InSpeed)
    {
        const auto IsZero = InSpeed <= 0.0f;
        const auto Direction = IsZero ? FVector::ZeroVector : InDirection;
        const auto Speed = IsZero ? 0.0f : InSpeed;

        const auto& Last = InOutState.Steering;
        if (IsZero == false && Last.Speed.IsSet() && Speed == Last.Speed.GetValue() && Direction.DotProduct(Last.Direction) >= 0.9998)
        { return; }

        InOutState.Steering.Direction = Direction;
        InOutState.Steering.Speed = TOptional<float32>(Speed);
        utils_surface_motion::Request_Steering(InOutState.Motion, FCk_Request_SurfaceMotion_Steering(Direction, Speed));
    }
}
