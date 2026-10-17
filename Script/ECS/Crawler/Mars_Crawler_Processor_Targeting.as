// Chooses an aggressive armed crawler's combat target every SenseInterval (a passive one never scans), among the
// entities tagged TAG_MarsCombatTarget in its
// world: a valid target (Get_IsCombatTargetValid) Hostile to the crawler, within AcquireRadius of it (horizontally), within
// HomeRadius of its home and within MaxHeightDifference of its height. The nearest wins; equal distances go to the lower
// handle string, so the choice is stable. A held target is kept, without the AcquireRadius check, until it stops being
// valid, Hostile or within HomeRadius of home. Only a changed choice is published, as Request_SetCombatTarget, and no
// scan runs while combat requests are pending (an explicit request is never overwritten by a scan of stale state).
class UMars_Processor_Crawler_Targeting : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _RunBefore.Add(n"/Script/Angelscript.Mars_Processor_Crawler_HandleRequests");

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Crawler);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_Fragment_Crawler_Targeting& InTargeting)
    {
        if (utils_entity_lifetime::Get_IsPendingDestroy(InHandle, ECk_EntityLifetime_DestructionPhase::BeginDestroy))
        { return; }

        auto Self = InHandle.As_Crawler();
        if (Self.Get_IsAggressive() == false)
        { return; }

        const auto Targeting = Self.Get_Spec().Combat.Targeting;

        InTargeting.SenseClock += float32(InDeltaT.Get_Seconds());
        if (InTargeting.SenseClock < Targeting.SenseInterval || Self.Get_HasPendingCombatRequests())
        { return; }

        InTargeting.SenseClock = 0.0f;

        const auto Held = Self.Get_CombatTarget();
        auto Choice = FCk_Handle();
        if (Get_IsKeepable(Self, Held))
        { Choice = Held; }
        else
        { Choice = Find_Nearest(Self); }

        InTargeting.Candidate = Choice;

        if (Choice != Held)
        { Self.Request_SetCombatTarget(FMars_Request_Crawler_SetCombatTarget(Choice)); }
    }

    private bool Get_IsKeepable(const FCk_Handle_Crawler& InSelf, FCk_Handle InTarget)
    {
        if (InSelf.Get_IsCombatTargetValid(InTarget) == false)
        { return false; }

        if (utils_relationship::Get_AttitudeTowards(InSelf, InTarget) != ECk_RelationshipAttitude::Hostile)
        { return false; }

        const auto TargetLocation = utils_transform::Get_EntityCurrentLocation(InTarget.As_Transform());
        return (TargetLocation - InSelf.Get_CombatHome()).Size2D() <= InSelf.Get_Spec().Combat.Targeting.HomeRadius;
    }

    private FCk_Handle Find_Nearest(const FCk_Handle_Crawler& InSelf)
    {
        const auto Combat = InSelf.Get_Spec().Combat;
        float32 MaxHeight = 0.0f;
        for (const auto& Entry : InSelf.Get_Spec().ResolvedAttacks.Entries)
        { MaxHeight = Math::Max(MaxHeight, Entry.Definition.Prepare.MaxHeightDifference); }
        const auto Root = utils_transform::Get_EntityCurrentLocation(InSelf.As_Transform());

        auto Best = FCk_Handle();
        auto BestDistance = 0.0;
        for (auto Candidate : utils_entity_tag::ForEach_Entity(InSelf, n"TAG_MarsCombatTarget"))
        {
            if (Get_IsKeepable(InSelf, Candidate) == false)
            { continue; }

            const auto Offset = utils_transform::Get_EntityCurrentLocation(Candidate.As_Transform()) - Root;
            const auto Distance = Offset.Size2D();
            if (Distance > Combat.Targeting.AcquireRadius || Math::Abs(Offset.Z) > MaxHeight)
            { continue; }

            const auto Closer = ck::Is_NOT_Valid(Best) || Distance < BestDistance ||
                (Distance == BestDistance && Candidate.ToString() < Best.ToString());
            if (Closer)
            {
                Best = Candidate;
                BestDistance = Distance;
            }
        }

        return Best;
    }
}
