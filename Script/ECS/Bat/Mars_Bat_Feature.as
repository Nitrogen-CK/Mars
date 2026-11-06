//--------------------------------------------------------------------------------------------------------------------------
// Dynamic Handle Definition
//--------------------------------------------------------------------------------------------------------------------------

asset Mars_BatHandle of UCkDynamic_HandleDefinition
{
    TypeName = "FCk_Handle_Bat";
    RequiredFragments.Add(FMars_Feature_Bat);
    Description = "A flying bat: hangs from a roost, flies a CkCrowd flying agent through a CkVoxelNav volume, telegraphs and commits one swoop at a hostile target, and falls when it dies";
}

struct FMars_Feature_Bat {}

// Until UMars_Processor_Bat_Setup has bound the body zone, the crowd agent and the voxel path to the kernel.
struct FMars_Tag_Bat_NeedsSetup {}

//--------------------------------------------------------------------------------------------------------------------------
// Enums
//--------------------------------------------------------------------------------------------------------------------------

// What the bat is doing (the presentation reads it). The behaviour phases are set by the control layer through
// Request_SetPhase; Telegraphing, Swooping, Recovering, Hit, Stunned, Falling, Landed and Dead are the kernel's own and
// are never accepted from a request. Screeching is presentation only: it names a telegraph (see the enumerator).
enum EMars_Bat_Phase
{
    Roosting,
    Alert,
    Launching,
    Patrolling,
    Approaching,
    Telegraphing,
    Swooping,
    Recovering,
    Returning,
    Braking,
    Perching,
    // Holding its place in the air: it has nowhere it can fly (its route or its perch failed) and no target.
    Hovering,
    Hit,
    Stunned,
    Falling,
    Landed,
    Dead,
    // Presentation only (the AnimBP's Screech): the first telegraph of a sortie, set by the Telegraph task through
    // Request_SetPhase and accepted only while the swoop ledger is Telegraphing. The ledger, its clocks and its outcomes do
    // not change; the commit names Swooping as usual.
    Screeching,
    // Flying to where its target was last sensed and circling there (the control layer's Search).
    Searching,
    // Pulling back from its target after a blow, before the next approach (the control layer's Retreat).
    Retreating
    // The enumerators from Screeching on were added after the AnimBP was built, in this order, so the earlier ones keep
    // their PhaseIndex (the AnimBP compares it); utils_bat::Get_AnimPhase folds the later ones onto the states it has.
}

// The last thing its route did. Every FlyTo ends in exactly one of these (or is superseded by the next FlyTo).
enum EMars_Bat_RouteOutcome
{
    // No FlyTo issued yet.
    None,
    // A FlyTo is with the crowd agent, not answered yet.
    Pending,
    Reached,
    // There is no flight volume to fly in (Spec.Volume unset and none tagged TAG_MarsBatFlightVolume).
    NoVolume,
    // The volume has not finished its bake.
    NoBake,
    // The goal (or the bat) is not in the volume's free space.
    EndpointUnresolvable,
    // Both ends resolve but no free space connects them.
    Unreachable,
    // The path search ran out of iterations or was rejected as invalid.
    SearchFailed,
    // The crowd agent failed the move (CkCrowd OnGoalFailed).
    GoalFailed,
    // The crowd agent is held short of the goal (CkCrowd OnGoalBlocked).
    GoalBlocked
}

// Why a telegraphed or committed swoop ended without running out.
enum EMars_Bat_SwoopCancel
{
    // The control layer asked (Request_CancelSwoop).
    Cancelled,
    // A blow landed on the bat.
    Interrupted,
    Died,
    // The target went invalid while the bat was still telegraphing.
    TargetLost
}

// Where the one swoop the bat may run stands.
enum EMars_Bat_SwoopStage
{
    None,
    // Holding in the air, facing its target: cancellable, no damage.
    Telegraphing,
    // Committed: flying through the target point; the mouth sweeps until one result lands.
    Committed,
    // Climbing back to where the swoop began: no damage.
    Recovering
}

// The bat's hold on its perch.
enum EMars_Bat_RoostClaim
{
    // No owner: the perch is the fixed point Spec.Roost.PerchLocation (or the spawn point), which cannot be lost.
    Unowned,
    // An owner is known (or is being looked for) and the claim is not confirmed yet.
    Pending,
    Held,
    // The owner went away or was taken: the bat must not land there.
    Lost,
    // Given back (it died); never re-taken.
    Released
}

//--------------------------------------------------------------------------------------------------------------------------
// Spec
//--------------------------------------------------------------------------------------------------------------------------

