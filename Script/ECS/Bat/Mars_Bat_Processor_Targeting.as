// Chooses the bat's target every SenseInterval among the entities tagged TAG_MarsCombatTarget in its world that are Hostile
// to it and within HomeRadius of its hang point: a held target is kept while it stays valid, Hostile, near home and within
// LoseRadius of the bat; otherwise the nearest within AcquireRadius wins (equal distances go to the lower handle string).
// A target it could not fly to is passed over while IgnoreLeft runs. A bat that is down holds none. Every change of
// target broadcasts OnTargetChanged (a target that went invalid is a change to none). With Sensing.SearchSeconds set, a
// hostile target lost only by distance (past LoseRadius, still within HomeRadius) leaves its last sensed location behind
// (LastKnown) until a target is held again or the control layer ends its search.
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
        {
            Sample_TargetMotion(State, Spec.Sensing.SenseInterval);
            State.LastKnown.Reset();
            return State.Target;
        }

        if (Get_IsSearchable(InSelf, State.Target))
        { State.LastKnown = utils_transform::Get_EntityCurrentLocation(State.Target.As_Transform()); }

        State.TargetLastLocation.Reset();
        State.TargetVelocity = FVector::ZeroVector;
        const auto Next = Find_Nearest(InSelf, Spec.Sensing.AcquireRadius);
        if (ck::IsValid(Next))
        { State.LastKnown.Reset(); }

        return Next;
    }

    // A held target that is no longer keepable but worth looking for: still a valid hostile within HomeRadius of home (it
    // only got too far from the bat), with SearchSeconds set. Dead, friendly, ignored or out of the home range: forgotten.
    private bool Get_IsSearchable(const FCk_Handle_Bat& InSelf, FCk_Handle InTarget) const
    {
        const auto Spec = InSelf.Get_Spec();
        if (Spec.Sensing.SearchSeconds.IsSet() == false || utils_bat::Get_IsTargetValid(InTarget) == false)
        { return false; }

        if (InTarget == InSelf.Get_Fragment(FMars_Fragment_Bat).Ignored ||
            utils_relationship::Get_AttitudeTowards(InSelf, InTarget) != ECk_RelationshipAttitude::Hostile)
        { return false; }

        const auto Location = utils_transform::Get_EntityCurrentLocation(InTarget.As_Transform());
        return (Location - InSelf.Get_HangPoint()).Size() <= Spec.Sensing.HomeRadius;
    }

    // The held target's velocity over the last sense interval, from its location now and at the previous sense.
    private void Sample_TargetMotion(FMars_Fragment_Bat& InOutState, float32 InInterval) const
    {
        const auto Now = utils_transform::Get_EntityCurrentLocation(InOutState.Target.As_Transform());
        if (InOutState.TargetLastLocation.IsSet() && InInterval > 0.0f)
        { InOutState.TargetVelocity = (Now - InOutState.TargetLastLocation.GetValue()) / float64(InInterval); }

        InOutState.TargetLastLocation = Now;
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
