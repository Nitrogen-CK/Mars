// The break and the detach both part processors run. They write the part's state and its pending sever, so they live on
// the processors and nowhere else.
//
// A detach disables the zone and releases its hurtboxes before it requests the detach, so the hurtbox nodes are gone before
// the segments ragdoll; the severed limb then becomes one world-owned entity tree rooted at the leg.
//
// OnLegDetached runs inside the leg's detach drain, while the leg is still body-owned and its rig still bound (the
// framework applies the leg's ownership and unbinds the rig right after): each released part gets a dynamic box Jolt
// body and a pending outward + up impulse, and ONE timer on the leg destroys the whole severed limb (the parts are the
// leg's lifetime children by then).
UCLASS(Abstract)
class UMars_Processor_BodyPart_Base : UCk_Processor_Script_Base_UE
{
    // Disables the zone, marks the part Broken and raises OnBroken.
    protected void DoBreak(FCk_Handle_BodyPart& InPart, const FMars_DamageEvent& InCause)
    {
        auto Zone = InPart.Get_Zone();
        Zone.Request_SetEnabled(FMars_Request_HitZone_SetEnabled(ECk_EnableDisable::Disable));

        InPart.Get_Fragment(FMars_Fragment_BodyPart).State = EMars_BodyPart_State::Broken;

        if (InPart.Has_Fragment(FMars_Fragment_BodyPart_Signals))
        { InPart.Get_Fragment(FMars_Fragment_BodyPart_Signals).OnBroken.Broadcast(InPart, InCause); }
    }

    // Disables the zone, releases its hurtboxes, marks the part Severed and asks the leg to detach to the world; OnSevered
    // fires from OnLegDetached with what the detach released.
    protected void DoDetach(FCk_Handle_BodyPart& InPart, const FMars_DamageEvent& InCause)
    {
        auto Zone = InPart.Get_Zone();
        Zone.Request_SetEnabled(FMars_Request_HitZone_SetEnabled(ECk_EnableDisable::Disable));
        Zone.Request_ReleaseHurtboxes(FMars_Request_HitZone_ReleaseHurtboxes());

        InPart.Get_Fragment(FMars_Fragment_BodyPart).State = EMars_BodyPart_State::Severed;

        // Only the sever detaches a leg, and a part severs once (it left Attached above), so a leg already detached is a
        // defect. No detach would fire: the sever completes here with nothing released.
        auto Leg = InPart.Get_Leg();
        if (ck::EnsureIfNot(utils_procedural_leg::Get_IsAttached(Leg), f"[BodyPart] [{InPart.ToString()}] severed a leg that was no longer attached: only the sever detaches a leg"))
        {
            if (InPart.Has_Fragment(FMars_Fragment_BodyPart_Signals))
            { InPart.Get_Fragment(FMars_Fragment_BodyPart_Signals).OnSevered.Broadcast(InPart, InCause, TArray<FCk_Handle_Transform>()); }

            return;
        }

        InPart.AddOrGet_Fragment(FMars_Fragment_BodyPart_PendingSever).Cause = InCause;

        utils_procedural_leg::BindTo_OnDetached(Leg, FCk_Delegate_ProceduralLeg_OnDetached(this, n"OnLegDetached"),
            ECk_Signal_BindingPolicy::FireIfPayloadInFlightThisFrame, ECk_Signal_PostFireBehavior::Unbind);

        // Set on a named local: the binding rejects the setter chained on a temporary.
        auto Detach = FCk_Request_ProceduralLeg_Detach(ECk_ProceduralLeg_ReleasedPartsOwnership::TransferToLeg);
        Detach.Set_LegOwnership(ECk_ProceduralLeg_DetachedLegOwnership::TransferToWorld);
        utils_procedural_leg::Request_Detach(Leg, Detach);
    }

    // Bound only by DoDetach, on a part's own leg, after it stashed the cause in PendingSever.
    UFUNCTION()
    private void OnLegDetached(FCk_Handle_ProceduralLeg InLeg, FCk_ProceduralLeg_ReleasedParts InReleasedParts)
    {
        auto Part = InLeg.As_BodyPart();

        const auto Debris = Part.Get_Spec().Severance.Debris;
        const TArray<FVector> HalfExtents = Part.Get_Spec().SegmentHalfExtents;
        const TArray<FCk_Handle_Transform> Released = InReleasedParts.Get_Parts();

        // Still bound here (the framework unbinds the rig after this broadcast): it names which released part is which
        // segment. Without it the released order (segments, then the foot) is used.
        auto ChainSegments = TArray<FCk_Handle_Transform>();
        const auto Rig = InLeg.As_ProceduralRig(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(Rig))
        { ChainSegments = utils_procedural_rig::Get_Chain(Rig).Get_Segments(); }

        // Still the body here (the leg's own ownership transfer lands after this broadcast).
        const auto Body = utils_entity_lifetime::Get_LifetimeOwner(InLeg).As_Transform();
        const auto BodyLocation = utils_transform::Get_EntityCurrentLocation(Body);

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

            auto DebrisBody = utils_jolt_body::Add(ReleasedPart, BodySpec);

            auto Outward = utils_transform::Get_EntityCurrentLocation(ReleasedPart) - BodyLocation;
            Outward.Z = 0.0;
            const auto Velocity = Outward.GetSafeNormal() * Debris.OutwardSpeed + FVector::UpVector * Debris.UpSpeed;

            auto& Pending = Part.AddOrGet_Fragment(FMars_Fragment_BodyPart_PendingDebris);
            Pending.Impulses.Add(FMars_BodyPart_PendingImpulse(DebrisBody, Velocity * Debris.MassKg));
        }

        // One timer for the whole severed limb: the leg owns its released parts once the detach completes, and the
        // body's leg record drops the entry through its own cleanup.
        utils_monster::Add_DespawnTimer(InLeg, Debris.LifetimeSeconds, FCk_Delegate_Timer(this, n"OnDebrisExpired"));

        auto Cause = FMars_DamageEvent();
        if (ck::EnsureIfNot(Part.Has_Fragment(FMars_Fragment_BodyPart_PendingSever), f"[BodyPart] [{Part.ToString()}] detached with no pending sever cause") == false)
        {
            Cause = Part.Get_Fragment(FMars_Fragment_BodyPart_PendingSever).Cause;
            Part.Request_TryRemove(FMars_Fragment_BodyPart_PendingSever);
        }

        if (Part.Has_Fragment(FMars_Fragment_BodyPart_Signals))
        { Part.Get_Fragment(FMars_Fragment_BodyPart_Signals).OnSevered.Broadcast(Part, Cause, Released); }
    }

    UFUNCTION()
    private void OnDebrisExpired(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        utils_monster::Request_DestroyTimerOwner(InTimer);
    }

    // InPart's segment index in the rig chain; InFallback with no chain (no rig); the chain's length (the foot's entry,
    // the last half extents) when the chain does not name it.
    private int32 Get_ChainIndex(const TArray<FCk_Handle_Transform>& InChainSegments, FCk_Handle_Transform InPart, int32 InFallback) const
    {
        if (InChainSegments.Num() == 0)
        { return InFallback; }

        for (int32 Index = 0; Index < InChainSegments.Num(); ++Index)
        {
            if (InChainSegments[Index] == InPart)
            { return Index; }
        }

        return InChainSegments.Num();
    }
}
