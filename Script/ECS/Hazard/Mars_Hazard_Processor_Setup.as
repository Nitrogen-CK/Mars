// Owns every hit: an entity entering the trigger of an armed hazard, and everything already inside when it arms.
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
        Hazard.BindTo_OnArmedChanged(FMars_Delegate_Hazard_OnArmedChanged(this, n"OnHazardArmedChanged"));

        auto Trigger = Hazard.Get_Trigger();
        if (ck::IsValid(Trigger) && Trigger.Has_Fragment(FMars_Fragment_Hazard_TriggerLink))
        {
            // Several hazards may share a trigger; binding this processor twice to one event would double-fire.
            auto& Link = Trigger.Get_Fragment(FMars_Fragment_Hazard_TriggerLink);
            if (Link.IsBound == false)
            {
                Link.IsBound = true;
                Trigger.BindTo_OnEntityEntered(FMars_Delegate_Trigger_OnEntityEntered(this, n"OnTriggerEntityEntered"));
            }
        }

        // An arm request handled before this setup broadcast to no one.
        if (Hazard.Get_IsArmed())
        { HitAllInside(Hazard); }

        Hazard.Request_TryRemove(FMars_Tag_Hazard_NeedsSetup);
    }

    UFUNCTION()
    private void OnHazardArmedChanged(FCk_Handle_Hazard InHazard, bool InArmed)
    {
        if (InArmed == false)
        { return; }

        auto Hazard = InHazard;
        HitAllInside(Hazard);
    }

    UFUNCTION()
    private void OnTriggerEntityEntered(FCk_Handle_Trigger InTrigger, FCk_Handle InEntity)
    {
        if (InTrigger.Has_Fragment(FMars_Fragment_Hazard_TriggerLink) == false)
        { return; }

        // Copied: a hit broadcasts, and a listener may change the link.
        auto Hazards = InTrigger.Get_Fragment(FMars_Fragment_Hazard_TriggerLink).Hazards;
        for (auto LinkedHazard : Hazards)
        {
            auto Hazard = LinkedHazard;
            if (ck::IsValid(Hazard) && Hazard.Get_IsArmed())
            { Hit(Hazard, InEntity); }
        }
    }

    private void HitAllInside(FCk_Handle_Hazard& InHazard)
    {
        auto Trigger = InHazard.Get_Trigger();
        if (ck::Is_NOT_Valid(Trigger))
        { return; }

        auto EntitiesInside = Trigger.Get_EntitiesInside();
        for (auto Entity : EntitiesInside)
        { Hit(InHazard, Entity); }
    }

    private void Hit(FCk_Handle_Hazard& InHazard, FCk_Handle InEntity)
    {
        const auto& Params = InHazard.Get_Fragment(FMars_Fragment_Hazard_Params);
        auto Impulse = Params.PushImpulse;
        const auto PushIsRelative = Params.PushIsRelative;

        if (InHazard.Has_Fragment(FMars_Fragment_Hazard_Signals))
        { InHazard.Get_Fragment(FMars_Fragment_Hazard_Signals).OnHit.Broadcast(InHazard, InEntity); }

        // LaunchCharacter with overrides would zero the character's velocity for a zero impulse.
        if (Impulse.IsNearlyZero())
        { return; }

        // The entered entity is usually a probe node under the character's entity, hence the recursive lookup.
        auto Character = Cast<ACharacter>(utils_owning_actor::TryGet_EntityOwningActor_Recursive(InEntity));
        if (Character == nullptr)
        { return; }

        if (PushIsRelative)
        {
            auto HazardTransform = InHazard.As_Transform(ECk_SanityCheck::UnChecked);
            if (ck::IsValid(HazardTransform))
            { Impulse = utils_transform::Get_EntityCurrentTransform(HazardTransform).TransformVectorNoScale(Impulse); }
        }

        Character.LaunchCharacter(Impulse, true, true);
    }
}
