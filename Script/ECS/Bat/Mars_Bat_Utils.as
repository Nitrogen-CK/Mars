// Why a StartSwoop would be refused now (the drain's verdict, also what the control layer's CanSwoop asks).
enum EMars_Bat_SwoopAdmission
{
    Admitted,
    Dead,
    Busy,
    Hurt,
    Cooldown,
    NoTarget,
    OutOfRange,
    // The point it would swoop through is not in the flight volume's free space.
    GoalBlocked,
    // Static geometry stands between its mouth and the aim point: it would dive into a wall.
    NoLineOfSight
}

// The flight volume a bat flies in (utils_bat::Add_FlightVolume): world bounds, the finest cell edge (cm), the clearance
// baked round every obstacle (the bat's AgentRadius) and whether it bakes as soon as it is set up.
struct FMars_Bat_FlightVolume_Spec
{
    UPROPERTY()
    FBox Bounds;

    UPROPERTY()
    float32 CellSize = 40.0f;

    UPROPERTY()
    float32 Clearance = 40.0f;

    UPROPERTY()
    ECk_EnableDisable AutoBuild = ECk_EnableDisable::Enable;

    FMars_Bat_FlightVolume_Spec() {}

    FMars_Bat_FlightVolume_Spec(FBox InBounds, float32 InCellSize, float32 InClearance, ECk_EnableDisable InAutoBuild)
    {
        Bounds = InBounds;
        CellSize = InCellSize;
        Clearance = InClearance;
        AutoBuild = InAutoBuild;
    }
}

mixin FMars_Validation Validate(const FMars_Bat_FlightVolume_Spec& Self)
{
    if (Self.Bounds.IsValid == false || Self.Bounds.Min.X >= Self.Bounds.Max.X || Self.Bounds.Min.Y >= Self.Bounds.Max.Y ||
        Self.Bounds.Min.Z >= Self.Bounds.Max.Z)
    { return FMars_Validation("Bat flight volume has empty or invalid Bounds"); }

    if (utils_bat::Get_IsPositiveFinite(Self.CellSize) == false || Math::IsFinite(Self.Clearance) == false || Self.Clearance < 0.0f)
    { return FMars_Validation(f"Bat flight volume has a non-positive CellSize [{Self.CellSize}] or a negative Clearance [{Self.Clearance}]"); }

    return FMars_Validation();
}

// The swoop's progress, for whoever poses or reads it: the stage and how far through it [0, 1].
struct FMars_Bat_SwoopFrame
{
    UPROPERTY()
    EMars_Bat_SwoopStage Stage = EMars_Bat_SwoopStage::None;

    UPROPERTY()
    float32 Alpha = 0.0f;

    FMars_Bat_SwoopFrame() {}

    FMars_Bat_SwoopFrame(EMars_Bat_SwoopStage InStage, float32 InAlpha)
    {
        Stage = InStage;
        Alpha = InAlpha;
    }
}

namespace utils_bat
{
    // Entity tags: a perch a bat may claim, and a flight volume a bat may discover.
    const FName RoostTag = n"TAG_MarsBatRoost";
    const FName FlightVolumeTag = n"TAG_MarsBatFlightVolume";

    // The crowd agent's height is this many radii (it only sizes its debug body for a flyer).
    const float32 AgentHeightInRadii = 2.0f;

    bool Get_IsPositiveFinite(float32 InValue)
    {
        return Math::IsFinite(InValue) && InValue > 0.0f;
    }

