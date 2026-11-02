// Chooses the Root Maw's target every SenseInterval, among the entities tagged TAG_MarsCombatTarget in its world that are
// Hostile to it and stand within HomeRadius of its home: a held target is kept while it stays valid, Hostile, near home
// and within LoseRadius of the Maw; otherwise the nearest within AcquireRadius wins (equal distances go to the lower
// handle string, so the choice is stable). A dead Maw holds none. The processor owns the targeting fragment.
class UMars_Processor_RootMaw_Targeting : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _RunBefore.Add(n"/Script/Angelscript.Mars_Processor_RootMaw_HandleRequests");

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_RootMaw);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_Fragment_RootMaw_Targeting& InTargeting)
    {
        if (utils_entity_lifetime::Get_IsPendingDestroy(InHandle, ECk_EntityLifetime_DestructionPhase::BeginDestroy))
        { return; }

        auto Self = InHandle.As_RootMaw();
        if (Self.Get_IsDead())
        {
            InTargeting.Target = FCk_Handle();
            return;
        }

        const auto Spec = Self.Get_Spec();
        InTargeting.SenseClock += float32(InDeltaT.Get_Seconds());
        if (InTargeting.SenseClock < Spec.Senses.SenseInterval)
        { return; }

        InTargeting.SenseClock = 0.0f;
        if (Get_IsKeepable(Self, InTargeting.Target, Spec.Senses.LoseRadius))
        { return; }

        InTargeting.Target = Find_Nearest(Self, Spec.Senses.AcquireRadius);
    }

    private bool Get_IsKeepable(const FCk_Handle_RootMaw& InSelf, FCk_Handle InTarget, float32 InRadius) const
    {
        if (utils_root_maw::Get_IsTargetValid(InTarget) == false)
        { return false; }

        if (utils_relationship::Get_AttitudeTowards(InSelf, InTarget) != ECk_RelationshipAttitude::Hostile)
        { return false; }

        const auto Location = utils_transform::Get_EntityCurrentLocation(InTarget.As_Transform());
        if ((Location - InSelf.Get_Home()).Size() > InSelf.Get_Spec().Locomotion.HomeRadius)
        { return false; }

        return (Location - InSelf.Get_Location()).Size() <= InRadius;
    }

    private FCk_Handle Find_Nearest(const FCk_Handle_RootMaw& InSelf, float32 InRadius) const
    {
        const auto Here = InSelf.Get_Location();

        auto Best = FCk_Handle();
        auto BestDistance = 0.0;
        for (auto Candidate : utils_entity_tag::ForEach_Entity(InSelf, n"TAG_MarsCombatTarget"))
        {
            if (Get_IsKeepable(InSelf, Candidate, InRadius) == false)
            { continue; }

            const auto Distance = (utils_transform::Get_EntityCurrentLocation(Candidate.As_Transform()) - Here).Size();
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
