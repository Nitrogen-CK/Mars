// Root (on the rat's root, initial = Alive; context = the root)
// |- Alive   ->Dead [IsDead: ByteAttribute.Mars.Monster.Dead == 1]     tasks: Behave
// `- Dead    (sink)                                                    tasks: Dead (stops the navigator; the kernel releases the loot)
//
// The control layer over the kernel. Behave reads the rat (phase, clocks, route answers, threat), its raid (target view,
// lease, chefs) and enqueues requests only - Advance, MoveTo, Stop, Claim on the rat and GrantLease on the raid; the kernel's
// drain validates every edge. One task drives the whole phase table because the phase is kernel state (tests and the
// assembly read it headless); the edge table (utils_pantry_rat::Get_IsAllowedAdvance) is what keeps a loaded thief fleeing.
//   Emerge        MoveTo(OutsideStand, Creep)                          -> Observe on arrival or a failed route
//   Observe       pause to PauseDeadline; threat -> AvoidPlayer; no target for NoTargetReturnSeconds -> ReturnEmpty;
//                 target guarded / leased elsewhere -> WatchGuarded; away from the work point -> BoundApproach; at it: ask
//                 for the lease, then -> Inspect with it
//   BoundApproach one burst (BurstsPlanned bounds along the provider route to the work point, never ending inside a chef's
//                 avoidance) -> Observe; threat -> AvoidPlayer; guarded -> WatchGuarded
//   WatchGuarded  hold; threat -> AvoidPlayer; clear -> Observe; no target -> ReturnEmpty
//   AvoidPlayer   MoveTo(the ring point farthest from the threat, clear of every chef) -> Observe; none: hold, rescore
//   Inspect       InspectSeconds; lease lost / guarded / threat -> Observe            -> ClaimTell
//   ClaimTell     RummageSeconds; same aborts; then re-check the guard on current transforms -> Claim(token)
//   FleeWithLoot  one burst (2..3 bounds) toward the flee goal (ring scoring, den mouths kept out) -> FleePause; none -> FleeCornered
//   FleePause     to PauseDeadline -> FleeWithLoot
//   FleeCornered  every DecisionIntervalSeconds, a flee goal -> FleeWithLoot
//   ReturnEmpty   MoveTo(ReturnAdmission), then MoveTo(Inside, Creep) through the arch -> DenEnter; a target -> Observe;
//                 threat -> AvoidPlayer
//   DenEnter      committed: the kernel crouches (DenCrouchSeconds), fades 1 -> 0 (ReturnFadeSeconds), hides the rat
//                 (DormantInDen, FadeAlpha back to 1 while hidden) and asks the den to admit it; the raid retires it

namespace utils_pantry_rat
{
    // The rat works a slot once its root is this close (planar) to the slot's work point.
    const float64 k_WorkReachCm = 40.0;

    // A flee or avoid candidate nearer than this to the rat is no move at all.
    const float64 k_MinMoveCm = 150.0;

    // A flee goal the rat is this close to is spent: the next burst picks a new one.
    const float64 k_FleeGoalSpentCm = 60.0;

    // A DenEnter the den has not answered in this long goes back to Observe.
    const float32 k_DenAnswerSeconds = 2.0f;

    // The step along a route at which its separation from the chefs is sampled.
    const float64 k_RouteSampleCm = 50.0;