    // Monster.Mars.Bat (DefaultGameplayTags.ini). Looked up, not GameplayTags::: an editor that booted before the tag
    // existed still compiles this script (it then has no tag, and Add refuses the bat until the editor restarts).
    FGameplayTag Get_MonsterTag()
    {
        return FGameplayTag::RequestGameplayTag(n"Monster.Mars.Bat", false);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Composition
    //----------------------------------------------------------------------------------------------------------------------

    FCk_CrowdAgent_Spec Make_AgentSpec(FMars_Bat_Flight InFlight)
    {
        auto Spec = FCk_CrowdAgent_Spec(InFlight.AgentRadius, InFlight.AgentRadius * AgentHeightInRadii);
        Spec.Set_AgentMode(ECk_CrowdAgent_Mode::Flying);
        Spec.Set_MaxSpeed(InFlight.CruiseSpeed);
        Spec.Set_MaxAcceleration(InFlight.MaxAcceleration);
        // The crowd turns in radians a second.
        Spec.Set_MaxTurnRate(Math::DegreesToRadians(InFlight.MaxTurnRate));
        Spec.Set_ArrivalRadius(InFlight.ArrivalRadius);
        return Spec;
    }

    // Composes the bat on InRoot (its flying body; the entity script hangs every visual off a presentation node under it):
    // monster (Health, body zone, team, Dead) -> damage dealer -> the body hurtbox -> the CkCrowd flying agent with its
    // velocity, acceleration and integrator -> the voxel path (bound to Spec.Volume when given) -> the bat's fragments
    // (UMars_Processor_Bat_Setup then binds the zone, the agent and the path) -> LAST the state machine
    // (Mars_Bat_Hfsm.as). The crowd agent is the only writer of the root transform while the bat is alive. A rejected
    // spec or sub-feature ensures and returns an invalid handle.
    FCk_Handle_Bat Add(FCk_Handle_Transform& InRoot, FMars_Bat_Spec InSpec)
    {
        FCk_Handle RootEntity = InRoot;
        auto Spec = InSpec;
        if (Spec.Monster.MonsterTag.IsValid() == false)
        { Spec.Monster.MonsterTag = Get_MonsterTag(); }

        const auto Validation = Spec.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[Bat] [{RootEntity.ToString()}] rejected the spec: {Validation.Get_Error()}"))
        { return FCk_Handle_Bat(); }

        auto Monster = utils_monster::Add(RootEntity, Spec.Monster);
        if (ck::Is_NOT_Valid(Monster))
        { return FCk_Handle_Bat(); }

        auto Dealer = utils_damage_dealer::Add(RootEntity, FMars_DamageDealer_Spec());
        if (ck::Is_NOT_Valid(Dealer))
        { return FCk_Handle_Bat(); }

        auto BodyZone = Monster.Get_BodyZone();
        utils_hit_zone::AddHurtbox_Box(BodyZone, InRoot, FMars_HitZone_Hurtbox(HurtboxHalfExtents, FTransform::Identity));

        auto Agent = utils_crowd_agent::Add(InRoot, Make_AgentSpec(Spec.Flight));
        if (ck::EnsureIfNot(ck::IsValid(Agent), f"[Bat] [{RootEntity.ToString()}] the crowd agent was rejected"))
        { return FCk_Handle_Bat(); }

        utils_velocity::Add(RootEntity, FCk_Velocity_Spec(ECk_LocalWorld::World, FVector::ZeroVector), ECk_Replication::DoesNotReplicate);
        utils_acceleration::Add(RootEntity, FCk_Acceleration_Spec(ECk_LocalWorld::World, FVector::ZeroVector), ECk_Replication::DoesNotReplicate);
        utils_euler_integrator::Request_Start(RootEntity);

        auto Path = utils_voxel_nav_path::Add(RootEntity, FCk_VoxelNavPath_Spec(Spec.Flight.AgentRadius));
        if (ck::EnsureIfNot(ck::IsValid(Path), f"[Bat] [{RootEntity.ToString()}] the voxel path was rejected"))
        { return FCk_Handle_Bat(); }

        if (ck::IsValid(Spec.Volume))
        { utils_voxel_nav_path::Request_SetVolume(Path, Spec.Volume); }

        auto Params = FMars_Fragment_Bat_Params();
        Params.Spec = Spec;
        Params.Monster = Monster;
        Params.Dealer = Dealer;
        Params.Agent = Agent;
        Params.Path = Path;
        Params.FixedPerchAnchor = Spec.Roost.PerchLocation.IsSet() ? Spec.Roost.PerchLocation.GetValue() :
            utils_transform::Get_EntityCurrentLocation(InRoot) - Spec.Roost.HangOffset;

        auto State = FMars_Fragment_Bat();
        State.Route.Volume = Spec.Volume;
        if (ck::IsValid(Spec.Roost.PerchOwner))
        {
            State.Perch.Claim = EMars_Bat_RoostClaim::Pending;
            State.Perch.Owner = Spec.Roost.PerchOwner;
        }
        else if (Spec.Roost.DiscoverRadius.IsSet())
        { State.Perch.Claim = EMars_Bat_RoostClaim::Pending; }

        RootEntity.Add_Fragment(FMars_Feature_Bat());
        RootEntity.Add_Fragment(Params);
        RootEntity.Add_Fragment(State);
        RootEntity.Add_Fragment(FMars_Fragment_Bat_PatrolBlackboard());
        RootEntity.Add_Fragment(FMars_Fragment_Bat_SortieBlackboard());
        RootEntity.Add_Fragment(FMars_Fragment_Bat_SearchBlackboard());
        RootEntity.Add_Fragment(FMars_Tag_Bat_NeedsSetup());

        // Last: Alive's condition reads the Dead attribute as the machine enters its initial state.
        utils_state_machine::Add(RootEntity, FCk_StateMachine_Spec(UMars_SmState_Bat_Alive));
        return RootEntity.As_Bat();
    }

    // The body zone's box round the bat's body (root frame): the wings' membranes are not part of it.
    const FVector HurtboxHalfExtents = FVector(22.0, 34.0, 16.0);

    // Makes InRoost a perch a bat can claim: the roost fragments and RoostTag. Its transform's location is the perch
    // anchor; the bat hangs at anchor + Spec.Roost.HangOffset.
    void Add_Roost(FCk_Handle& InRoost)
    {
        if (ck::EnsureIfNot(ck::IsValid(InRoost.As_Transform(ECk_SanityCheck::UnChecked)), f"[Bat] roost [{InRoost.ToString()}] has no transform"))
        { return; }

        InRoost.Add_Fragment(FMars_Feature_BatRoost());
        InRoost.Add_Fragment(FMars_Fragment_BatRoost());
        utils_entity_tag::Add(InRoost, RoostTag);
    }

    // A voxel flight volume on InOwner, tagged FlightVolumeTag so a bat with no Spec.Volume finds it. The bake reads the
    // Jolt static world: build it once the geometry it must see is in (AutoBuild Disable + Request_Build when not sure).
    FCk_Handle_VoxelNavVolume Add_FlightVolume(FCk_Handle& InOwner, FMars_Bat_FlightVolume_Spec InSpec)
    {
        const auto Validation = InSpec.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[Bat] [{InOwner.ToString()}] rejected the flight volume: {Validation.Get_Error()}"))
        { return FCk_Handle_VoxelNavVolume(); }

        auto VolumeSpec = FCk_VoxelNavVolume_Spec(InSpec.Bounds, InSpec.CellSize);
        VolumeSpec.Set_ClearanceUu(InSpec.Clearance);
        VolumeSpec.Set_AutoBuildOnSetup(InSpec.AutoBuild);

        auto Volume = utils_voxel_nav_volume::Add(InOwner, VolumeSpec);
        if (ck::EnsureIfNot(ck::IsValid(Volume), f"[Bat] [{InOwner.ToString()}] the voxel volume was rejected"))
        { return Volume; }

        FCk_Handle VolumeEntity = Volume;
        utils_entity_tag::Add(VolumeEntity, FlightVolumeTag);
        return Volume;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Roost readers and requests (on the perch entity)
    //----------------------------------------------------------------------------------------------------------------------

    bool Get_IsRoost(FCk_Handle InEntity)
    {
        if (ck::Is_NOT_Valid(InEntity) || utils_entity_lifetime::Get_IsPendingDestroy(InEntity, ECk_EntityLifetime_DestructionPhase::BeginDestroy))
        { return false; }

        return InEntity.Has_Fragment(FMars_Feature_BatRoost);
    }

    FMars_Fragment_BatRoost Get_RoostState(FCk_Handle InRoost)
    {
        if (Get_IsRoost(InRoost) == false)
        { return FMars_Fragment_BatRoost(); }

        return InRoost.Get_Fragment(FMars_Fragment_BatRoost);
    }

    FVector Get_RoostAnchor(FCk_Handle InRoost)
    {
        return utils_transform::Get_EntityCurrentLocation(InRoost.As_Transform());
    }

    void Request_ClaimRoost(FCk_Handle InRoost, const FMars_Request_BatRoost_Claim& InRequest)
    {
        auto Roost = InRoost;
        Roost.AddOrGet_Fragment(FMars_Fragment_BatRoost_Requests).ClaimRequests.Add(InRequest);
    }

    void Request_ReleaseRoost(FCk_Handle InRoost, const FMars_Request_BatRoost_Release& InRequest)
    {
        auto Roost = InRoost;
        Roost.AddOrGet_Fragment(FMars_Fragment_BatRoost_Requests).ReleaseRequests.Add(InRequest);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Readers
    //----------------------------------------------------------------------------------------------------------------------

    // A target the bat may act on: alive as an entity and placed in the world.
    bool Get_IsTargetValid(FCk_Handle InTarget)
    {
        if (ck::Is_NOT_Valid(InTarget) || utils_entity_lifetime::Get_IsPendingDestroy(InTarget, ECk_EntityLifetime_DestructionPhase::BeginDestroy))
        { return false; }

        return ck::IsValid(InTarget.As_Transform(ECk_SanityCheck::UnChecked));
    }

    // The phases only the kernel sets.
    bool Get_IsKernelPhase(EMars_Bat_Phase InPhase)
    {
        return InPhase == EMars_Bat_Phase::Telegraphing || InPhase == EMars_Bat_Phase::Swooping || InPhase == EMars_Bat_Phase::Recovering ||
            InPhase == EMars_Bat_Phase::Hit || InPhase == EMars_Bat_Phase::Stunned || InPhase == EMars_Bat_Phase::Falling ||
            InPhase == EMars_Bat_Phase::Landed || InPhase == EMars_Bat_Phase::Dead;
    }

    bool Get_IsRouteFailure(EMars_Bat_RouteOutcome InOutcome)
    {
        return InOutcome != EMars_Bat_RouteOutcome::None && InOutcome != EMars_Bat_RouteOutcome::Pending &&
            InOutcome != EMars_Bat_RouteOutcome::Reached;
    }

    float32 Get_StageSeconds(FMars_Bat_SwoopTiming InTiming, EMars_Bat_SwoopStage InStage)
    {
        if (InStage == EMars_Bat_SwoopStage::Telegraphing)
        { return InTiming.TelegraphSeconds; }

        if (InStage == EMars_Bat_SwoopStage::Committed)
        { return InTiming.SwoopSeconds; }

        if (InStage == EMars_Bat_SwoopStage::Recovering)
        { return InTiming.RecoverSeconds; }

        return 0.0f;
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

mixin FMars_Bat_Spec Get_Spec(const FCk_Handle_Bat& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Bat_Params).Spec;
}

mixin FCk_Handle_Monster Get_Monster(const FCk_Handle_Bat& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Bat_Params).Monster;
}

mixin FCk_Handle_DamageDealer Get_Dealer(const FCk_Handle_Bat& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Bat_Params).Dealer;
}

mixin FCk_Handle_CrowdAgent Get_Agent(const FCk_Handle_Bat& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Bat_Params).Agent;
}

mixin FCk_Handle_VoxelNavPath Get_Path(const FCk_Handle_Bat& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Bat_Params).Path;
}

