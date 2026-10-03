// The part arbiter. Drains RecordHit -> Sever, each kind in arrival order.
//
// RecordHit: the condition ledger (data, not code paths): a Damages reaction moves Pristine -> Damaged; a Ruins reaction
// accumulates its scaled amount in RuinDamageTaken and moves Pristine -> Damaged, then Ruined once RuinDamageTaken reaches
// RuinThreshold x Health.Max; a None reaction leaves the condition. A change broadcasts OnConditionChanged. Then
// SpillToBody x Amount lands on the monster's body Health as its own ApplyDamage.
//
// Sever (only while Attached) applies the depletion policy:
//   None      nothing.
//   Break     zone disabled, State = Broken, OnBroken.
//   DetachLeg zone disabled and hurtboxes released (both queued before the detach, so the hurtbox nodes are gone before
//             the segments ragdoll), State = Severed, the cause stashed in PendingSever, a one-shot OnDetached bind,
//             then Request_Detach(parts TransferToLeg, leg TransferToWorld): the severed limb becomes one world-owned
//             entity tree rooted at the leg, which stays alive with a Detached status.
//
// OnLegDetached runs inside the leg's detach drain, while the leg is still body-owned and its rig still bound (the
// framework applies the leg's ownership and unbinds the rig right after): each released part gets a dynamic box Jolt
// body sized from SegmentHalfExtents and a pending outward + up impulse; ONE timer on the leg destroys the whole severed
// limb (the parts are the leg's lifetime children by then); OnSevered broadcasts with the released parts.
class UMars_Processor_BodyPart_HandleRequests : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Fragment_BodyPart_Requests;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_BodyPart);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle,
                       FMars_Fragment_BodyPart_Requests& InRequests,
                       FMars_Fragment_BodyPart& InState)
    {
        auto Self = InHandle.As_BodyPart();

        TArray<FMars_Request_BodyPart_RecordHit> RecordHitRequests = InRequests.RecordHitRequests;
        TArray<FMars_Request_BodyPart_Sever> SeverRequests = InRequests.SeverRequests;

        // Swap-and-pop - InRequests is dead past this line. Removing before broadcasting lets re-entrant requests survive.
        Self.Request_TryRemove(FMars_Fragment_BodyPart_Requests);

        for (const auto& Request : RecordHitRequests)
        { HandleRecordHit(Self, Request); }

        for (const auto& Request : SeverRequests)
        { HandleSever(Self, Request); }
    }

    //----------------------------------------------------------------------------------------------------------------------
    // RecordHit
    //----------------------------------------------------------------------------------------------------------------------

    private void HandleRecordHit(FCk_Handle_BodyPart& InPart, const FMars_Request_BodyPart_RecordHit& InRequest)
    {
        const auto Severance = InPart.Get_Spec().Severance;

        auto& State = InPart.Get_Fragment(FMars_Fragment_BodyPart);
        const auto Old = State.Condition;
        auto New = Old;

        if (InRequest.Reaction.Impact == EMars_HitZone_ConditionImpact::Damages)
        {
            if (New == EMars_BodyPart_Condition::Pristine)
            { New = EMars_BodyPart_Condition::Damaged; }
        }
        else if (InRequest.Reaction.Impact == EMars_HitZone_ConditionImpact::Ruins)
        {
            State.RuinDamageTaken += InRequest.Event.Amount;

            const auto Max = ck::IsValid(State.Health) ? State.Health.Get_Max() : 0.0f;
            if (State.RuinDamageTaken >= Severance.RuinThreshold * Max)
            { New = EMars_BodyPart_Condition::Ruined; }
            else if (New == EMars_BodyPart_Condition::Pristine)
            { New = EMars_BodyPart_Condition::Damaged; }
        }

        State.Condition = New;
        auto Monster = InPart.Get_Monster();

        if (New != Old)
        {
            ck::Trace(f"[BodyPart] [{InPart.ToString()}] condition {Old :n} -> {New :n}");

            if (InPart.Has_Fragment(FMars_Fragment_BodyPart_Signals))
            { InPart.Get_Fragment(FMars_Fragment_BodyPart_Signals).OnConditionChanged.Broadcast(InPart, Old, New); }
        }

        if (Severance.SpillToBody <= 0.0f || ck::Is_NOT_Valid(Monster))
        { return; }

        auto BodyHealth = Monster.Get_BodyHealth();
        if (ck::Is_NOT_Valid(BodyHealth))
        { return; }

        auto Spilled = InRequest.Event;
        Spilled.Amount = InRequest.Event.Amount * Severance.SpillToBody;
        BodyHealth.Request_ApplyDamage(FMars_Request_Health_ApplyDamage(Spilled));
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Sever
    //----------------------------------------------------------------------------------------------------------------------

    private void HandleSever(FCk_Handle_BodyPart& InPart, const FMars_Request_BodyPart_Sever& InRequest)
    {
        if (InPart.Get_State() != EMars_BodyPart_State::Attached)
        { return; }

        const auto Policy = InPart.Get_Spec().Severance.OnDepleted;
        if (Policy == EMars_BodyPart_DepletionPolicy::None)
        { return; }

        auto Zone = InPart.Get_Zone();
        if (ck::IsValid(Zone))
        { Zone.Request_SetEnabled(FMars_Request_HitZone_SetEnabled(false)); }

        if (Policy == EMars_BodyPart_DepletionPolicy::Break)
        {
            InPart.Get_Fragment(FMars_Fragment_BodyPart).State = EMars_BodyPart_State::Broken;
            ck::Trace(f"[BodyPart] [{InPart.ToString()}] broken");

            if (InPart.Has_Fragment(FMars_Fragment_BodyPart_Signals))
            { InPart.Get_Fragment(FMars_Fragment_BodyPart_Signals).OnBroken.Broadcast(InPart, InRequest.Cause); }
            return;
        }

        if (ck::IsValid(Zone))
        { Zone.Request_ReleaseHurtboxes(FMars_Request_HitZone_ReleaseHurtboxes()); }

        InPart.Get_Fragment(FMars_Fragment_BodyPart).State = EMars_BodyPart_State::Severed;

        auto Leg = InPart.Get_Leg();
        if (utils_procedural_leg::Get_IsAttached(Leg) == false)
        {
            // Detached by someone else already: no detach will fire, so the sever completes here with nothing released.
            ck::Trace(f"[BodyPart] [{InPart.ToString()}] severed a leg that was no longer attached");
            if (InPart.Has_Fragment(FMars_Fragment_BodyPart_Signals))
            { InPart.Get_Fragment(FMars_Fragment_BodyPart_Signals).OnSevered.Broadcast(InPart, InRequest.Cause, TArray<FCk_Handle_Transform>()); }
            return;
        }

        InPart.AddOrGet_Fragment(FMars_Fragment_BodyPart_PendingSever).Cause = InRequest.Cause;

        utils_procedural_leg::BindTo_OnDetached(Leg, FCk_Delegate_ProceduralLeg_OnDetached(this, n"OnLegDetached"),
            ECk_Signal_BindingPolicy::FireIfPayloadInFlightThisFrame, ECk_Signal_PostFireBehavior::Unbind);

        // Set on a named local: the binding rejects the setter chained on a temporary.
        auto Detach = FCk_Request_ProceduralLeg_Detach(ECk_ProceduralLeg_ReleasedPartsOwnership::TransferToLeg);
        Detach.Set_LegOwnership(ECk_ProceduralLeg_DetachedLegOwnership::TransferToWorld);
        utils_procedural_leg::Request_Detach(Leg, Detach);

        ck::Trace(f"[BodyPart] [{InPart.ToString()}] severing: detach requested");
    }

    UFUNCTION()
    private void OnLegDetached(FCk_Handle_ProceduralLeg InLeg, FCk_ProceduralLeg_ReleasedParts InReleasedParts)
    {
        auto LegEntity = FCk_Handle(InLeg);
        auto Part = LegEntity.As_BodyPart(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Part))
        { return; }

        const auto Debris = Part.Get_Spec().Severance.Debris;
        const TArray<FVector> HalfExtents = Part.Get_Spec().SegmentHalfExtents;
        const TArray<FCk_Handle_Transform> Released = InReleasedParts.Get_Parts();

        // Still bound here (the framework unbinds the rig after this broadcast): it names which released part is which
        // segment. Without it the released order (segments, then the foot) is used.
        auto ChainSegments = TArray<FCk_Handle_Transform>();
        auto MaybeRig = utils_procedural_rig::DoCast(LegEntity);
        if (MaybeRig.IsSet())
        { ChainSegments = utils_procedural_rig::Get_Chain(MaybeRig.GetValue()).Get_Segments(); }

        // Still the body here (the leg's own ownership transfer lands after this broadcast).
        auto BodyLocation = FVector::ZeroVector;
        auto Body = utils_entity_lifetime::Get_LifetimeOwner(LegEntity).As_Transform(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(Body))
        { BodyLocation = utils_transform::Get_EntityCurrentLocation(Body); }

        for (int32 Index = 0; Index < Released.Num(); ++Index)
        {
            auto ReleasedPart = Released[Index];
            const auto HalfExtent = HalfExtents[Math::Min(Get_ChainIndex(ChainSegments, ReleasedPart, Index), HalfExtents.Num() - 1)];

            auto Shape = FCk_Jolt_ShapeDimensions(ECk_Jolt_ShapeType::Box);
            Shape.Set_HalfExtents(HalfExtent);
            auto BodySpec = FCk_JoltBody_Spec(ECk_JoltBody_ShapeSource::ExplicitShape);
            BodySpec.Set_ShapeDimensions(Shape);
            BodySpec.Set_MotionType(ECk_MotionType::Dynamic);
            BodySpec.Set_MassSource(ECk_JoltBody_MassSource::Explicit);
            BodySpec.Set_MassKg(Debris.MassKg);
            BodySpec.Set_CollisionProfileName(Debris.CollisionProfile);

            auto PartEntity = FCk_Handle(ReleasedPart);
            auto DebrisBody = utils_jolt_body::Add(PartEntity, BodySpec);

            auto Outward = utils_transform::Get_EntityCurrentLocation(ReleasedPart) - BodyLocation;
            Outward.Z = 0.0;
            const auto Velocity = Outward.GetSafeNormal() * Debris.OutwardSpeed + FVector::UpVector * Debris.UpSpeed;

            auto& Pending = Part.AddOrGet_Fragment(FMars_Fragment_BodyPart_PendingDebris);
            Pending.Bodies.Add(DebrisBody);
            Pending.Impulses.Add(Velocity * Debris.MassKg);
        }

        // One timer for the whole severed limb: the leg owns its released parts once the detach completes.
        auto TimerSpec = FCk_Timer_Spec(FCk_Time(Debris.LifetimeSeconds));
        TimerSpec.Set_StartingState(ECk_Timer_State::Running)
                 .Set_Behavior(ECk_Timer_Behavior::StopOnDone);
        auto Timer = utils_timer::Add(LegEntity, TimerSpec);
        if (ck::IsValid(Timer))
        { utils_timer::BindTo_OnDone(Timer, FCk_Delegate_Timer(this, n"OnDebrisExpired")); }

        auto Cause = FMars_DamageEvent();
        if (Part.Has_Fragment(FMars_Fragment_BodyPart_PendingSever))
        {
            Cause = Part.Get_Fragment(FMars_Fragment_BodyPart_PendingSever).Cause;
            Part.Request_TryRemove(FMars_Fragment_BodyPart_PendingSever);
        }

        ck::Trace(f"[BodyPart] [{Part.ToString()}] severed: [{Released.Num()}] parts released as debris for [{Debris.LifetimeSeconds}]s");

        if (Part.Has_Fragment(FMars_Fragment_BodyPart_Signals))
        { Part.Get_Fragment(FMars_Fragment_BodyPart_Signals).OnSevered.Broadcast(Part, Cause, Released); }
    }

    UFUNCTION()
    private void OnDebrisExpired(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        // The timer's owner is the severed leg; destroying it takes its released parts (its lifetime children) along,
        // and the body's leg record drops the entry through its own cleanup.
        auto Leg = utils_entity_lifetime::Get_LifetimeOwner(FCk_Handle(InTimer));
        if (ck::IsValid(Leg))
        { utils_entity_lifetime::Request_DestroyEntity(Leg); }
    }

    // The segment index of InPart in the rig chain; InFallback when the chain does not name it (the foot, or no rig).
    private int32 Get_ChainIndex(const TArray<FCk_Handle_Transform>& InChainSegments, FCk_Handle_Transform InPart, int32 InFallback) const
    {
        if (InChainSegments.Num() == 0)
        { return InFallback; }

        for (int32 Index = 0; Index < InChainSegments.Num(); ++Index)
        {
            if (FCk_Handle(InChainSegments[Index]) == FCk_Handle(InPart))
            { return Index; }
        }

        // Not a segment: the foot, whose half extents are the last entry.
        return InChainSegments.Num();
    }
}