    // The best flee goal for a loaded rat (DESIGN_TECH_SPEC section 8): a ring point (Make_FleeRing over its raid's bounds,
    // the playable floor) at least k_MinMoveCm away, LoadedPortalKeepOutCm from every den portal at the goal and along the
    // provider route (which must answer Success - never a den mouth, never a straight line), scored by the ROUTE's
    // separation from the nearest chef: the closest the rat would come to any chef on its floor anywhere along the route
    // to the goal (with no chef, the goal's distance from the rat). A goal behind the chaser therefore loses to one that
    // turns away from it. Ties go to the lower ring index. Bounded: one provider query per candidate that could still win.
    TOptional<FVector> Pick_FleeGoal(const FCk_Handle_PantryRat& InRat)
    {
        const auto Raid = InRat.Get_Raid();
        if (ck::Is_NOT_Valid(Raid))
        { return TOptional<FVector>(); }

        const auto Tuning = InRat.Get_Tuning();
        const auto Here = InRat.Get_Location();
        const auto Chefs = Raid.Get_Chefs();
        const auto Portals = Get_PortalPoints(Raid);
        const auto KeepOut = float64(Tuning.Routing.LoadedPortalKeepOutCm);
        const auto Ring = utils_pantry_raid::Make_FleeRing(Raid.Get_BoundsWorld(), Tuning.Routing, Here.Z);

        auto Best = TOptional<FVector>();
        auto BestScore = 0.0;
        for (const auto& Point : Ring)
        {
            if (utils_pantry_raid::Get_PlanarDistance(Point, Here) < k_MinMoveCm || Get_PortalClearance(Portals, Point) < KeepOut)
            { continue; }

            // The goal's own separation bounds the route's from above: a candidate that cannot win is never queried.
            const auto GoalScore = Get_Separation(Chefs, Point, Here, Tuning.Guard.SameFloorCm);
            if (Best.IsSet() && GoalScore <= BestScore)
            { continue; }

            auto Waypoints = TArray<FVector>();
            if (Get_IsRouteClear(Here, Point, Portals, KeepOut, Waypoints) == false)
            { continue; }

            const auto Score = Math::Min(GoalScore, Get_RouteSeparation(Chefs, Here, Waypoints, Point, Tuning.Guard.SameFloorCm));
            if (Best.IsSet() && Score <= BestScore)
            { continue; }

            Best = TOptional<FVector>(Point);
            BestScore = Score;
        }

        return Best;
    }

    // The closest any chef on the rat's floor comes to the route InFrom -> InWaypoints -> InGoal (sampled every
    // k_RouteSampleCm, the start excluded); a large number with no chef.
    float64 Get_RouteSeparation(const TArray<FMars_PantryRaid_ChefSnapshot>& InChefs, FVector InFrom, const TArray<FVector>& InWaypoints,
                                FVector InGoal, float32 InSameFloorCm)
    {
        auto Points = InWaypoints;
        if (Points.Num() == 0 || (Points.Last() - InGoal).Size2D() > 1.0)
        { Points.Add(InGoal); }

        auto Nearest = 1.0e9;
        auto Previous = InFrom;
        for (const auto& Point : Points)
        {
            const auto Length = (Point - Previous).Size2D();
            const auto Steps = Math::Max(1, Math::CeilToInt(Length / k_RouteSampleCm));
            for (int32 Step = 1; Step <= Steps; ++Step)
            {
                const auto Sample = Previous + (Point - Previous) * (float64(Step) / float64(Steps));
                const auto Chef = utils_pantry_raid::Get_NearestChef(InChefs, Sample, InSameFloorCm);
                if (ck::IsValid(Chef.Root))
                { Nearest = Math::Min(Nearest, utils_pantry_raid::Get_PlanarDistance(Chef.Location, Sample)); }
            }

            Previous = Point;
        }

        return Nearest;
    }

    // The best safe point from the rat's threat: a ring point at least k_MinMoveCm away, AvoidExitCm clear of every chef,
    // on a Success route, farthest from the threat; ties go to the lower index.
    TOptional<FVector> Pick_AvoidGoal(const FCk_Handle_PantryRat& InRat)
    {
        const auto Raid = InRat.Get_Raid();
        if (ck::Is_NOT_Valid(Raid))
        { return TOptional<FVector>(); }

        const auto Tuning = InRat.Get_Tuning();
        const auto Here = InRat.Get_Location();
        const auto Chefs = Raid.Get_Chefs();
        const auto Ring = utils_pantry_raid::Make_FleeRing(Raid.Get_BoundsWorld(), Tuning.Routing, Here.Z);
        const auto NoPortals = TArray<FVector>();

        auto Best = TOptional<FVector>();
        auto BestScore = 0.0;
        for (const auto& Point : Ring)
        {
            if (utils_pantry_raid::Get_PlanarDistance(Point, Here) < k_MinMoveCm
                || utils_pantry_raid::Get_IsAnyChefWithin(Chefs, Point, Tuning.Guard.AvoidExitCm, Tuning.Guard.SameFloorCm))
            { continue; }

            const auto Score = Get_Separation(Chefs, Point, Here, Tuning.Guard.SameFloorCm);
            if (Best.IsSet() && Score <= BestScore)
            { continue; }

            if (Get_IsRouteClear(Here, Point, NoPortals, 0.0) == false)
            { continue; }

            Best = TOptional<FVector>(Point);
            BestScore = Score;
        }

        return Best;
    }