mixin bool Get_IsDead(const FCk_Handle_Bat& Self)
{
    return Self.Get_Monster().Get_IsDead();
}

mixin EMars_Bat_Phase Get_Phase(const FCk_Handle_Bat& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Bat).Phase;
}

// Seconds in the current phase.
mixin float32 Get_PhaseClock(const FCk_Handle_Bat& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Bat).PhaseClock;
}

mixin FTransform Get_RootTransform(const FCk_Handle_Bat& Self)
{
    return utils_transform::Get_EntityCurrentTransform(Self.As_Transform());
}

mixin FVector Get_Location(const FCk_Handle_Bat& Self)
{
    return utils_transform::Get_EntityCurrentLocation(Self.As_Transform());
}

// The swoop's blow centre now (world).
mixin FVector Get_MouthLocation(const FCk_Handle_Bat& Self)
{
    return Self.Get_RootTransform().TransformPosition(Self.Get_Spec().Swoop.Blow.MouthOffset);
}

mixin FCk_Handle Get_Target(const FCk_Handle_Bat& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Bat).Target;
}

// The target's velocity as the senses measured it (zero until two senses of the same target).
mixin FVector Get_TargetVelocity(const FCk_Handle_Bat& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Bat).TargetVelocity;
}

mixin bool Get_HasTarget(const FCk_Handle_Bat& Self)
{
    return utils_bat::Get_IsTargetValid(Self.Get_Target());
}

