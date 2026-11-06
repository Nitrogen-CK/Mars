// The bat's one clock, after the request drain, every frame:
// 0. the flight volume: with none known it finds the nearest tagged TAG_MarsBatFlightVolume and binds its path to it;
// 1. the perch: a Pending claim with no owner looks for a roost within DiscoverRadius and claims it; a Pending claim the
//    roost granted becomes Held; a Held (or Pending) claim whose roost went away or went to another bat becomes Lost and
//    broadcasts OnPerchLost once;
// 2. the hurt clocks run down;
// 3. the swoop: the cooldown runs down; a dead bat's swoop ends Died; Telegraphing holds (a target gone invalid ends it
//    TargetLost) and commits when TelegraphSeconds pass, flying through the aim point at SwoopSpeed; Committed sweeps the
//    mouth from its last place each frame until one result lands (the ledger's HitZones), and recovers after SwoopSeconds,
//    flying back to where it committed; Recovering ends after RecoverSeconds and starts the cooldown;
// 4. the death fall (Falling): gravity on the fall velocity, a static-world ray from where it is to where it would be, and
//    on contact it rests there (Landed) - or Landed where it is after MaxFallSeconds with no ground;
// 5. a bat whose own spot is not goal-free after its route failed (the agent overshot into a wall's clearance band, where
//    no path can start) climbs toward the nearest goal-free point at half cruise, so the next route can be asked for;
// 6. telemetry from the root's own motion (speed, signed turn rate, pitch);
// 7. the phase clock.
// The crowd agent writes the root transform while the bat flies; this processor writes it only while Falling, after the
// agent was taken out of the crowd.
class UMars_Processor_Bat_Tick : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _RunAfter.Add(n"/Script/Angelscript.Mars_Processor_Bat_HandleRequests");

    // cm/s^2.
    private const float64 k_Gravity = 980.0;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Bat);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle)
    {
        if (utils_entity_lifetime::Get_IsPendingDestroy(InHandle, ECk_EntityLifetime_DestructionPhase::BeginDestroy))
        { return; }

        auto Self = InHandle.As_Bat();
        const auto DeltaSeconds = float32(InDeltaT.Get_Seconds());

        TickVolume(Self);
        TickPerch(Self);
        TickHurt(Self, DeltaSeconds);
        TickSwoop(Self, DeltaSeconds);
        TickFall(Self, DeltaSeconds);
        TickUnstick(Self, DeltaSeconds);
        TickTelemetry(Self, DeltaSeconds);

        Self.Get_Fragment(FMars_Fragment_Bat).PhaseClock += DeltaSeconds;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Volume
    //----------------------------------------------------------------------------------------------------------------------

    private void TickVolume(FCk_Handle_Bat& InSelf)
    {
        if (ck::IsValid(InSelf.Get_Volume()))
        { return; }

        const auto Here = InSelf.Get_Location();
        auto Best = FCk_Handle_VoxelNavVolume();
        auto BestDistance = 0.0;
        for (auto Candidate : utils_entity_tag::ForEach_Entity(InSelf, utils_bat::FlightVolumeTag))
        {
            if (utils_entity_lifetime::Get_IsPendingDestroy(Candidate, ECk_EntityLifetime_DestructionPhase::BeginDestroy))
            { continue; }

            const auto Volume = Candidate.As_VoxelNavVolume(ECk_SanityCheck::UnChecked);
            if (ck::Is_NOT_Valid(Volume))
            { continue; }

            const auto Owner = utils_entity_lifetime::Get_LifetimeOwner(Candidate);
            const auto OwnerTransform = Owner.As_Transform(ECk_SanityCheck::UnChecked);
            const auto Distance = ck::IsValid(OwnerTransform) ? (utils_transform::Get_EntityCurrentLocation(OwnerTransform) - Here).Size() : 0.0;
            if (ck::Is_NOT_Valid(Best) || Distance < BestDistance)
            {
                Best = Volume;
                BestDistance = Distance;
            }
        }

        if (ck::Is_NOT_Valid(Best))
        { return; }

        InSelf.Get_Fragment(FMars_Fragment_Bat).Route.Volume = Best;
        utils_voxel_nav_path::Request_SetVolume(InSelf.Get_Path(), Best);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Perch
    //----------------------------------------------------------------------------------------------------------------------

    private void TickPerch(FCk_Handle_Bat& InSelf)
    {
        auto Perch = InSelf.Get_Fragment(FMars_Fragment_Bat).Perch;
        if (Perch.Claim != EMars_Bat_RoostClaim::Pending && Perch.Claim != EMars_Bat_RoostClaim::Held)
        { return; }

        if (Perch.Claim == EMars_Bat_RoostClaim::Pending && ck::Is_NOT_Valid(Perch.Owner))
        {
            const auto Found = Find_Roost(InSelf);
            if (ck::Is_NOT_Valid(Found))
            { return; }

            InSelf.Get_Fragment(FMars_Fragment_Bat).Perch.Owner = Found;
            utils_bat::Request_ClaimRoost(Found, FMars_Request_BatRoost_Claim(InSelf));
            return;
        }

        FCk_Handle Self = InSelf;
        const auto Roost = utils_bat::Get_RoostState(Perch.Owner);
        const auto Gone = utils_bat::Get_IsRoost(Perch.Owner) == false;
        const auto Mine = Roost.Occupancy == EMars_BatRoost_Occupancy::Claimed && Roost.Claimant == Self;
        const auto Taken = Roost.Occupancy == EMars_BatRoost_Occupancy::Claimed && Roost.Claimant != Self;
        if (Gone == false && Taken == false)
        {
            if (Mine && Perch.Claim == EMars_Bat_RoostClaim::Pending)
            { InSelf.Get_Fragment(FMars_Fragment_Bat).Perch.Claim = EMars_Bat_RoostClaim::Held; }

            // Pending and not granted yet (the claim is in the roost's queue), or Held and still mine.
            if (Mine || (Roost.Occupancy == EMars_BatRoost_Occupancy::Free && Perch.Claim == EMars_Bat_RoostClaim::Pending))
            { return; }
        }

        InSelf.Get_Fragment(FMars_Fragment_Bat).Perch.Claim = EMars_Bat_RoostClaim::Lost;
        utils_bat::Broadcast_PerchLost(InSelf, Perch.Owner);
    }

    private FCk_Handle Find_Roost(const FCk_Handle_Bat& InSelf) const
    {
        const auto Radius = InSelf.Get_Spec().Roost.DiscoverRadius;
        if (Radius.IsSet() == false)
        { return FCk_Handle(); }

        const auto Anchor = InSelf.Get_Fragment(FMars_Fragment_Bat_Params).FixedPerchAnchor;
        auto Best = FCk_Handle();
        auto BestDistance = 0.0;
        for (auto Candidate : utils_entity_tag::ForEach_Entity(InSelf, utils_bat::RoostTag))
        {
            if (utils_bat::Get_IsRoost(Candidate) == false ||
                utils_bat::Get_RoostState(Candidate).Occupancy == EMars_BatRoost_Occupancy::Claimed)
            { continue; }

            const auto Distance = (utils_bat::Get_RoostAnchor(Candidate) - Anchor).Size();
            if (Distance > Radius.GetValue())
            { continue; }

            if (ck::Is_NOT_Valid(Best) || Distance < BestDistance)
            {
                Best = Candidate;
                BestDistance = Distance;
            }
        }

        return Best;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Hurt
    //----------------------------------------------------------------------------------------------------------------------

    private void TickHurt(FCk_Handle_Bat& InSelf, float32 InDeltaSeconds)
    {
        auto& Hurt = InSelf.Get_Fragment(FMars_Fragment_Bat).Hurt;
        Hurt.HitLeft = Math::Max(Hurt.HitLeft - InDeltaSeconds, 0.0f);
        Hurt.StunLeft = Math::Max(Hurt.StunLeft - InDeltaSeconds, 0.0f);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Swoop
    //----------------------------------------------------------------------------------------------------------------------

    private void TickSwoop(FCk_Handle_Bat& InSelf, float32 InDeltaSeconds)
    {
        auto& Ledger = InSelf.Get_Fragment(FMars_Fragment_Bat).Swoop;
        Ledger.Cooldown = Math::Max(Ledger.Cooldown - InDeltaSeconds, 0.0f);
        if (Ledger.Stage == EMars_Bat_SwoopStage::None)
        { return; }

        // Damage stops the frame the body is depleted (before the Dead attribute latches), whatever the control layer has
        // caught up with.
        if (Get_IsDying(InSelf))
        {
            utils_bat::End_Swoop(InSelf, EMars_Bat_SwoopCancel::Died);
            utils_bat::Stop_Agent(InSelf);
            return;
        }

        const auto Spec = InSelf.Get_Spec();
        Ledger.StageElapsed += InDeltaSeconds;
        const auto Stage = Ledger.Stage;
        const auto Over = Ledger.StageElapsed >= utils_bat::Get_StageSeconds(Spec.Swoop.Timing, Stage);

        if (Stage == EMars_Bat_SwoopStage::Telegraphing)
        {
            if (utils_bat::Get_IsTargetValid(Ledger.Target) == false)
            {
                utils_bat::End_Swoop(InSelf, EMars_Bat_SwoopCancel::TargetLost);
                utils_bat::Stop_Agent(InSelf);
                return;
            }

            FaceAimPoint(InSelf, InDeltaSeconds);
            if (Over)
            { Commit(InSelf); }

            return;
        }

        if (Stage == EMars_Bat_SwoopStage::Committed)
        {
            Sweep(InSelf);
            if (Over)
            { Recover(InSelf); }

            return;
        }

        if (Over)
        { utils_bat::End_Swoop(InSelf, EMars_Bat_SwoopCancel::Cancelled); }
    }

    // Through the aim point (led by the target's velocity) at SwoopSpeed; the line it flies is fixed from here on.
    private void Commit(FCk_Handle_Bat& InSelf)
    {
        const auto Spec = InSelf.Get_Spec();
        auto& Ledger = InSelf.Get_Fragment(FMars_Fragment_Bat).Swoop;
        Ledger.Stage = EMars_Bat_SwoopStage::Committed;
        Ledger.StageElapsed = 0.0f;
        // Through where the target will be when the mouth gets there, not where it is: a walking target is still met.
        // The dive starts from a standstill and the agent accelerates at MaxAcceleration toward SwoopSpeed, so the time to
        // contact (the aim point less the blow's reach) follows that profile, not a constant speed. The lead is capped at
        // Standoff so a sensing glitch cannot send the dive across the room.
        const auto AimNow = utils_transform::Get_EntityCurrentLocation(Ledger.Target.As_Transform()) + FVector(0.0, 0.0, Spec.Swoop.AimHeight);
        const auto Lead = InSelf.Get_TargetVelocity().GetClampedToMaxSize(Spec.Swoop.Standoff) *
            Get_DiveSeconds(Spec, Math::Max((AimNow - InSelf.Get_Location()).Size() - float64(Spec.Swoop.Blow.ContactRadius), 0.0));
        Ledger.Goal = AimNow + Lead;
        Ledger.LastMouth = InSelf.Get_MouthLocation();
        const auto Goal = Ledger.Goal;

        utils_bat::Set_Phase(InSelf, EMars_Bat_Phase::Swooping);
        utils_bat::Issue_Move(InSelf, FMars_Request_Bat_FlyTo(Goal, Spec.Flight.SwoopSpeed));
    }

    // Seconds a dive from rest covers InDistance: accelerating at MaxAcceleration, then at SwoopSpeed once it gets there.
    private float64 Get_DiveSeconds(const FMars_Bat_Spec& InSpec, float64 InDistance) const
    {
        const float64 Speed = InSpec.Flight.SwoopSpeed;
        const float64 Acceleration = InSpec.Flight.MaxAcceleration;
        const auto AccelDistance = 0.5 * Speed * Speed / Acceleration;
        if (InDistance <= AccelDistance)
        { return Math::Sqrt(2.0 * InDistance / Acceleration); }

        return Speed / Acceleration + (InDistance - AccelDistance) / Speed;
    }

    // Pulls out by carrying THROUGH: the mirror of the strike point on the far side of the aim point (Standoff past it along
    // the dive line, Height up), so the bat keeps facing the way it flew and the next approach turns it back onto the
    // target. Only when that point is not goal-free (a wall or a pillar behind the target) does it fly back to where it
    // committed from, the way it came.
    private void Recover(FCk_Handle_Bat& InSelf)
    {
        const auto Spec = InSelf.Get_Spec();
        auto& Ledger = InSelf.Get_Fragment(FMars_Fragment_Bat).Swoop;
        Ledger.Stage = EMars_Bat_SwoopStage::Recovering;
        Ledger.StageElapsed = 0.0f;
        const auto From = Ledger.From;
        const auto Aim = Ledger.Goal;

        auto Dive = Aim - From;
        Dive.Z = 0.0;
        Dive = Dive.GetSafeNormal();
        const auto Through = Aim + Dive * Spec.Swoop.Standoff + FVector(0.0, 0.0, Spec.Swoop.Height);
        const auto ThroughIsFree = Dive.IsNearlyZero() == false && InSelf.Get_IsNavReady() && InSelf.Get_IsGoalFree(Through);

        utils_bat::Set_Phase(InSelf, EMars_Bat_Phase::Recovering);
        utils_bat::Issue_Move(InSelf, FMars_Request_Bat_FlyTo(ThroughIsFree ? Through : From, Spec.Flight.CruiseSpeed));
    }

    // While it telegraphs the agent is stopped, and CkCrowd's facing writer disengages below its speed floor (it holds the
    // body), so the kernel may turn the root itself: yaw and a bounded pitch slew toward the aim point at MaxTurnRate.
    // Without this the bat telegraphs facing whatever heading its last leg left it on (after a pull-out, away from the
    // target).
    private void FaceAimPoint(FCk_Handle_Bat& InSelf, float32 InDeltaSeconds)
    {
        if (InDeltaSeconds <= 0.0f)
        { return; }

        const auto Aim = InSelf.Get_TargetAimPoint();
        const auto Here = InSelf.Get_Location();
        const auto ToAim = Aim - Here;
        if (ToAim.IsNearlyZero())
        { return; }

        const auto Wanted = ToAim.Rotation();
        const auto Current = InSelf.Get_RootTransform().GetRotation().Rotator();
        const float64 MaxStep = float64(InSelf.Get_Spec().Flight.MaxTurnRate) * float64(InDeltaSeconds);
        const auto YawDelta = Math::Clamp(Math::FindDeltaAngleDegrees(Current.Yaw, Wanted.Yaw), -MaxStep, MaxStep);
        const auto WantedPitch = Math::Clamp(Wanted.Pitch, TelegraphPitchMin, TelegraphPitchMax);
        const auto PitchDelta = Math::Clamp(Math::FindDeltaAngleDegrees(Current.Pitch, WantedPitch), -MaxStep, MaxStep);

        auto Root = InSelf.As_Transform();
        utils_transform::Request_SetRotation(Root, FCk_Request_Transform_SetRotation(
            FRotator(Current.Pitch + PitchDelta, Current.Yaw + YawDelta, 0.0)));
    }

    // The nose may dip toward a target below it while telegraphing, but never stand on its head.
    private const float64 TelegraphPitchMin = -50.0;
    private const float64 TelegraphPitchMax = 20.0;

    // The mouth through the frame: a swept sphere from its last place to this one, only while no result has landed this
    // generation. A zone hit is recorded and announced; the damage itself goes through the dealer.
    private void Sweep(FCk_Handle_Bat& InSelf)
    {
        const auto Mouth = InSelf.Get_MouthLocation();
        auto& Ledger = InSelf.Get_Fragment(FMars_Fragment_Bat).Swoop;
        const auto From = Ledger.LastMouth;
        Ledger.LastMouth = Mouth;
        if (Ledger.HitZones.Num() > 0)
        { return; }

        if (Get_IsDying(InSelf))
        {
            utils_bat::End_Swoop(InSelf, EMars_Bat_SwoopCancel::Died);
            utils_bat::Stop_Agent(InSelf);
            return;
        }

        const auto Generation = Ledger.Generation;
        const auto Blow = InSelf.Get_Spec().Swoop.Blow;
        auto Dealer = InSelf.Get_Dealer();
        const auto Result = Dealer.Request_StrikeSweep(FMars_DamageDealer_Sweep(From, Mouth, Blow.ContactRadius),
            utils_damage_dealer::Make_Event(Dealer, Blow.Damage, Blow.DamageType));
        if (ck::Is_NOT_Valid(Result.Get_HitEntity()) || Result.Get_HitKind() != ECk_ProbeTrace_HitKind::Probe)
        { return; }

        auto Zone = utils_hit_zone::TryGet_Zone(Result.Get_HitEntity());
        if (ck::Is_NOT_Valid(Zone))
        { return; }

        // Re-fetched: the damage request above added fragments to this entity.
        auto& Written = InSelf.Get_Fragment(FMars_Fragment_Bat).Swoop;
        Written.HitZones.Add(Zone);
        Written.Landed += 1;
        if (InSelf.Has_Fragment(FMars_Fragment_Bat_Signals))
        { InSelf.Get_Fragment(FMars_Fragment_Bat_Signals).OnSwoopLanded.Broadcast(InSelf, Generation, Zone); }
    }

    // Dead, or the body health depleted and the Dead attribute not latched yet.
    private bool Get_IsDying(const FCk_Handle_Bat& InSelf) const
    {
        if (InSelf.Get_IsDead())
        { return true; }

        const auto Health = InSelf.Get_Monster().Get_BodyHealth();
        return ck::IsValid(Health) && Health.Get_IsDepleted();
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Fall
    //----------------------------------------------------------------------------------------------------------------------

    private void TickFall(FCk_Handle_Bat& InSelf, float32 InDeltaSeconds)
    {
        if (InSelf.Get_Phase() != EMars_Bat_Phase::Falling || InDeltaSeconds <= 0.0f)
        { return; }

        auto Fall = InSelf.Get_Fragment(FMars_Fragment_Bat).Fall;
        Fall.Elapsed += InDeltaSeconds;
        Fall.Velocity.Z -= k_Gravity * InDeltaSeconds;

        const auto Here = InSelf.Get_Location();
        const auto There = Here + Fall.Velocity * InDeltaSeconds;
        auto Filter = FCk_Jolt_QueryFilter();
        Filter.Set_BodySelection(ECk_Jolt_QueryBodySelection::StaticNonSensor);
        const auto Hit = utils_jolt_query::Get_RayCast(Here, There, Filter);

        auto Root = InSelf.As_Transform();
        if (Hit.Get_HasHit())
        {
            Fall.Velocity = FVector::ZeroVector;
            InSelf.Get_Fragment(FMars_Fragment_Bat).Fall = Fall;
            utils_transform::Request_SetLocation(Root, FCk_Request_Transform_SetLocation(Hit.Get_Position() + Hit.Get_Normal() * LandLift));
            utils_bat::Set_Phase(InSelf, EMars_Bat_Phase::Landed);
            return;
        }

        InSelf.Get_Fragment(FMars_Fragment_Bat).Fall = Fall;
        utils_transform::Request_SetLocation(Root, FCk_Request_Transform_SetLocation(There));
        if (Fall.Elapsed >= InSelf.Get_Spec().Timing.MaxFallSeconds)
        { utils_bat::Set_Phase(InSelf, EMars_Bat_Phase::Landed); }
    }

    // A landed body rests this far off the ground along its normal (its belly).
    private const float64 LandLift = 10.0;

    //----------------------------------------------------------------------------------------------------------------------
    // Unstick
    //----------------------------------------------------------------------------------------------------------------------

    // Only while flying under its own wings between routes: the last route failed or it hovers with nowhere to go (the
    // agent is stopped either way), no swoop runs, it is not hurt, hanging or down. Writes the root location itself, as the
    // fall does, while the agent holds.
    private void TickUnstick(FCk_Handle_Bat& InSelf, float32 InDeltaSeconds)
    {
        if (InDeltaSeconds <= 0.0f || InSelf.Get_IsDown() || InSelf.Get_IsHurt() || InSelf.Get_SwoopStage() != EMars_Bat_SwoopStage::None)
        { return; }

        const auto Phase = InSelf.Get_Phase();
        if (Phase == EMars_Bat_Phase::Roosting || Phase == EMars_Bat_Phase::Alert || Phase == EMars_Bat_Phase::Perching)
        { return; }

        const auto Stranded = utils_bat::Get_IsRouteFailure(InSelf.Get_RouteOutcome()) || Phase == EMars_Bat_Phase::Hovering;
        if (Stranded == false || InSelf.Get_IsNavReady() == false)
        { return; }

        const auto Here = InSelf.Get_Location();
        if (InSelf.Get_IsGoalFree(Here))
        { return; }

        const auto Target = InSelf.Get_NearestGoalFree(Here);
        if (Target.IsSet() == false)
        { return; }

        const auto Step = float64(InSelf.Get_Spec().Flight.CruiseSpeed) * 0.5 * float64(InDeltaSeconds);
        const auto Delta = Target.GetValue() - Here;
        const auto There = Delta.Size() <= Step ? Target.GetValue() : Here + Delta.GetSafeNormal() * Step;
        auto Root = InSelf.As_Transform();
        utils_transform::Request_SetLocation(Root, FCk_Request_Transform_SetLocation(There));
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Telemetry
    //----------------------------------------------------------------------------------------------------------------------

    private void TickTelemetry(FCk_Handle_Bat& InSelf, float32 InDeltaSeconds)
    {
        const auto Root = InSelf.Get_RootTransform();
        const auto Here = Root.GetLocation();
        const auto Rotation = Root.GetRotation().Rotator();
        auto& Telemetry = InSelf.Get_Fragment(FMars_Fragment_Bat).Telemetry;
        if (Telemetry.HasSample == false || InDeltaSeconds <= 0.0f)
        {
            Telemetry.LastLocation = Here;
            Telemetry.LastYaw = Rotation.Yaw;
            Telemetry.HasSample = true;
            Telemetry.Pitch = float32(Rotation.Pitch);
            return;
        }

        Telemetry.Velocity = (Here - Telemetry.LastLocation) / InDeltaSeconds;
        Telemetry.Speed = float32(Telemetry.Velocity.Size());
        Telemetry.SignedTurnRate = float32(Math::FindDeltaAngleDegrees(Telemetry.LastYaw, Rotation.Yaw) / InDeltaSeconds);
        Telemetry.Pitch = float32(Rotation.Pitch);
        Telemetry.LastLocation = Here;
        Telemetry.LastYaw = Rotation.Yaw;
    }
}