    // A candidate's distance from the nearest chef on its floor; with no chef, its distance from the rat.
    float64 Get_Separation(const TArray<FMars_PantryRaid_ChefSnapshot>& InChefs, FVector InPoint, FVector InHere, float32 InSameFloorCm)
    {
        const auto Nearest = utils_pantry_raid::Get_NearestChef(InChefs, InPoint, InSameFloorCm);
        if (ck::IsValid(Nearest.Root))
        { return utils_pantry_raid::Get_PlanarDistance(Nearest.Location, InPoint); }

        return utils_pantry_raid::Get_PlanarDistance(InHere, InPoint);
    }

    // The provider answers Success from InFrom to InTo, and every waypoint keeps InKeepOut from InPortals.
    bool Get_IsRouteClear(FVector InFrom, FVector InTo, const TArray<FVector>& InPortals, float64 InKeepOut)
    {
        auto Waypoints = TArray<FVector>();
        return Get_IsRouteClear(InFrom, InTo, InPortals, InKeepOut, Waypoints);
    }

    // As above; OutWaypoints receives the provider's route.
    bool Get_IsRouteClear(FVector InFrom, FVector InTo, const TArray<FVector>& InPortals, float64 InKeepOut, TArray<FVector>& OutWaypoints)
    {
        auto Query = FCk_NavSurface_PathQuery(InFrom, InTo);
        Query.Set_AgentRadiusUu(k_AgentRadius);
        const auto Result = utils_nav_surface::Try_FindPathSync(Query);
        if (Result.Get_Status() != ECk_NavSurface_QueryStatus::Success)
        { return false; }

        OutWaypoints = Result.Get_Waypoints();
        for (const auto& Waypoint : OutWaypoints)
        {
            if (Get_PortalClearance(InPortals, Waypoint) < InKeepOut)
            { return false; }
        }

        return true;
    }

    // The point one burst (InBounds bounds at InSpeed) along the provider route from InFrom to InGoal; unset when the provider
    // has no route.
    TOptional<FVector> Get_BurstGoal(FVector InFrom, FVector InGoal, float64 InBurstLength)
    {
        auto Query = FCk_NavSurface_PathQuery(InFrom, InGoal);
        Query.Set_AgentRadiusUu(k_AgentRadius);
        const auto Result = utils_nav_surface::Try_FindPathSync(Query);
        if (Result.Get_Status() != ECk_NavSurface_QueryStatus::Success)
        { return TOptional<FVector>(); }

        auto Waypoints = Result.Get_Waypoints();
        if (Waypoints.Num() == 0 || (Waypoints.Last() - InGoal).Size2D() > 1.0)
        { Waypoints.Add(InGoal); }

        auto Point = utils_pantry_raid::Get_PointAlongPath(InFrom, Waypoints, InBurstLength);
        Point.Z = InFrom.Z;
        return TOptional<FVector>(Point);
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Conditions
//--------------------------------------------------------------------------------------------------------------------------

class UMars_SmCondition_PantryRat_IsDead : UMars_SmCondition_ByteAttribute
{
    default AttributeTag = GameplayTags::ByteAttribute_Mars_Monster_Dead;
    default Comparison._Operator = ECk_ComparisonOperators::EqualTo;
    default Comparison._RHS = 1;
}

//--------------------------------------------------------------------------------------------------------------------------
// States
//--------------------------------------------------------------------------------------------------------------------------

class UMars_SmState_PantryRat_Alive : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToDead = AddTransition(InHandle, UMars_SmState_PantryRat_Dead);
        AddCondition(ToDead, UMars_SmCondition_PantryRat_IsDead);

        AddTask(InHandle, UMars_SmTask_PantryRat_Behave);
    }
}

class UMars_SmState_PantryRat_Dead : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        AddTask(InHandle, UMars_SmTask_PantryRat_Dead);
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Tasks
//--------------------------------------------------------------------------------------------------------------------------

class UMars_SmTask_PantryRat_Dead : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::EnterExitOnly;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        auto Rat = ck::Ctx(InHandle).As_PantryRat(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(Rat))
        { Rat.Request_Stop(FMars_Request_PantryRat_Stop()); }
    }
}