// Where a target it lost by distance was last sensed (see FMars_Fragment_Bat.LastKnown).
mixin TOptional<FVector> Get_LastKnown(const FCk_Handle_Bat& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Bat).LastKnown;
}

// A last-known place is held and no EndSearch is queued against it (a state that just gave the search up must not be sent
// straight back by the memory the drain has not cleared yet).
mixin bool Get_HasLastKnown(const FCk_Handle_Bat& Self)
{
    if (Self.Get_LastKnown().IsSet() == false)
    { return false; }

    return Self.Has_Fragment(FMars_Fragment_Bat_Requests) == false ||
        Self.Get_Fragment(FMars_Fragment_Bat_Requests).EndSearchRequests.Num() == 0;
}

// The last-known place raised by the swoop's AimHeight: what the search circles (the aim point a target there would have).
mixin FVector Get_SearchAim(const FCk_Handle_Bat& Self)
{
    const auto LastKnown = Self.Get_LastKnown();
    return (LastKnown.IsSet() ? LastKnown.GetValue() : Self.Get_Location()) + FVector(0.0, 0.0, Self.Get_Spec().Swoop.AimHeight);
}

// Where the search flies first: Swoop.Height over the search aim.
mixin FVector Get_SearchPoint(const FCk_Handle_Bat& Self)
{
    return Self.Get_SearchAim() + FVector(0.0, 0.0, Self.Get_Spec().Swoop.Height);
}

// The target's location raised by the swoop's AimHeight (what the swoop flies through).
mixin FVector Get_TargetAimPoint(const FCk_Handle_Bat& Self)
{
    return utils_transform::Get_EntityCurrentLocation(Self.Get_Target().As_Transform()) +
        FVector(0.0, 0.0, Self.Get_Spec().Swoop.AimHeight);
}