// How it flies (the crowd agent's tuning). Speeds cm/s, acceleration cm/s^2, turn rate degrees/s.
struct FMars_Bat_Flight
{
    UPROPERTY()
    float32 CruiseSpeed = 380.0f;

    UPROPERTY()
    float32 SwoopSpeed = 900.0f;

    UPROPERTY()
    float32 MaxAcceleration = 1400.0f;

    UPROPERTY()
    float32 MaxTurnRate = 360.0f;

    // The flying body's radius: the crowd agent, the voxel path and the flight volume's clearance all use it. The wings'
    // reach is inside it.
    UPROPERTY()
    float32 AgentRadius = 40.0f;

    // How close counts as there for a FlyTo.
    UPROPERTY()
    float32 ArrivalRadius = 30.0f;
}

// What it notices. Targets are entities tagged TAG_MarsCombatTarget and Hostile to it.
struct FMars_Bat_Sensing
{
    UPROPERTY()
    float32 AcquireRadius = 1100.0f;

    // A held target is kept until it leaves this radius (hysteresis over AcquireRadius) ...
    UPROPERTY()
    float32 LoseRadius = 1500.0f;

    // ... or HomeRadius of its perch.
    UPROPERTY()
    float32 HomeRadius = 2000.0f;

    UPROPERTY()
    float32 SenseInterval = 0.2f;

    // Set: a hostile target that leaves LoseRadius while still within HomeRadius is remembered where it was last sensed
    // (Get_LastKnown) and the control layer flies there and circles for this long before giving it up. Unset: a target
    // that leaves is forgotten at once.
    UPROPERTY()
    TOptional<float32> SearchSeconds = 3.0f;
}

// The swoop's clocks (s): Telegraph (cancellable), Swoop (committed), Recover, then the cooldown before the next one.
struct FMars_Bat_SwoopTiming
{
    UPROPERTY()
    float32 TelegraphSeconds = 0.6f;

    UPROPERTY()
    float32 SwoopSeconds = 0.7f;

    UPROPERTY()
    float32 RecoverSeconds = 0.8f;

    UPROPERTY()
    float32 CooldownSeconds = 1.5f;
}

// What a landed swoop does: the mouth (MouthOffset in the root's frame) sweeps a ContactRadius sphere.
struct FMars_Bat_SwoopBlow
{
    UPROPERTY()
    float32 Damage = 12.0f;

    UPROPERTY(meta = (Categories = "DamageType"))
    FGameplayTag DamageType = GameplayTags::DamageType_Mars_Sever;

    UPROPERTY()
    float32 ContactRadius = 30.0f;

    UPROPERTY()
    FVector MouthOffset = FVector(26.0, 0.0, -4.0);
}

// The swoop: the control layer brings the bat to its strike point (Height over the aim point, Standoff back toward the
// bat); a swoop starts only within Range of the aim point (the target's location raised by AimHeight).
struct FMars_Bat_Swoop
{
    UPROPERTY()
    FMars_Bat_SwoopTiming Timing;

    UPROPERTY()
    FMars_Bat_SwoopBlow Blow;

    UPROPERTY()
    float32 Range = 450.0f;

    UPROPERTY()
    float32 Height = 160.0f;

    UPROPERTY()
    float32 Standoff = 220.0f;

    UPROPERTY()
    float32 AimHeight = 0.0f;
}

// Where it hangs. The hang point is the perch anchor plus HangOffset; the anchor is the claimed owner's location when it
// has one, else PerchLocation, else where the bat was spawned.
struct FMars_Bat_Roost
{
    // World space. Unset: the spawn point.
    UPROPERTY()
    TOptional<FVector> PerchLocation;

    // A roost entity (UMars_BatRoost_EntityScript, utils_bat::Add_Roost) the bat claims. Invalid: it looks for one
    // (DiscoverRadius) or keeps the fixed perch.
    UPROPERTY()
    FCk_Handle PerchOwner;

    // Unset: no search. Set: with no PerchOwner, the nearest roost within this radius of the perch anchor is claimed.
    UPROPERTY()
    TOptional<float32> DiscoverRadius;

    UPROPERTY()
    FVector HangOffset = FVector(0.0, 0.0, -80.0);

    UPROPERTY()
    float32 AlertSeconds = 0.6f;

    UPROPERTY()
    float32 LaunchSeconds = 0.5f;

    UPROPERTY()
    float32 PerchSeconds = 0.6f;
}

// The rest of its clocks (s).
struct FMars_Bat_Timing
{
    UPROPERTY()
    float32 HitSeconds = 0.35f;

