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

        utils_bat::Try_RememberLastKnown(InSelf, State.Target);
        State.TargetLastLocation.Reset();
        State.TargetVelocity = FVector::ZeroVector;
        const auto Next = Find_Nearest(InSelf, Spec.Sensing.AcquireRadius);
        if (ck::IsValid(Next))
        { State.LastKnown.Reset(); }

        return Next;
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

// The kernel's shared write of the last-known place (the sense that loses a target, and the route failure that drops one).
namespace utils_bat
{
    // Remembers where a target the bat is losing was last sensed, when it is worth looking for: SearchSeconds set, the
    // target still a valid hostile within HomeRadius of home and not the one being ignored. The place must be somewhere
    // the bat can fly to: its location now when the flight volume has it free, else where the previous sense saw it (a
    // target that dropped into a hole or stepped out of the flyable space is searched for at the rim), else nothing.
    void Try_RememberLastKnown(FCk_Handle_Bat& InSelf, FCk_Handle InTarget)
    {
        const auto Spec = InSelf.Get_Spec();
        if (Spec.Sensing.SearchSeconds.IsSet() == false || Get_IsTargetValid(InTarget) == false)
        { return; }

        auto& State = InSelf.Get_Fragment(FMars_Fragment_Bat);
        if (InTarget == State.Ignored || utils_relationship::Get_AttitudeTowards(InSelf, InTarget) != ECk_RelationshipAttitude::Hostile)
        { return; }

        const auto Now = utils_transform::Get_EntityCurrentLocation(InTarget.As_Transform());
        if ((Now - InSelf.Get_HangPoint()).Size() > Spec.Sensing.HomeRadius)
        { return; }

        const auto Lift = FVector(0.0, 0.0, Spec.Swoop.AimHeight + Spec.Swoop.Height);
        if (Get_IsFlyable(InSelf, Now + Lift))
        {
            State.LastKnown = Now;
            return;
        }

        if (State.TargetLastLocation.IsSet() && Get_IsFlyable(InSelf, State.TargetLastLocation.GetValue() + Lift))
        { State.LastKnown = State.TargetLastLocation.GetValue(); }
    }

    // InPoint is goal-free in the flight volume AND no static geometry lies between the bat and it: the volume answers free
    // for space it never rasterized (under the floor, past a wall, inside its power-of-two cube), so a target that dropped
    // through the floor would otherwise leave a place beneath it. The ray is the cheap proxy for "inside the flyable space"
    // the volume does not offer.
    bool Get_IsFlyable(const FCk_Handle_Bat& InSelf, FVector InPoint)
    {
        return InSelf.Get_IsGoalFree(InPoint) && Get_IsStaticBetween(InSelf, InSelf.Get_Location(), InPoint) == false;
    }
}