// Where it waits to swoop: Height over the aim point and Standoff back toward the bat along the ground.
mixin FVector Get_StrikePoint(const FCk_Handle_Bat& Self)
{
    const auto Swoop = Self.Get_Spec().Swoop;
    const auto Aim = Self.Get_TargetAimPoint();
    auto Back = Self.Get_Location() - Aim;
    Back.Z = 0.0;
    Back = Back.GetSafeNormal();
    if (Back.IsNearlyZero())
    { Back = -Self.Get_RootTransform().GetRotation().GetForwardVector(); }

    return Aim + Back * Swoop.Standoff + FVector(0.0, 0.0, Swoop.Height);
}

mixin FMars_Bat_Route Get_Route(const FCk_Handle_Bat& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Bat).Route;
}

mixin EMars_Bat_RouteOutcome Get_RouteOutcome(const FCk_Handle_Bat& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Bat).Route.Outcome;
}

mixin FCk_Handle_VoxelNavVolume Get_Volume(const FCk_Handle_Bat& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Bat).Route.Volume;
}

// A volume is known and baked: a FlyTo can be asked for.
mixin bool Get_IsNavReady(const FCk_Handle_Bat& Self)
{
    const auto Volume = Self.Get_Volume();
    return ck::IsValid(Volume) && utils_voxel_nav_volume::Get_IsBuilt(Volume);
}

// The route issued while the kernel was in InPhase (and still is) answered with a failure.
mixin bool Get_IsRouteFailedIn(const FCk_Handle_Bat& Self, EMars_Bat_Phase InPhase)
{
    const auto& State = Self.Get_Fragment(FMars_Fragment_Bat);
    return State.Phase == InPhase && State.Route.IssuedIn == InPhase && utils_bat::Get_IsRouteFailure(State.Route.Outcome);
}

// The route issued while the kernel was in InPhase (and still is) arrived.
mixin bool Get_IsRouteReachedIn(const FCk_Handle_Bat& Self, EMars_Bat_Phase InPhase)
{
    const auto& State = Self.Get_Fragment(FMars_Fragment_Bat);
    return State.Phase == InPhase && State.Route.IssuedIn == InPhase && State.Route.Outcome == EMars_Bat_RouteOutcome::Reached;
}

mixin FMars_Bat_SwoopLedger Get_SwoopLedger(const FCk_Handle_Bat& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Bat).Swoop;
}

mixin EMars_Bat_SwoopStage Get_SwoopStage(const FCk_Handle_Bat& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Bat).Swoop.Stage;
}

mixin bool Get_IsSwoopCommitted(const FCk_Handle_Bat& Self)
{
    return Self.Get_SwoopStage() == EMars_Bat_SwoopStage::Committed;
}

mixin FMars_Bat_SwoopFrame Get_SwoopFrame(const FCk_Handle_Bat& Self)
{
    const auto& Swoop = Self.Get_Fragment(FMars_Fragment_Bat).Swoop;
    const auto Seconds = utils_bat::Get_StageSeconds(Self.Get_Spec().Swoop.Timing, Swoop.Stage);
    const auto Alpha = Seconds > 0.0f ? Math::Clamp(Swoop.StageElapsed / Seconds, 0.0f, 1.0f) : 0.0f;
    return FMars_Bat_SwoopFrame(Swoop.Stage, Alpha);
}

// A swoop runs, or a StartSwoop is queued.
mixin bool Get_IsSwoopBusy(const FCk_Handle_Bat& Self)
{
    if (Self.Get_SwoopStage() != EMars_Bat_SwoopStage::None)
    { return true; }

    return Self.Has_Fragment(FMars_Fragment_Bat_Requests) &&
        Self.Get_Fragment(FMars_Fragment_Bat_Requests).StartSwoopRequests.Num() > 0;
}

mixin FMars_Bat_Hurt Get_Hurt(const FCk_Handle_Bat& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Bat).Hurt;
}

mixin bool Get_IsHurt(const FCk_Handle_Bat& Self)
{
    const auto& Hurt = Self.Get_Fragment(FMars_Fragment_Bat).Hurt;
    return Hurt.HitLeft > 0.0f || Hurt.StunLeft > 0.0f;
}

// Out of the air for good (falling, landed or dead).
mixin bool Get_IsDown(const FCk_Handle_Bat& Self)
{
    const auto Phase = Self.Get_Phase();
    return Phase == EMars_Bat_Phase::Falling || Phase == EMars_Bat_Phase::Landed || Phase == EMars_Bat_Phase::Dead;
}