    UPROPERTY()
    float32 StunSeconds = 1.6f;

    // A blow of at least this much stuns instead of merely flinching.
    UPROPERTY()
    float32 StunDamage = 20.0f;

    // Unset: it never leaves its roost without a target. Set: it patrols its FlightNodes after hanging this long.
    UPROPERTY()
    TOptional<float32> RoostIdleSeconds;

    // In Hovering, how long it waits before trying its perch again.
    UPROPERTY()
    float32 HoverRetrySeconds = 2.0f;

    // A fall that meets no ground ends (Landed where it is) after this long.
    UPROPERTY()
    float32 MaxFallSeconds = 4.0f;

    // The hurt reaction's second half. Set: once the hurt clocks run out with a target still held, it pulls back to this
    // far from the aim point (Get_RetreatPoint, along the ground away from the target, Swoop.Height up) before it
    // approaches again, RetreatSeconds at most. Unset: it approaches again at once.
    UPROPERTY()
    TOptional<float32> RetreatDistance = 450.0f;

    UPROPERTY()
    float32 RetreatSeconds = 1.5f;
}

struct FMars_Bat_Spec
{
    UPROPERTY()
    FMars_Bat_Flight Flight;

    UPROPERTY()
    FMars_Bat_Sensing Sensing;

    UPROPERTY()
    FMars_Bat_Swoop Swoop;

    UPROPERTY()
    FMars_Bat_Roost Roost;

    UPROPERTY()
    FMars_Bat_Timing Timing;

    // Patrol nodes, world space, flown in order. They must lie in the flight volume's free space.
    UPROPERTY()
    TArray<FVector> FlightNodes;

    // The flight volume. Invalid: the bat looks for a volume tagged TAG_MarsBatFlightVolume (the nearest) each sense
    // interval until it has one, reporting NoVolume for any FlyTo meanwhile.
    UPROPERTY()
    FCk_Handle_VoxelNavVolume Volume;

    // Health, the body zone, the corpse time and the team. MonsterTag unset is filled with Monster.Mars.Bat by Add.
    UPROPERTY()
    FMars_Monster_Spec Monster = FMars_Monster_Spec(FGameplayTag(), FMars_Health_Spec(40.0f),
        utils_hit_zone::Make_FleshZoneSpec(GameplayTags::HitZone_Mars_Body, 1.0f), 6.0f, ECk_Team_ID::Two);
}

//--------------------------------------------------------------------------------------------------------------------------
// Validation
//--------------------------------------------------------------------------------------------------------------------------

mixin FMars_Validation Validate(const FMars_Bat_Flight& Self)
{
    if (utils_bat::Get_IsPositiveFinite(Self.CruiseSpeed) == false || utils_bat::Get_IsPositiveFinite(Self.SwoopSpeed) == false ||
        utils_bat::Get_IsPositiveFinite(Self.MaxAcceleration) == false || utils_bat::Get_IsPositiveFinite(Self.MaxTurnRate) == false ||
        utils_bat::Get_IsPositiveFinite(Self.AgentRadius) == false || utils_bat::Get_IsPositiveFinite(Self.ArrivalRadius) == false)
    { return FMars_Validation(f"Bat flight has a non-positive CruiseSpeed [{Self.CruiseSpeed}], SwoopSpeed [{Self.SwoopSpeed}], MaxAcceleration [{Self.MaxAcceleration}], MaxTurnRate [{Self.MaxTurnRate}], AgentRadius [{Self.AgentRadius}] or ArrivalRadius [{Self.ArrivalRadius}]"); }

    return FMars_Validation();
}

mixin FMars_Validation Validate(const FMars_Bat_Sensing& Self)
{
    if (utils_bat::Get_IsPositiveFinite(Self.AcquireRadius) == false || Self.LoseRadius < Self.AcquireRadius ||
        utils_bat::Get_IsPositiveFinite(Self.HomeRadius) == false || utils_bat::Get_IsPositiveFinite(Self.SenseInterval) == false)
    { return FMars_Validation(f"Bat sensing has a bad AcquireRadius [{Self.AcquireRadius}], LoseRadius [{Self.LoseRadius}], HomeRadius [{Self.HomeRadius}] or SenseInterval [{Self.SenseInterval}]"); }

    if (Self.SearchSeconds.IsSet() && utils_bat::Get_IsPositiveFinite(Self.SearchSeconds.GetValue()) == false)
    { return FMars_Validation(f"Bat sensing has a non-positive SearchSeconds [{Self.SearchSeconds.GetValue()}]"); }

    return FMars_Validation();
}

