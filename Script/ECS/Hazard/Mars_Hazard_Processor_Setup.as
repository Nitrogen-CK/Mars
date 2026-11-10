// Owns every hit, on the authority only: an entity entering the trigger of an armed hazard, and everything already inside
// when it arms. A client wires none of it: it binds the ledger's rep-notify, reconciles once and broadcasts
// OnArmedChanged when the replicated arming changes.
class UMars_Processor_Hazard_Setup : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Tag_Hazard_NeedsSetup;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Hazard);
        Query.Require(FMars_Tag_Hazard_NeedsSetup);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle)
    {
        auto Hazard = InHandle.As_Hazard();
        Hazard.Request_TryRemove(FMars_Tag_Hazard_NeedsSetup);

        if (utils_net::Get_HasAuthority(InHandle) == false)
        {
            InHandle.BindTo_OnRepNotify(FMars_Fragment_Hazard, FCk_DynamicFragment_OnRepNotify(this, n"OnLedgerReplicated"));
            Reconcile(Hazard);
            return;
        }

        Hazard.Request_TryRemove(FMars_Fragment_Hazard_Mirror);
        Hazard.BindTo_OnArmedChanged(FMars_Delegate_Hazard_OnArmedChanged(this, n"OnHazardArmedChanged"));

        // Several hazards may share a trigger; binding this processor twice to one event would double-fire.
        auto Trigger = Hazard.Get_Trigger();
        auto& Link = Trigger.Get_Fragment(FMars_Fragment_Hazard_TriggerLink);
        if (Link.IsBound == false)
        {
            Link.IsBound = true;
            Trigger.BindTo_OnEntityEntered(FMars_Delegate_Trigger_OnEntityEntered(this, n"OnTriggerEntityEntered"));
        }

        // An arm request handled before this setup broadcast to no one.
        if (Hazard.Get_IsArmed())
        { HitAllInside(Hazard); }
    }

    UFUNCTION()
    private void OnLedgerReplicated(FCk_Handle InHandle, FCk_DynamicFragment_RepNotifyInfo InInfo)
    {
        auto Hazard = InHandle.As_Hazard();
        Reconcile(Hazard);
    }

    // The diff against Last guards the reconcile and the notify alike: one replicated change broadcasts once.
    private void Reconcile(FCk_Handle_Hazard& InHazard)
    {
        auto& Mirror = InHazard.Get_Fragment(FMars_Fragment_Hazard_Mirror);
        const auto WasArming = Mirror.Last.Arming;
        Mirror.Last = InHazard.Get_Fragment(FMars_Fragment_Hazard);

        const auto Arming = Mirror.Last.Arming;
        if (Arming == WasArming)
        { return; }

        if (InHazard.Has_Fragment(FMars_Fragment_Hazard_Signals))
        { InHazard.Get_Fragment(FMars_Fragment_Hazard_Signals).OnArmedChanged.Broadcast(InHazard, Arming); }
    }

    UFUNCTION()
    private void OnHazardArmedChanged(FCk_Handle_Hazard InHazard, EMars_Hazard_Arming InArming)
    {
        if (InArming != EMars_Hazard_Arming::Armed)
        { return; }

        auto Hazard = InHazard;
        HitAllInside(Hazard);
    }

    // Bound only on triggers that carry a hazard link.
    UFUNCTION()
    private void OnTriggerEntityEntered(FCk_Handle_Trigger InTrigger, FCk_Handle InEntity)
    {
        // Copied: a hit broadcasts, and a listener may change the link.
        auto Hazards = InTrigger.Get_Fragment(FMars_Fragment_Hazard_TriggerLink).Hazards;
        for (auto LinkedHazard : Hazards)
        {
            // A hazard sharing the trigger may already be gone.
            auto Hazard = LinkedHazard;
            if (ck::IsValid(Hazard) && Hazard.Get_IsArmed())
            { Hit(Hazard, InEntity); }
        }
    }

    private void HitAllInside(FCk_Handle_Hazard& InHazard)
    {
        auto Trigger = InHazard.Get_Trigger();
        auto EntitiesInside = Trigger.Get_EntitiesInside();
        for (auto Entity : EntitiesInside)
        { Hit(InHazard, Entity); }
    }

    private void Hit(FCk_Handle_Hazard& InHazard, FCk_Handle InEntity)
    {
        const auto Spec = InHazard.Get_Spec();
        auto Impulse = Spec.PushImpulse;

        if (InHazard.Has_Fragment(FMars_Fragment_Hazard_Signals))
        { InHazard.Get_Fragment(FMars_Fragment_Hazard_Signals).OnHit.Broadcast(InHazard, InEntity); }

        // LaunchCharacter with overrides would zero the character's velocity for a zero impulse.
        if (Impulse.IsNearlyZero())
        { return; }

        // The entered entity is usually a probe node under the character's entity, hence the recursive lookup.
        auto Character = Cast<ACharacter>(utils_owning_actor::TryGet_EntityOwningActor_Recursive(InEntity));
        if (Character == nullptr)
        { return; }

        // Add guarantees the transform of a hazard that pushes relative to it.
        if (Spec.PushIsRelative)
        { Impulse = utils_transform::Get_EntityCurrentTransform(InHazard.As_Transform()).TransformVectorNoScale(Impulse); }

        // The push replaces the character's velocity rather than adding to it.
        const auto OverrideHorizontalVelocity = true;
        const auto OverrideVerticalVelocity = true;
        Character.LaunchCharacter(Impulse, OverrideHorizontalVelocity, OverrideVerticalVelocity);
    }
}
