// The only writer of the dial's state. The last set applies first, lock or no lock: the pointer is put on its detent
// (Stepped counts the detents the shorter way round, Placed none). Then the last lock request: a locked dial snaps onto
// its index and drops everything else. Unlocked, each step in arrival order (the pointer jumps to the detent), the
// summed turn (the pointer follows it and Index becomes the detent nearest), and a settle (the pointer snaps onto
// Index). At most one OnIndexChanged (the final index, only when it changed) and one OnAngleChanged (the final angle
// and the detents crossed, only when the pointer moved) per drain.
class UMars_Processor_Dial_HandleRequests : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Fragment_Dial_Requests;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Dial);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_Fragment_Dial_Requests& InRequests, FMars_Fragment_Dial& InState)
    {
        auto Self = InHandle.As_Dial();

        const auto HasSet = InRequests.SetIndexRequests.Num() > 0;
        const auto Set = HasSet ? InRequests.SetIndexRequests.Last() : FMars_Request_Dial_SetIndex();
        const auto HasLock = InRequests.LockRequests.Num() > 0;
        const auto Locked = HasLock ? InRequests.LockRequests.Last().Locked : InState.Locked;
        const auto StepRequests = InRequests.StepRequests;
        const auto HasSettle = InRequests.SettleRequests.Num() > 0;
        auto TurnDegrees = 0.0f;
        for (const auto& Turn : InRequests.TurnRequests)
        { TurnDegrees += Turn.Degrees; }

        // InRequests is invalid past this line; removing before broadcasting lets re-entrant requests survive.
        Self.Request_TryRemove(FMars_Fragment_Dial_Requests);

        const auto Positions = Self.Get_Positions();
        const auto DetentDegrees = 360.0f / float32(Positions);
        const auto IndexBefore = InState.Index;
        const auto AngleBefore = InState.Angle;
        auto Index = IndexBefore;
        auto Angle = AngleBefore;
        auto Crossed = 0;

        if (HasSet && Get_IsOnTheRing(Self, Set))
        {
            if (Set.Arrival == EMars_Dial_Arrival::Stepped)
            { Crossed += utils_dial::Get_DetentDistance(Index, Set.Index, Positions); }

            Index = Set.Index;
            Angle = utils_dial::Get_DetentAngle(Index, Positions);
        }

        InState.Locked = Locked;
        if (Locked)
        { Angle = utils_dial::Get_DetentAngle(Index, Positions); }
        else
        {
            for (const auto& Step : StepRequests)
            {
                Index = utils_dial::Get_Wrapped(Index, Step.Detents, Positions);
                Angle = utils_dial::Get_DetentAngle(Index, Positions);
                Crossed += Math::Abs(Step.Detents);
            }

            if (TurnDegrees != 0.0f)
            {
                // Counted unwrapped, so a turn through 0 crosses the line between the last detent and the first like
                // any other.
                const auto Turned = Angle + TurnDegrees;
                Crossed += Math::Abs(Math::RoundToInt(Turned / DetentDegrees) - Math::RoundToInt(Angle / DetentDegrees));
                Angle = utils_dial::Get_WrappedAngle(Turned);
                Index = utils_dial::Get_NearestDetent(Angle, Positions);
            }

            if (HasSettle)
            { Angle = utils_dial::Get_DetentAngle(Index, Positions); }
        }

        InState.Index = Index;
        InState.Angle = Angle;

        if (Self.Has_Fragment(FMars_Fragment_Dial_Signals) == false)
        { return; }

        if (Angle != AngleBefore)
        { Self.Get_Fragment(FMars_Fragment_Dial_Signals).OnAngleChanged.Broadcast(Self, Angle, Crossed); }

        if (Index != IndexBefore && Self.Has_Fragment(FMars_Fragment_Dial_Signals))
        { Self.Get_Fragment(FMars_Fragment_Dial_Signals).OnIndexChanged.Broadcast(Self, Index); }
    }

    // A set off the ring is its host's error: it ensures and is skipped.
    private bool Get_IsOnTheRing(const FCk_Handle_Dial& InDial, const FMars_Request_Dial_SetIndex& InSet) const
    {
        const auto Positions = InDial.Get_Positions();
        return ck::EnsureIfNot(InSet.Index >= 0 && InSet.Index < Positions,
            f"[Dial] [{InDial.ToString()}] was set to [{InSet.Index}], off its [{Positions}] positions; the set is skipped") == false;
    }
}