mixin FMars_Validation Validate(const FMars_Bat_Swoop& Self)
{
    const auto& Timing = Self.Timing;
    if (utils_bat::Get_IsPositiveFinite(Timing.TelegraphSeconds) == false || utils_bat::Get_IsPositiveFinite(Timing.SwoopSeconds) == false ||
        utils_bat::Get_IsPositiveFinite(Timing.RecoverSeconds) == false || Math::IsFinite(Timing.CooldownSeconds) == false || Timing.CooldownSeconds < 0.0f)
    { return FMars_Validation(f"Bat swoop has a non-positive phase (telegraph [{Timing.TelegraphSeconds}], swoop [{Timing.SwoopSeconds}], recover [{Timing.RecoverSeconds}]) or a negative cooldown [{Timing.CooldownSeconds}]"); }

    const auto& Blow = Self.Blow;
    if (Math::IsFinite(Blow.Damage) == false || Blow.Damage < 0.0f || utils_bat::Get_IsPositiveFinite(Blow.ContactRadius) == false ||
        Blow.DamageType.IsValid() == false || Blow.MouthOffset.ContainsNaN())
    { return FMars_Validation(f"Bat swoop blow has a bad Damage [{Blow.Damage}], ContactRadius [{Blow.ContactRadius}], DamageType [{Blow.DamageType.ToString()}] or MouthOffset"); }

    if (utils_bat::Get_IsPositiveFinite(Self.Range) == false || Math::IsFinite(Self.Height) == false || Self.Height < 0.0f ||
        Math::IsFinite(Self.Standoff) == false || Self.Standoff < 0.0f || Math::IsFinite(Self.AimHeight) == false)
    { return FMars_Validation(f"Bat swoop has a bad Range [{Self.Range}], Height [{Self.Height}], Standoff [{Self.Standoff}] or AimHeight [{Self.AimHeight}]"); }

    return FMars_Validation();
}

mixin FMars_Validation Validate(const FMars_Bat_Roost& Self)
{
    if (Self.PerchLocation.IsSet() && Self.PerchLocation.GetValue().ContainsNaN())
    { return FMars_Validation("Bat roost has a NaN PerchLocation"); }

    if (Self.DiscoverRadius.IsSet() && utils_bat::Get_IsPositiveFinite(Self.DiscoverRadius.GetValue()) == false)
    { return FMars_Validation(f"Bat roost has a non-positive DiscoverRadius [{Self.DiscoverRadius.GetValue()}]"); }

    if (Self.HangOffset.ContainsNaN() || utils_bat::Get_IsPositiveFinite(Self.AlertSeconds) == false ||
        utils_bat::Get_IsPositiveFinite(Self.LaunchSeconds) == false || utils_bat::Get_IsPositiveFinite(Self.PerchSeconds) == false)
    { return FMars_Validation(f"Bat roost has a NaN HangOffset or a non-positive AlertSeconds [{Self.AlertSeconds}], LaunchSeconds [{Self.LaunchSeconds}] or PerchSeconds [{Self.PerchSeconds}]"); }

    return FMars_Validation();
}

mixin FMars_Validation Validate(const FMars_Bat_Timing& Self)
{
    if (utils_bat::Get_IsPositiveFinite(Self.HitSeconds) == false || utils_bat::Get_IsPositiveFinite(Self.StunSeconds) == false ||
        Math::IsFinite(Self.StunDamage) == false || Self.StunDamage < 0.0f || utils_bat::Get_IsPositiveFinite(Self.HoverRetrySeconds) == false ||
        utils_bat::Get_IsPositiveFinite(Self.MaxFallSeconds) == false)
    { return FMars_Validation(f"Bat timing has a bad HitSeconds [{Self.HitSeconds}], StunSeconds [{Self.StunSeconds}], StunDamage [{Self.StunDamage}], HoverRetrySeconds [{Self.HoverRetrySeconds}] or MaxFallSeconds [{Self.MaxFallSeconds}]"); }

    if (Self.RoostIdleSeconds.IsSet() && utils_bat::Get_IsPositiveFinite(Self.RoostIdleSeconds.GetValue()) == false)
    { return FMars_Validation(f"Bat timing has a non-positive RoostIdleSeconds [{Self.RoostIdleSeconds.GetValue()}]"); }

    if ((Self.RetreatDistance.IsSet() && utils_bat::Get_IsPositiveFinite(Self.RetreatDistance.GetValue()) == false) ||
        utils_bat::Get_IsPositiveFinite(Self.RetreatSeconds) == false)
    { return FMars_Validation(f"Bat timing has a non-positive RetreatDistance or RetreatSeconds [{Self.RetreatSeconds}]"); }

    return FMars_Validation();
}