// Whether a StartSwoop at InTarget would be admitted now (the drain asks exactly this).
mixin EMars_Bat_SwoopAdmission Get_SwoopAdmission(const FCk_Handle_Bat& Self, FCk_Handle InTarget)
{
    if (Self.Get_IsDead() || Self.Get_IsDown())
    { return EMars_Bat_SwoopAdmission::Dead; }

    const auto& State = Self.Get_Fragment(FMars_Fragment_Bat);
    if (State.Swoop.Stage != EMars_Bat_SwoopStage::None)
    { return EMars_Bat_SwoopAdmission::Busy; }

    if (Self.Get_IsHurt())
    { return EMars_Bat_SwoopAdmission::Hurt; }

    if (State.Swoop.Cooldown > 0.0f)
    { return EMars_Bat_SwoopAdmission::Cooldown; }

    if (utils_bat::Get_IsTargetValid(InTarget) == false)
    { return EMars_Bat_SwoopAdmission::NoTarget; }

    const auto Swoop = Self.Get_Spec().Swoop;
    const auto Aim = utils_transform::Get_EntityCurrentLocation(InTarget.As_Transform()) + FVector(0.0, 0.0, Swoop.AimHeight);
    if ((Aim - Self.Get_Location()).Size() > Swoop.Range)
    { return EMars_Bat_SwoopAdmission::OutOfRange; }

    const auto Volume = State.Route.Volume;
    if (ck::Is_NOT_Valid(Volume) || utils_voxel_nav_volume::Get_IsBuilt(Volume) == false ||
        utils_voxel_nav_volume::Get_IsPointFree(Volume, Aim) == false)
    { return EMars_Bat_SwoopAdmission::GoalBlocked; }

    if (utils_bat::Get_IsStaticBetween(Self.Get_MouthLocation(), Aim))
    { return EMars_Bat_SwoopAdmission::NoLineOfSight; }

    return EMars_Bat_SwoopAdmission::Admitted;
}

// A point on the standoff circle round the aim point (Standoff out, Height up), InLeadDegrees ahead of the bat's current
// bearing in the InSign direction (+1 counter-clockwise seen from above). Chasing it circles the target.
mixin FVector Get_OrbitPoint(const FCk_Handle_Bat& Self, int32 InSign, float64 InLeadDegrees)
{
    return Self.Get_OrbitPointAround(Self.Get_TargetAimPoint(), InSign, InLeadDegrees);
}

// The same circle round any aim point InCentre (the search circles where the target was last sensed).
mixin FVector Get_OrbitPointAround(const FCk_Handle_Bat& Self, FVector InCentre, int32 InSign, float64 InLeadDegrees)
{
    const auto Swoop = Self.Get_Spec().Swoop;
    auto Out = Self.Get_Location() - InCentre;
    Out.Z = 0.0;
    if (Out.IsNearlyZero())
    { Out = -Self.Get_RootTransform().GetRotation().GetForwardVector(); }

    const auto Bearing = Math::RadiansToDegrees(Math::Atan2(Out.Y, Out.X)) + float64(InSign >= 0 ? 1 : -1) * InLeadDegrees;
    const auto Radians = Math::DegreesToRadians(Bearing);
    return InCentre + FVector(Math::Cos(Radians), Math::Sin(Radians), 0.0) * Swoop.Standoff + FVector(0.0, 0.0, Swoop.Height);
}

// The orbit goal the control layer flies while circling InCentre: the orbit point InSign round, else (when the flight volume
// does not have it free: a target against a wall, a corner) the point the other way round, else InFallback (the strike or
// search point it already holds). Without a check an orbit point in a wall fails the route, which while Approaching drops
// the target (seen in PIE: a search in the room's corner ended on EndpointUnresolvable).
mixin FVector Get_OrbitGoal(const FCk_Handle_Bat& Self, FVector InCentre, int32 InSign, FVector InFallback)
{
    const auto Volume = Self.Get_Volume();
    if (ck::Is_NOT_Valid(Volume) || utils_voxel_nav_volume::Get_IsBuilt(Volume) == false)
    { return InFallback; }

    for (int32 Try = 0; Try < 2; ++Try)
    {
        const auto Point = Self.Get_OrbitPointAround(InCentre, Try == 0 ? InSign : -InSign, utils_bat::OrbitLeadDeg);
        if (utils_voxel_nav_volume::Get_IsPointFree(Volume, Point))
        { return Point; }
    }

    return InFallback;
}

