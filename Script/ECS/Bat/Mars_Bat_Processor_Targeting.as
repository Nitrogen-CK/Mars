// Chooses the bat's target every SenseInterval among the entities tagged TAG_MarsCombatTarget in its world that are Hostile
// to it and within HomeRadius of its hang point: a held target is kept while it stays valid, Hostile, near home and within
// LoseRadius of the bat; otherwise the nearest within AcquireRadius wins (equal distances go to the lower handle string).
// A target it could not fly to is passed over while IgnoreLeft runs. A bat that is down holds none. Every change of
// target broadcasts OnTargetChanged (a target that went invalid is a change to none).
class UMars_Processor_Bat_Targeting : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _RunBefore.Add(n"/Script/Angelscript.Mars_Processor_Bat_HandleRequests");

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
        const auto Previous = Self.Get_Target();
        const auto Next = Choose(Self, float32(InDeltaT.Get_Seconds()));
        if (Next == Previous && (ck::IsValid(Next) || ck::Is_NOT_Valid(Previous)))
        { return; }

        // A held handle that went invalid compares equal to nothing useful: treat it as a change to none.
        Self.Get_Fragment(FMars_Fragment_Bat).Target = Next;
        utils_bat::Broadcast_TargetChanged(Self);
    }

    private FCk_Handle Choose(FCk_Handle_Bat& InSelf, float32 InDeltaSeconds)
    {
        auto& State = InSelf.Get_Fragment(FMars_Fragment_Bat);
        State.IgnoreLeft = Math::Max(State.IgnoreLeft - InDeltaSeconds, 0.0f);
        if (State.IgnoreLeft <= 0.0f)
        { State.Ignored = FCk_Handle(); }

        if (InSelf.Get_IsDead() || InSelf.Get_IsDown())
        { return FCk_Handle(); }

        // A target that died between senses is dropped at once.
        if (ck::IsValid(State.Target) && utils_bat::Get_IsTargetValid(State.Target) == false)
        { return FCk_Handle(); }

        const auto Spec = InSelf.Get_Spec();
        State.SenseClock += InDeltaSeconds;
        if (State.SenseClock < Spec.Sensing.SenseInterval)
        { return State.Target; }

        State.SenseClock = 0.0f;
        if (Get_IsKeepable(InSelf, State.Target, Spec.Sensing.LoseRadius))
        { return State.Target; }

        return Find_Nearest(InSelf, Spec.Sensing.AcquireRadius);
    }

    private bool Get_IsKeepable(const FCk_Handle_Bat& InSelf, FCk_Handle InTarget, float32 InRadius) const
    {
        if (utils_bat::Get_IsTargetValid(InTarget) == false)
        { return false; }

        if (InTarget == InSelf.Get_Fragment(FMars_Fragment_Bat).Ignored)
        { return false; }

        if (utils_relationship::Get_AttitudeTowards(InSelf, InTarget) != ECk_RelationshipAttitude::Hostile)
        { return false; }

        const auto Location = utils_transform::Get_EntityCurrentLocation(InTarget.As_Transform());
        if ((Location - InSelf.Get_HangPoint()).Size() > InSelf.Get_Spec().Sensing.HomeRadius)
        { return false; }

        return (Location - InSelf.Get_Location()).Size() <= InRadius;
    }

    private FCk_Handle Find_Nearest(const FCk_Handle_Bat& InSelf, float32 InRadius) const
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
