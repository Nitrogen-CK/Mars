// The only writer of the dial's state. The last lock request applies first; a locked dial drops everything else. Then each
// step in arrival order (the pointer jumps to the detent), the summed turn (the pointer follows it and Index becomes the
// detent nearest), and a settle (the pointer snaps onto Index). At most one OnIndexChanged (the final index, only when it
// changed) and one OnAngleChanged (the final angle and the detents crossed, only when the pointer moved) per drain.
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

        const auto HasLock = InRequests.LockRequests.Num() > 0;
        const auto Locked = HasLock ? InRequests.LockRequests.Last().Locked : InState.Locked;
        const auto StepRequests = InRequests.StepRequests;
        const auto HasSettle = InRequests.SettleRequests.Num() > 0;
        auto TurnDegrees = 0.0f;
        for (const auto& Turn : InRequests.TurnRequests)
        { TurnDegrees += Turn.Degrees; }

        // InRequests is invalid past this line; removing before broadcasting lets re-entrant requests survive.
        Self.Request_TryRemove(FMars_Fragment_Dial_Requests);

        InState.Locked = Locked;
        if (Locked)
        {
            const auto Angle = utils_dial::Get_DetentAngle(InState.Index, Self.Get_Positions());
            const auto Moved = InState.Angle != Angle;
            InState.Angle = Angle;
            if (Moved && Self.Has_Fragment(FMars_Fragment_Dial_Signals))
            { Self.Get_Fragment(FMars_Fragment_Dial_Signals).OnAngleChanged.Broadcast(Self, Angle, 0); }
            return;
        }

        const auto Positions = Self.Get_Positions();
        const auto DetentDegrees = 360.0f / float32(Positions);
        const auto IndexBefore = InState.Index;
        const auto AngleBefore = InState.Angle;
        auto Index = IndexBefore;
        auto Angle = AngleBefore;
        auto Crossed = 0;

        for (const auto& Step : StepRequests)
        {
            Index = utils_dial::Get_Wrapped(Index, Step.Detents, Positions);
            Angle = utils_dial::Get_DetentAngle(Index, Positions);
            Crossed += Math::Abs(Step.Detents);
        }

        if (TurnDegrees != 0.0f)
        {
            // Counted unwrapped, so a turn through 0 crosses the line between the last detent and the first like any other.
            const auto Turned = Angle + TurnDegrees;
            Crossed += Math::Abs(Math::RoundToInt(Turned / DetentDegrees) - Math::RoundToInt(Angle / DetentDegrees));
            Angle = utils_dial::Get_WrappedAngle(Turned);
            Index = utils_dial::Get_NearestDetent(Angle, Positions);
        }

        if (HasSettle)
        { Angle = utils_dial::Get_DetentAngle(Index, Positions); }

        InState.Index = Index;
        InState.Angle = Angle;

        if (Self.Has_Fragment(FMars_Fragment_Dial_Signals) == false)
        { return; }

        if (Angle != AngleBefore)
        { Self.Get_Fragment(FMars_Fragment_Dial_Signals).OnAngleChanged.Broadcast(Self, Angle, Crossed); }

        if (Index != IndexBefore && Self.Has_Fragment(FMars_Fragment_Dial_Signals))
        { Self.Get_Fragment(FMars_Fragment_Dial_Signals).OnIndexChanged.Broadcast(Self, Index); }
    }
}