// Where it pulls back to after a blow: Timing.RetreatDistance from the aim point along the ground away from the target,
// Swoop.Height up. A point the flight volume does not have free is tried at half the distance, then the strike point stands
// in (a retreat that cannot be flown ends as a route failure, which the control layer takes as done).
mixin FVector Get_RetreatPoint(const FCk_Handle_Bat& Self)
{
    const auto Spec = Self.Get_Spec();
    const auto Aim = Self.Get_TargetAimPoint();
    auto Away = Self.Get_Location() - Aim;
    Away.Z = 0.0;
    Away = Away.GetSafeNormal();
    if (Away.IsNearlyZero())
    { Away = -Self.Get_RootTransform().GetRotation().GetForwardVector(); }

    const auto Distance = Spec.Timing.RetreatDistance.IsSet() ? float64(Spec.Timing.RetreatDistance.GetValue()) : float64(Spec.Swoop.Standoff);
    const auto Volume = Self.Get_Volume();
    const auto Ready = ck::IsValid(Volume) && utils_voxel_nav_volume::Get_IsBuilt(Volume);
    for (int32 Halving = 0; Halving < 2; ++Halving)
    {
        const auto Point = Aim + Away * (Distance / float64(1 << Halving)) + FVector(0.0, 0.0, Spec.Swoop.Height);
        if (Ready == false || utils_voxel_nav_volume::Get_IsPointFree(Volume, Point))
        { return Point; }
    }

    return Self.Get_StrikePoint();
}

namespace utils_bat
{
    // Static world geometry between two points (a wall, a pillar), by a Jolt static-world ray.
    bool Get_IsStaticBetween(FVector InFrom, FVector InTo)
    {
        auto Filter = FCk_Jolt_QueryFilter();
        Filter.Set_BodySelection(ECk_Jolt_QueryBodySelection::StaticNonSensor);
        return utils_jolt_query::Get_RayCast(InFrom, InTo, Filter).Get_HasHit();
    }
}

mixin FMars_Bat_Telemetry Get_Telemetry(const FCk_Handle_Bat& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Bat).Telemetry;
}

mixin EMars_Bat_RoostClaim Get_RoostClaim(const FCk_Handle_Bat& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Bat).Perch.Claim;
}

mixin FCk_Handle Get_RoostOwner(const FCk_Handle_Bat& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Bat).Perch.Owner;
}

// It has somewhere it may land: a fixed perch, or an owned roost that is held (or still being claimed).
mixin bool Get_HasPerch(const FCk_Handle_Bat& Self)
{
    const auto& Perch = Self.Get_Fragment(FMars_Fragment_Bat).Perch;
    if (Perch.Claim == EMars_Bat_RoostClaim::Unowned)
    { return true; }

    if (Perch.Claim == EMars_Bat_RoostClaim::Held)
    { return utils_bat::Get_IsRoost(Perch.Owner); }

    // Pending: still looking (no owner), or the claim is queued on a roost that still exists (TickPerch turns it Lost when
    // the roost goes away or goes to another bat). Reading a queued claim as no perch sent a discovering bat Roost -> Hover
    // on its first frame in PIE.
    return Perch.Claim == EMars_Bat_RoostClaim::Pending && (ck::Is_NOT_Valid(Perch.Owner) || utils_bat::Get_IsRoost(Perch.Owner));
}

// Where it hangs from: the roost's location when it has one, else the fixed anchor.
mixin FVector Get_PerchAnchor(const FCk_Handle_Bat& Self)
{
    const auto& Perch = Self.Get_Fragment(FMars_Fragment_Bat).Perch;
    if ((Perch.Claim == EMars_Bat_RoostClaim::Held || Perch.Claim == EMars_Bat_RoostClaim::Pending) && utils_bat::Get_IsRoost(Perch.Owner))
    { return utils_bat::Get_RoostAnchor(Perch.Owner); }

    return Self.Get_Fragment(FMars_Fragment_Bat_Params).FixedPerchAnchor;
}