mixin FMars_Validation Validate(const FMars_Bat_Spec& Self)
{
    auto Validation = Self.Flight.Validate();
    if (Validation.IsValid() == false)
    { return Validation; }

    Validation = Self.Sensing.Validate();
    if (Validation.IsValid() == false)
    { return Validation; }

    Validation = Self.Swoop.Validate();
    if (Validation.IsValid() == false)
    { return Validation; }

    Validation = Self.Roost.Validate();
    if (Validation.IsValid() == false)
    { return Validation; }

    Validation = Self.Timing.Validate();
    if (Validation.IsValid() == false)
    { return Validation; }

    for (const auto& Node : Self.FlightNodes)
    {
        if (Node.ContainsNaN())
        { return FMars_Validation("Bat has a NaN flight node"); }
    }

    return Self.Monster.Validate();
}

//--------------------------------------------------------------------------------------------------------------------------
// Params
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Fragment_Bat_Params
{
    UPROPERTY()
    FMars_Bat_Spec Spec;

    UPROPERTY()
    FCk_Handle_Monster Monster;

    UPROPERTY()
    FCk_Handle_DamageDealer Dealer;

    UPROPERTY()
    FCk_Handle_CrowdAgent Agent;

    UPROPERTY()
    FCk_Handle_VoxelNavPath Path;

    // The perch anchor with no owner: Spec.Roost.PerchLocation, else the spawn point.
    UPROPERTY()
    FVector FixedPerchAnchor;
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

// The route: one FlyTo at a time, each answered once.
struct FMars_Bat_Route
{
    UPROPERTY()
    EMars_Bat_RouteOutcome Outcome = EMars_Bat_RouteOutcome::None;

    // Bumped by every FlyTo the kernel accepts or refuses.
    UPROPERTY()
    int32 Generation = 0;

    UPROPERTY()
    FVector Goal;

    UPROPERTY()
    float32 Speed = 0.0f;

    // The phase the kernel was in when it took the FlyTo: a condition only trusts an answer to a route of its own phase.
    UPROPERTY()
    EMars_Bat_Phase IssuedIn = EMars_Bat_Phase::Roosting;

    UPROPERTY()
    FCk_Handle_VoxelNavVolume Volume;
}

// The swoop ledger. One Generation per StartSwoop admitted; at most one damage result per generation (Results), and
// sweeps happen only while Stage is Committed and the bat is alive.
struct FMars_Bat_SwoopLedger
{
    UPROPERTY()
    EMars_Bat_SwoopStage Stage = EMars_Bat_SwoopStage::None;

    UPROPERTY()
    int32 Generation = 0;

    UPROPERTY()
    float32 StageElapsed = 0.0f;

    UPROPERTY()
    FCk_Handle Target;

    // Where it committed from (it recovers back there) and the point it swoops through.
    UPROPERTY()
    FVector From;

    UPROPERTY()
    FVector Goal;

    UPROPERTY()
    FVector LastMouth;

    // The zones this generation hurt (0 or 1).
    UPROPERTY()
    TArray<FCk_Handle_HitZone> HitZones;

    UPROPERTY()
    float32 Cooldown = 0.0f;

    // Totals over the bat's life, for the readers and tests.
    UPROPERTY()
    int32 Landed = 0;

    UPROPERTY()
    int32 Cancelled = 0;
}

struct FMars_Bat_Perch
{
    UPROPERTY()
    EMars_Bat_RoostClaim Claim = EMars_Bat_RoostClaim::Unowned;

    // The roost entity claimed or being claimed (invalid when Unowned).
    UPROPERTY()
    FCk_Handle Owner;
}

struct FMars_Bat_Hurt
{
    UPROPERTY()
    float32 HitLeft = 0.0f;

    UPROPERTY()
    float32 StunLeft = 0.0f;

    UPROPERTY()
    int32 HitCount = 0;
}

// Measured by the tick from the root's own motion; the presentation reads it (it never moves the bat).
struct FMars_Bat_Telemetry
{
    UPROPERTY()
    FVector Velocity = FVector::ZeroVector;

    UPROPERTY()
    float32 Speed = 0.0f;

    // Degrees a second, positive turning right (yaw increasing).
    UPROPERTY()
    float32 SignedTurnRate = 0.0f;

    // Degrees, nose up positive.
    UPROPERTY()
    float32 Pitch = 0.0f;

    UPROPERTY()
    FVector LastLocation = FVector::ZeroVector;

    UPROPERTY()
    float64 LastYaw = 0.0;

    UPROPERTY()
    bool HasSample = false;
}

// The death fall, integrated by the tick once the crowd agent is disabled.
struct FMars_Bat_Fall
{
    UPROPERTY()
    FVector Velocity = FVector::ZeroVector;

    UPROPERTY()
    float32 Elapsed = 0.0f;
}

// Written only by the bat's processors (HandleRequests, Setup, Targeting, Tick).
struct FMars_Fragment_Bat
{
    UPROPERTY()
    EMars_Bat_Phase Phase = EMars_Bat_Phase::Roosting;

    // Seconds in the current phase.
    UPROPERTY()
    float32 PhaseClock = 0.0f;

    UPROPERTY()
    FCk_Handle Target;

    UPROPERTY()
    float32 SenseClock = 0.0f;

    // The target's motion as the senses saw it: its location at the last sense and the velocity between the last two
    // (zero until two senses of the same target), so a committed swoop can lead a moving target.
    UPROPERTY()
    TOptional<FVector> TargetLastLocation;

    UPROPERTY()
    FVector TargetVelocity = FVector::ZeroVector;

    // Where a hostile target it lost by distance (past LoseRadius, still within HomeRadius) was last sensed, with
    // Sensing.SearchSeconds set: kept until a target is held again, the control layer ends its search (EndSearch) or it
    // falls. A target that died or turned friendly leaves no memory.
    UPROPERTY()
    TOptional<FVector> LastKnown;

    // A target it could not fly to (an Approaching route failed) is passed over for IgnoreLeft seconds.
    UPROPERTY()
    FCk_Handle Ignored;

    UPROPERTY()
    float32 IgnoreLeft = 0.0f;

    UPROPERTY()
    FMars_Bat_Route Route;

    UPROPERTY()
    FMars_Bat_SwoopLedger Swoop;

    UPROPERTY()
    FMars_Bat_Perch Perch;

    UPROPERTY()
    FMars_Bat_Hurt Hurt;

    UPROPERTY()
    FMars_Bat_Telemetry Telemetry;

    UPROPERTY()
    FMars_Bat_Fall Fall;
}

// The control layer's own working state (the patrol's next node), written only by UMars_SmTask_Bat_Patrol; no processor
// reads it.
struct FMars_Fragment_Bat_PatrolBlackboard
{
    UPROPERTY()
    int32 NextNode = 0;

    UPROPERTY()
    int32 Visited = 0;

    UPROPERTY()
    EMars_Bat_PatrolProgress Progress = EMars_Bat_PatrolProgress::Flying;
}

// The control layer's sortie memory, written only by UMars_SmTask_Bat_Launch (clears it) and UMars_SmTask_Bat_Telegraph
// (sets it); no processor reads it.
struct FMars_Fragment_Bat_SortieBlackboard
{
    // This sortie's first telegraph has been named Screeching.
    UPROPERTY()
    bool Screeched = false;
}

enum EMars_Bat_PatrolProgress
{
    Flying,
    Finished
}

// The control layer's search memory, written only by UMars_SmTask_Bat_Search; no processor reads it.
struct FMars_Fragment_Bat_SearchBlackboard
{
    // The kernel's phase clock when it came within reach of the search point (unset: still on its way).
    UPROPERTY()
    TOptional<float32> ArrivedClock;
}

//--------------------------------------------------------------------------------------------------------------------------
// Roost (on the perch entity, utils_bat::Add_Roost)
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Feature_BatRoost {}

// One bat at a time. Written only by UMars_Processor_BatRoost_HandleRequests and UMars_Processor_BatRoost_Tick (which
// releases a claimant that has gone away): ReleaseCount counts every hand-back, whichever path made it.
enum EMars_BatRoost_Occupancy
{
    Free,
    Claimed
}

struct FMars_Fragment_BatRoost
{
    UPROPERTY()
    EMars_BatRoost_Occupancy Occupancy = EMars_BatRoost_Occupancy::Free;

    UPROPERTY()
    FCk_Handle Claimant;

    UPROPERTY()
    int32 ClaimCount = 0;

    UPROPERTY()
    int32 ReleaseCount = 0;
}

struct FMars_Request_BatRoost_Claim
{
    UPROPERTY()
    FCk_Handle Bat;

    FMars_Request_BatRoost_Claim() {}

    FMars_Request_BatRoost_Claim(FCk_Handle InBat)
    {
        Bat = InBat;
    }
}

// Only the claimant's release counts.
struct FMars_Request_BatRoost_Release
{
    UPROPERTY()
    FCk_Handle Bat;

    FMars_Request_BatRoost_Release() {}

    FMars_Request_BatRoost_Release(FCk_Handle InBat)
    {
        Bat = InBat;
    }
}

// Applied Release -> Claim, each kind in arrival order.
struct FMars_Fragment_BatRoost_Requests
{
    UPROPERTY()
    TArray<FMars_Request_BatRoost_Release> ReleaseRequests;

    UPROPERTY()
    TArray<FMars_Request_BatRoost_Claim> ClaimRequests;
}

//--------------------------------------------------------------------------------------------------------------------------
// Signals
//--------------------------------------------------------------------------------------------------------------------------

delegate void FMars_Delegate_Bat_OnPhaseChanged(FCk_Handle_Bat InBat, EMars_Bat_Phase InFrom, EMars_Bat_Phase InTo);
event void FMars_Delegate_Bat_OnPhaseChanged_MC(FCk_Handle_Bat InBat, EMars_Bat_Phase InFrom, EMars_Bat_Phase InTo);

// The one damage result of swoop InGeneration (the zone's own OnHit carries the damage).
delegate void FMars_Delegate_Bat_OnSwoopLanded(FCk_Handle_Bat InBat, int32 InGeneration, FCk_Handle_HitZone InZone);
event void FMars_Delegate_Bat_OnSwoopLanded_MC(FCk_Handle_Bat InBat, int32 InGeneration, FCk_Handle_HitZone InZone);

delegate void FMars_Delegate_Bat_OnSwoopCancelled(FCk_Handle_Bat InBat, int32 InGeneration, EMars_Bat_SwoopCancel InReason);
event void FMars_Delegate_Bat_OnSwoopCancelled_MC(FCk_Handle_Bat InBat, int32 InGeneration, EMars_Bat_SwoopCancel InReason);

// Every answer to a FlyTo (Reached and each failure), once per route generation.
delegate void FMars_Delegate_Bat_OnRouteOutcome(FCk_Handle_Bat InBat, int32 InGeneration, EMars_Bat_RouteOutcome InOutcome);
event void FMars_Delegate_Bat_OnRouteOutcome_MC(FCk_Handle_Bat InBat, int32 InGeneration, EMars_Bat_RouteOutcome InOutcome);

delegate void FMars_Delegate_Bat_OnPerchLost(FCk_Handle_Bat InBat, FCk_Handle InOwner);
event void FMars_Delegate_Bat_OnPerchLost_MC(FCk_Handle_Bat InBat, FCk_Handle InOwner);

delegate void FMars_Delegate_Bat_OnTargetChanged(FCk_Handle_Bat InBat, FCk_Handle InTarget);
event void FMars_Delegate_Bat_OnTargetChanged_MC(FCk_Handle_Bat InBat, FCk_Handle InTarget);

struct FMars_Fragment_Bat_Signals
{
    FMars_Delegate_Bat_OnPhaseChanged_MC OnPhaseChanged;
    FMars_Delegate_Bat_OnSwoopLanded_MC OnSwoopLanded;
    FMars_Delegate_Bat_OnSwoopCancelled_MC OnSwoopCancelled;
    FMars_Delegate_Bat_OnRouteOutcome_MC OnRouteOutcome;
    FMars_Delegate_Bat_OnPerchLost_MC OnPerchLost;
    FMars_Delegate_Bat_OnTargetChanged_MC OnTargetChanged;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

// A behaviour phase (Roosting .. Perching, Hovering, Searching, Retreating). Dropped while a swoop runs, while hurt and
// once dead or falling: the kernel's own phases win.
struct FMars_Request_Bat_SetPhase
{
    UPROPERTY()
    EMars_Bat_Phase Phase = EMars_Bat_Phase::Roosting;

    FMars_Request_Bat_SetPhase() {}

    FMars_Request_Bat_SetPhase(EMars_Bat_Phase InPhase)
    {
        Phase = InPhase;
    }
}

// Fly to Goal (world) at Speed. Refused with an explicit outcome (NoVolume, NoBake, EndpointUnresolvable) when the
// route cannot even be asked for; otherwise Pending until the agent or the path answers.
struct FMars_Request_Bat_FlyTo
{
    UPROPERTY()
    FVector Goal;

    UPROPERTY()
    float32 Speed = 0.0f;

    FMars_Request_Bat_FlyTo() {}

    FMars_Request_Bat_FlyTo(FVector InGoal, float32 InSpeed)
    {
        Goal = InGoal;
        Speed = InSpeed;
    }
}

// Stop where it is (the crowd agent's Stop) and drop the route.
struct FMars_Request_Bat_Hold
{
    UPROPERTY()
    bool _Placeholder = false;
}

// An answer from the crowd agent or the voxel path (fed by the setup processor's bindings).
struct FMars_Request_Bat_RouteResult
{
    UPROPERTY()
    EMars_Bat_RouteOutcome Outcome = EMars_Bat_RouteOutcome::Reached;

    // The route generation this answer belongs to, when the answerer knows it (the crowd agent's active move correlation
    // id, stamped by Issue_Move); unset = unknown, taken as the current route. An answer for another generation is dropped.
    UPROPERTY()
    TOptional<int32> Generation;

    FMars_Request_Bat_RouteResult() {}

    FMars_Request_Bat_RouteResult(EMars_Bat_RouteOutcome InOutcome)
    {
        Outcome = InOutcome;
    }

    FMars_Request_Bat_RouteResult(EMars_Bat_RouteOutcome InOutcome, int32 InGeneration)
    {
        Outcome = InOutcome;
        Generation = InGeneration;
    }
}

// Telegraph a swoop at Target if it is admissible now (Get_SwoopAdmission); a refusal is dropped.
struct FMars_Request_Bat_StartSwoop
{
    UPROPERTY()
    FCk_Handle Target;

    FMars_Request_Bat_StartSwoop() {}

    FMars_Request_Bat_StartSwoop(FCk_Handle InTarget)
    {
        Target = InTarget;
    }
}

// Ends a telegraphed or committed swoop now (no recovery); its cooldown still starts. Nothing when none runs.
struct FMars_Request_Bat_CancelSwoop
{
    UPROPERTY()
    EMars_Bat_SwoopCancel Reason = EMars_Bat_SwoopCancel::Cancelled;

    FMars_Request_Bat_CancelSwoop() {}

    FMars_Request_Bat_CancelSwoop(EMars_Bat_SwoopCancel InReason)
    {
        Reason = InReason;
    }
}

// A blow landed on its body zone (fed from the zone's OnHit). Unless dead: Hit (or Stunned at StunDamage), the agent
// stops, a running swoop is Interrupted.
struct FMars_Request_Bat_TakeHit
{
    UPROPERTY()
    FMars_DamageEvent Event;

    FMars_Request_Bat_TakeHit() {}

    FMars_Request_Bat_TakeHit(FMars_DamageEvent InEvent)
    {
        Event = InEvent;
    }
}

// The death teardown's movement half: the agent stops and leaves the crowd, a running swoop ends (Died), and the bat
// falls (Falling, then Landed on the ground the tick finds). Latched.
struct FMars_Request_Bat_Fall
{
    UPROPERTY()
    bool _Placeholder = false;
}

// Gives the perch back (Released). Only the first does anything.
struct FMars_Request_Bat_ReleaseRoost
{
    UPROPERTY()
    bool _Placeholder = false;
}

// The control layer is done looking where its target was last sensed: Get_LastKnown is forgotten. Nothing when none is
// held.
struct FMars_Request_Bat_EndSearch
{
    UPROPERTY()
    bool _Placeholder = false;
}

// Applied Fall -> TakeHit -> CancelSwoop -> RouteResult -> Hold -> SetPhase -> FlyTo -> StartSwoop -> ReleaseRoost ->
// EndSearch, each kind in arrival order.
struct FMars_Fragment_Bat_Requests
{
    UPROPERTY()
    TArray<FMars_Request_Bat_Fall> FallRequests;

    UPROPERTY()
    TArray<FMars_Request_Bat_TakeHit> TakeHitRequests;

    UPROPERTY()
    TArray<FMars_Request_Bat_CancelSwoop> CancelSwoopRequests;

    UPROPERTY()
    TArray<FMars_Request_Bat_RouteResult> RouteResultRequests;

    UPROPERTY()
    TArray<FMars_Request_Bat_Hold> HoldRequests;

    UPROPERTY()
    TArray<FMars_Request_Bat_FlyTo> FlyToRequests;

    UPROPERTY()
    TArray<FMars_Request_Bat_SetPhase> SetPhaseRequests;

    UPROPERTY()
    TArray<FMars_Request_Bat_StartSwoop> StartSwoopRequests;

    UPROPERTY()
    TArray<FMars_Request_Bat_ReleaseRoost> ReleaseRoostRequests;

    UPROPERTY()
    TArray<FMars_Request_Bat_EndSearch> EndSearchRequests;
}