class UMars_SmTask_PantryRat_Behave : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::Tick;

    private FCk_Handle_PantryRat _Rat;
    // The loaded rat's current far flee goal (kept across bursts until spent).
    private TOptional<FVector> _FleeGoal;
    // The rat's clock at which a held open question (cornered, a cautious avoid hold) is decided again.
    private float32 _NextDecisionAt = 0.0f;
    // ReturnEmpty's second leg (ReturnAdmission -> the den's Inside stand) was issued.
    private bool _HomeLegInside = false;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        _Rat = ck::Ctx(InHandle).As_PantryRat(ECk_SanityCheck::UnChecked);
        _FleeGoal.Reset();
        _NextDecisionAt = 0.0f;
        _HomeLegInside = false;
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        _Rat = FCk_Handle_PantryRat();
    }

    UFUNCTION(BlueprintOverride)
    ECk_SmTaskResult DoTick(FCk_Handle_SmTask InHandle, FCk_Time InDeltaT, ECk_Sm_NetContext InNetContext)
    {
        // Requests still queued: the drain answers them before the next decision, so nothing is asked twice.
        if (ck::Is_NOT_Valid(_Rat) || _Rat.Has_Fragment(FMars_Fragment_PantryRat_Requests) || _Rat.Get_IsDead())
        { return ECk_SmTaskResult::Running; }

        const auto Phase = _Rat.Get_Phase();
        if (Phase == EMars_PantryRat_Phase::Emerge)
        { Tick_Emerge(); }
        else if (Phase == EMars_PantryRat_Phase::Observe)
        { Tick_Observe(); }
        else if (Phase == EMars_PantryRat_Phase::BoundApproach)
        { Tick_BoundApproach(); }
        else if (Phase == EMars_PantryRat_Phase::WatchGuarded)
        { Tick_WatchGuarded(); }
        else if (Phase == EMars_PantryRat_Phase::AvoidPlayer)
        { Tick_AvoidPlayer(); }
        else if (Phase == EMars_PantryRat_Phase::Inspect || Phase == EMars_PantryRat_Phase::ClaimTell)
        { Tick_Claiming(Phase); }
        else if (Phase == EMars_PantryRat_Phase::FleeWithLoot)
        { Tick_FleeWithLoot(); }
        else if (Phase == EMars_PantryRat_Phase::FleePause)
        { Tick_FleePause(); }
        else if (Phase == EMars_PantryRat_Phase::FleeCornered)
        { Tick_FleeCornered(); }
        else if (Phase == EMars_PantryRat_Phase::ReturnEmpty)
        { Tick_ReturnEmpty(); }
        else if (Phase == EMars_PantryRat_Phase::DenEnter)
        { Tick_DenEnter(); }

        return ECk_SmTaskResult::Running;
    }

    //----------------------------------------------------------------------------------------------------------------------

    private void Advance(EMars_PantryRat_Phase InTo)
    {
        _Rat.Request_Advance(FMars_Request_PantryRat_Advance(_Rat.Get_Phase(), InTo));
    }

    // No move was asked in the current phase yet (or the last one was stopped).
    private bool Get_NeedsRoute() const
    {
        const auto Route = _Rat.Get_Route();
        return Route.IssuedIn != _Rat.Get_Phase() || Route.Status == EMars_PantryRat_RouteStatus::Idle;
    }

    private TOptional<FMars_PantryRaid_TargetView> Get_TargetView() const
    {
        return _Rat.TryGet_TargetView();
    }

    private FVector Get_WorkPoint(const FMars_PantryRaid_TargetView& InView) const
    {
        return utils_pantry_raid::Get_WorkPoint(InView.SlotLocation, InView.PackLocation, _Rat.Get_Tuning().Theft.WorkStandoffCm,
            _Rat.Get_Location().Z);
    }

    private bool Get_ShouldGoHome() const
    {
        const auto Since = _Rat.Get_NoTargetSince();
        return Since.IsSet() && _Rat.Get_Clock() - Since.GetValue() >= _Rat.Get_Tuning().Scent.NoTargetReturnSeconds;
    }

    private float64 Get_BurstLength(float32 InSpeed) const
    {
        const auto Rhythm = _Rat.Get_Tuning().Rhythm;
        return float64(Math::Max(_Rat.Get_Rhythm().BurstsPlanned, 1)) * float64(Rhythm.BoundSeconds * InSpeed);
    }

    private FVector Get_DenMarker(EMars_RatDen_Portal InPortal) const
    {
        auto Point = _Rat.Get_Den().Get_PortalWorld(InPortal);
        Point.Z = _Rat.Get_Location().Z;
        return Point;
    }

    //----------------------------------------------------------------------------------------------------------------------

    private void Tick_Emerge()
    {
        if (ck::Is_NOT_Valid(_Rat.Get_Den()))
        {
            Advance(EMars_PantryRat_Phase::Observe);
            return;
        }

        if (Get_NeedsRoute())
        {
            _Rat.Request_MoveTo(FMars_Request_PantryRat_MoveTo(Get_DenMarker(EMars_RatDen_Portal::OutsideStand),
                _Rat.Get_Tuning().Speeds.Creep, EMars_PantryRat_RoutePurpose::Home));
            return;
        }

        if (_Rat.Get_IsRouteIn(EMars_PantryRat_RouteStatus::Arrived) || _Rat.Get_IsRouteIn(EMars_PantryRat_RouteStatus::Failed))
        { Advance(EMars_PantryRat_Phase::Observe); }
    }

    private void Tick_Observe()
    {
        if (_Rat.Get_Threat().Active)
        {
            Advance(EMars_PantryRat_Phase::AvoidPlayer);
            return;
        }

        if (_Rat.Get_Clock() < _Rat.Get_Rhythm().PauseDeadline)
        { return; }

        const auto View = Get_TargetView();
        if (View.IsSet() == false)
        {
            if (Get_ShouldGoHome())
            { Advance(EMars_PantryRat_Phase::ReturnEmpty); }
            return;
        }

        const auto Target = View.GetValue();
        if (Target.Guarded || Target.LeasedElsewhere)
        {
            Advance(EMars_PantryRat_Phase::WatchGuarded);
            return;
        }

        if (utils_pantry_raid::Get_PlanarDistance(_Rat.Get_Location(), Get_WorkPoint(Target)) > utils_pantry_rat::k_WorkReachCm)
        {
            Advance(EMars_PantryRat_Phase::BoundApproach);
            return;
        }

        auto Raid = _Rat.Get_Raid();
        const auto Lease = Raid.TryGet_LeaseOf(_Rat);
        if (Lease.IsSet())
        {
            _Rat.Request_Advance(FMars_Request_PantryRat_Advance(EMars_PantryRat_Phase::Observe, EMars_PantryRat_Phase::Inspect,
                FMars_PantryRat_Target(Target.Pack, Lease.GetValue())));
            return;
        }

        Raid.Request_GrantLease(FMars_Request_PantryRaid_GrantLease(_Rat, Target.Pack, Target.Slot, Target.Item));
    }

    private void Tick_BoundApproach()
    {
        if (_Rat.Get_Threat().Active)
        {
            Advance(EMars_PantryRat_Phase::AvoidPlayer);
            return;
        }

        const auto View = Get_TargetView();
        if (View.IsSet() == false)
        {
            Advance(EMars_PantryRat_Phase::Observe);
            return;
        }

        if (View.GetValue().Guarded || View.GetValue().LeasedElsewhere)
        {
            Advance(EMars_PantryRat_Phase::WatchGuarded);
            return;
        }

        if (Get_NeedsRoute())
        {
            const auto Tuning = _Rat.Get_Tuning();
            const auto Speed = Tuning.Speeds.Approach;
            const auto Burst = utils_pantry_rat::Get_BurstGoal(_Rat.Get_Location(), Get_WorkPoint(View.GetValue()), Get_BurstLength(Speed));
            const auto Raid = _Rat.Get_Raid();
            // A bound never ends inside a chef's avoidance radius.
            if (Burst.IsSet() == false
                || utils_pantry_raid::Get_IsAnyChefWithin(Raid.Get_Chefs(), Burst.GetValue(), Tuning.Guard.AvoidEnterCm, Tuning.Guard.SameFloorCm))
            {
                Log(f"[PantryRat] [{_Rat.ToString()}] no safe burst toward the work point [{Get_WorkPoint(View.GetValue()).ToString()}] "
                    + f"(route [{Burst.IsSet()}])");
                Advance(EMars_PantryRat_Phase::WatchGuarded);
                return;
            }

            _Rat.Request_MoveTo(FMars_Request_PantryRat_MoveTo(Burst.GetValue(), Speed, EMars_PantryRat_RoutePurpose::Approach));
            return;
        }

        if (_Rat.Get_IsRouteIn(EMars_PantryRat_RouteStatus::Arrived) || _Rat.Get_IsRouteIn(EMars_PantryRat_RouteStatus::Failed))
        { Advance(EMars_PantryRat_Phase::Observe); }
    }

    private void Tick_WatchGuarded()
    {
        if (_Rat.Get_Threat().Active)
        {
            Advance(EMars_PantryRat_Phase::AvoidPlayer);
            return;
        }

        if (_Rat.Get_Route().Status == EMars_PantryRat_RouteStatus::Moving)
        {
            _Rat.Request_Stop(FMars_Request_PantryRat_Stop());
            return;
        }

        const auto View = Get_TargetView();
        if (View.IsSet() == false)
        {
            if (Get_ShouldGoHome())
            { Advance(EMars_PantryRat_Phase::ReturnEmpty); }
            return;
        }

        if (View.GetValue().Guarded == false && View.GetValue().LeasedElsewhere == false)
        { Advance(EMars_PantryRat_Phase::Observe); }
    }

    private void Tick_AvoidPlayer()
    {
        const auto Moving = _Rat.Get_IsRouteIn(EMars_PantryRat_RouteStatus::Moving);
        if (_Rat.Get_Threat().Active == false && Moving == false)
        {
            Advance(EMars_PantryRat_Phase::Observe);
            return;
        }

        if (_Rat.Get_IsRouteIn(EMars_PantryRat_RouteStatus::Arrived))
        {
            Advance(EMars_PantryRat_Phase::Observe);
            return;
        }

        if (Moving || _Rat.Get_Clock() < _NextDecisionAt)
        { return; }

        _NextDecisionAt = _Rat.Get_Clock() + _Rat.Get_Tuning().Routing.DecisionIntervalSeconds;
        const auto Goal = utils_pantry_rat::Pick_AvoidGoal(_Rat);
        // No safe candidate: a cautious hold in reachable space, rescored every decision interval.
        if (Goal.IsSet() == false)
        {
            if (_Rat.Get_Route().Status == EMars_PantryRat_RouteStatus::Moving)
            { _Rat.Request_Stop(FMars_Request_PantryRat_Stop()); }
            return;
        }

        _Rat.Request_MoveTo(FMars_Request_PantryRat_MoveTo(Goal.GetValue(), _Rat.Get_Tuning().Speeds.Approach, EMars_PantryRat_RoutePurpose::Avoid));
    }

    // Inspect then ClaimTell: the lease must stay ours, the pack unguarded and the rat unthreatened throughout.
    private void Tick_Claiming(EMars_PantryRat_Phase InPhase)
    {
        const auto Raid = _Rat.Get_Raid();
        const auto Lease = ck::IsValid(Raid) ? Raid.TryGet_LeaseOf(_Rat) : TOptional<FMars_PantryRaid_Lease>();
        const auto Target = _Rat.Get_Target();
        const auto View = Get_TargetView();
        const auto Lost = Lease.IsSet() == false || Target.IsSet() == false || Lease.GetValue().Token != Target.GetValue().Token
            || View.IsSet() == false || View.GetValue().Guarded || _Rat.Get_Threat().Active;
        if (Lost)
        {
            Advance(EMars_PantryRat_Phase::Observe);
            return;
        }

        const auto Theft = _Rat.Get_Tuning().Theft;
        if (InPhase == EMars_PantryRat_Phase::Inspect)
        {
            if (_Rat.Get_PhaseAge() >= Theft.InspectSeconds)
            { Advance(EMars_PantryRat_Phase::ClaimTell); }
            return;
        }

        if (_Rat.Get_PhaseAge() < Theft.RummageSeconds)
        { return; }

        // The last check before the commit reads every chef's current transform; the pocket's policy reads them again at the
        // inventory's commit.
        const auto Guard = _Rat.Get_Tuning().Guard;
        if (utils_pantry_raid::Get_IsAnyChefWithin(utils_pantry_raid::Read_ChefsNow(_Rat), View.GetValue().PackLocation, Guard.GuardEnterCm, Guard.SameFloorCm))
        {
            Advance(EMars_PantryRat_Phase::Observe);
            return;
        }

        _Rat.Request_Claim(FMars_Request_PantryRat_Claim(Target.GetValue().Token));
    }

    private void Tick_FleeWithLoot()
    {
        if (Get_NeedsRoute())
        {
            const auto Here = _Rat.Get_Location();
            if (_FleeGoal.IsSet() == false || utils_pantry_raid::Get_PlanarDistance(_FleeGoal.GetValue(), Here) < utils_pantry_rat::k_FleeGoalSpentCm)
            { _FleeGoal = utils_pantry_rat::Pick_FleeGoal(_Rat); }

            if (_FleeGoal.IsSet() == false)
            {
                Advance(EMars_PantryRat_Phase::FleeCornered);
                return;
            }

            const auto Speed = _Rat.Get_Tuning().Speeds.LoadedFlee;
            const auto Burst = utils_pantry_rat::Get_BurstGoal(Here, _FleeGoal.GetValue(), Get_BurstLength(Speed));
            if (Burst.IsSet() == false)
            {
                _FleeGoal.Reset();
                Advance(EMars_PantryRat_Phase::FleeCornered);
                return;
            }

            _Rat.Request_MoveTo(FMars_Request_PantryRat_MoveTo(Burst.GetValue(), Speed, EMars_PantryRat_RoutePurpose::Flee));
            return;
        }

        if (_Rat.Get_IsRouteIn(EMars_PantryRat_RouteStatus::Arrived))
        {
            Advance(EMars_PantryRat_Phase::FleePause);
            return;
        }

        if (_Rat.Get_IsRouteIn(EMars_PantryRat_RouteStatus::Failed))
        {
            _FleeGoal.Reset();
            Advance(EMars_PantryRat_Phase::FleeCornered);
        }
    }

    private void Tick_FleePause()
    {
        if (_Rat.Get_Clock() >= _Rat.Get_Rhythm().PauseDeadline)
        { Advance(EMars_PantryRat_Phase::FleeWithLoot); }
    }

    // Catchable in place, holding its loot; a reachable flee goal sends it running again.
    private void Tick_FleeCornered()
    {
        if (_Rat.Get_Clock() < _NextDecisionAt)
        { return; }

        _NextDecisionAt = _Rat.Get_Clock() + _Rat.Get_Tuning().Routing.DecisionIntervalSeconds;
        _FleeGoal = utils_pantry_rat::Pick_FleeGoal(_Rat);
        if (_FleeGoal.IsSet())
        { Advance(EMars_PantryRat_Phase::FleeWithLoot); }
    }

    private void Tick_ReturnEmpty()
    {
        if (_Rat.Get_Threat().Active)
        {
            Advance(EMars_PantryRat_Phase::AvoidPlayer);
            return;
        }

        if (Get_TargetView().IsSet())
        {
            Advance(EMars_PantryRat_Phase::Observe);
            return;
        }

        auto Den = _Rat.Get_Den();
        if (ck::Is_NOT_Valid(Den))
        { return; }

        if (Get_NeedsRoute())
        {
            _HomeLegInside = false;
            _Rat.Request_MoveTo(FMars_Request_PantryRat_MoveTo(Get_DenMarker(EMars_RatDen_Portal::ReturnAdmission),
                _Rat.Get_Tuning().Speeds.Approach, EMars_PantryRat_RoutePurpose::Home));
            return;
        }

        if (_Rat.Get_IsRouteIn(EMars_PantryRat_RouteStatus::Failed))
        {
            Advance(EMars_PantryRat_Phase::Observe);
            return;
        }

        if (_Rat.Get_IsRouteIn(EMars_PantryRat_RouteStatus::Arrived) == false)
        { return; }

        // At ReturnAdmission: creep through the arch to the Inside stand, so the crouch and the fade happen in the den mouth.
        if (_HomeLegInside == false)
        {
            _HomeLegInside = true;
            _Rat.Request_MoveTo(FMars_Request_PantryRat_MoveTo(Get_DenMarker(EMars_RatDen_Portal::Inside),
                _Rat.Get_Tuning().Speeds.Creep, EMars_PantryRat_RoutePurpose::Home));
            return;
        }

        // The kernel owns the rest: the crouch, the 0.25 s fade, the hide and the den's admission (Processor_Tick Advance_Fade).
        Advance(EMars_PantryRat_Phase::DenEnter);
    }

    // DenEnter is committed: the kernel crouches, fades, hides and asks the den; nothing to decide here.
    private void Tick_DenEnter()
    {
    }
}