// Where its root hangs while it roosts (its home).
mixin FVector Get_HangPoint(const FCk_Handle_Bat& Self)
{
    return Self.Get_PerchAnchor() + Self.Get_Spec().Roost.HangOffset;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

mixin void Request_SetPhase(FCk_Handle_Bat& Self, const FMars_Request_Bat_SetPhase& InRequest)
{
    Self.AddOrGet_Fragment(FMars_Fragment_Bat_Requests).SetPhaseRequests.Add(InRequest);
}

mixin void Request_FlyTo(FCk_Handle_Bat& Self, const FMars_Request_Bat_FlyTo& InRequest)
{
    Self.AddOrGet_Fragment(FMars_Fragment_Bat_Requests).FlyToRequests.Add(InRequest);
}

mixin void Request_Hold(FCk_Handle_Bat& Self, const FMars_Request_Bat_Hold& InRequest)
{
    Self.AddOrGet_Fragment(FMars_Fragment_Bat_Requests).HoldRequests.Add(InRequest);
}

mixin void Request_RouteResult(FCk_Handle_Bat& Self, const FMars_Request_Bat_RouteResult& InRequest)
{
    Self.AddOrGet_Fragment(FMars_Fragment_Bat_Requests).RouteResultRequests.Add(InRequest);
}

mixin void Request_StartSwoop(FCk_Handle_Bat& Self, const FMars_Request_Bat_StartSwoop& InRequest)
{
    Self.AddOrGet_Fragment(FMars_Fragment_Bat_Requests).StartSwoopRequests.Add(InRequest);
}

mixin void Request_CancelSwoop(FCk_Handle_Bat& Self, const FMars_Request_Bat_CancelSwoop& InRequest)
{
    Self.AddOrGet_Fragment(FMars_Fragment_Bat_Requests).CancelSwoopRequests.Add(InRequest);
}

mixin void Request_TakeHit(FCk_Handle_Bat& Self, const FMars_Request_Bat_TakeHit& InRequest)
{
    Self.AddOrGet_Fragment(FMars_Fragment_Bat_Requests).TakeHitRequests.Add(InRequest);
}

mixin void Request_Fall(FCk_Handle_Bat& Self, const FMars_Request_Bat_Fall& InRequest)
{
    Self.AddOrGet_Fragment(FMars_Fragment_Bat_Requests).FallRequests.Add(InRequest);
}

mixin void Request_ReleaseRoost(FCk_Handle_Bat& Self, const FMars_Request_Bat_ReleaseRoost& InRequest)
{
    Self.AddOrGet_Fragment(FMars_Fragment_Bat_Requests).ReleaseRoostRequests.Add(InRequest);
}

mixin void Request_EndSearch(FCk_Handle_Bat& Self, const FMars_Request_Bat_EndSearch& InRequest)
{
    Self.AddOrGet_Fragment(FMars_Fragment_Bat_Requests).EndSearchRequests.Add(InRequest);
}

//--------------------------------------------------------------------------------------------------------------------------
// Signal Binding
//--------------------------------------------------------------------------------------------------------------------------

mixin void BindTo_OnPhaseChanged(FCk_Handle_Bat& Self, FMars_Delegate_Bat_OnPhaseChanged InDelegate)
{
    Self.AddOrGet_Fragment(FMars_Fragment_Bat_Signals).OnPhaseChanged.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnPhaseChanged(FCk_Handle_Bat& Self, FMars_Delegate_Bat_OnPhaseChanged InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Bat_Signals))
    { Self.Get_Fragment(FMars_Fragment_Bat_Signals).OnPhaseChanged.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName()); }
}

mixin void BindTo_OnSwoopLanded(FCk_Handle_Bat& Self, FMars_Delegate_Bat_OnSwoopLanded InDelegate)
{
    Self.AddOrGet_Fragment(FMars_Fragment_Bat_Signals).OnSwoopLanded.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnSwoopLanded(FCk_Handle_Bat& Self, FMars_Delegate_Bat_OnSwoopLanded InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Bat_Signals))
    { Self.Get_Fragment(FMars_Fragment_Bat_Signals).OnSwoopLanded.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName()); }
}

mixin void BindTo_OnSwoopCancelled(FCk_Handle_Bat& Self, FMars_Delegate_Bat_OnSwoopCancelled InDelegate)
{
    Self.AddOrGet_Fragment(FMars_Fragment_Bat_Signals).OnSwoopCancelled.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnSwoopCancelled(FCk_Handle_Bat& Self, FMars_Delegate_Bat_OnSwoopCancelled InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Bat_Signals))
    { Self.Get_Fragment(FMars_Fragment_Bat_Signals).OnSwoopCancelled.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName()); }
}

mixin void BindTo_OnRouteOutcome(FCk_Handle_Bat& Self, FMars_Delegate_Bat_OnRouteOutcome InDelegate)
{
    Self.AddOrGet_Fragment(FMars_Fragment_Bat_Signals).OnRouteOutcome.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnRouteOutcome(FCk_Handle_Bat& Self, FMars_Delegate_Bat_OnRouteOutcome InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Bat_Signals))
    { Self.Get_Fragment(FMars_Fragment_Bat_Signals).OnRouteOutcome.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName()); }
}

mixin void BindTo_OnPerchLost(FCk_Handle_Bat& Self, FMars_Delegate_Bat_OnPerchLost InDelegate)
{
    Self.AddOrGet_Fragment(FMars_Fragment_Bat_Signals).OnPerchLost.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnPerchLost(FCk_Handle_Bat& Self, FMars_Delegate_Bat_OnPerchLost InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Bat_Signals))
    { Self.Get_Fragment(FMars_Fragment_Bat_Signals).OnPerchLost.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName()); }
}

mixin void BindTo_OnTargetChanged(FCk_Handle_Bat& Self, FMars_Delegate_Bat_OnTargetChanged InDelegate)
{
    Self.AddOrGet_Fragment(FMars_Fragment_Bat_Signals).OnTargetChanged.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnTargetChanged(FCk_Handle_Bat& Self, FMars_Delegate_Bat_OnTargetChanged InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Bat_Signals))
    { Self.Get_Fragment(FMars_Fragment_Bat_Signals).OnTargetChanged.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName()); }
}
