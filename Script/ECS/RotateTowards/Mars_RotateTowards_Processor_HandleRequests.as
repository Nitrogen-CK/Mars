class UMars_Processor_RotateTowards_HandleRequests : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Fragment_RotateTowards_Requests;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_RotateTowards);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_Fragment_RotateTowards_Requests& InRequests)
    {
        auto Self = InHandle.As_RotateTowards();

        auto Requests = InRequests;

        // Swap-and-pop - InRequests is dead past this line. Removing before broadcasting lets re-entrant requests survive.
        Self.Request_TryRemove(FMars_Fragment_RotateTowards_Requests);

        if (Requests.UpdateTarget.IsSet())
        { HandleUpdateTarget(Self, Requests.UpdateTarget.GetValue().NewTarget); }

        if (Requests.ClearTarget)
        { HandleClearTarget(Self); }

        // Re-fetched: a target-signal listener may have grown the state storage.
        auto& State = Self.Get_Fragment(FMars_Fragment_RotateTowards);

        if (Requests.SetRestReferencePoint.IsSet())
        { State.RangeClampSettings.RestReferencePoint = Requests.SetRestReferencePoint.GetValue().RestReferencePoint; }

        if (Requests.SetYawRange.IsSet())
        { State.RangeClampSettings.YawRange = Requests.SetYawRange.GetValue().YawRange; }

        if (Requests.SetPitchRange.IsSet())
        { State.RangeClampSettings.PitchRange = Requests.SetPitchRange.GetValue().PitchRange; }

        if (Requests.SetRollRange.IsSet())
        { State.RangeClampSettings.RollRange = Requests.SetRollRange.GetValue().RollRange; }
    }

    private void HandleUpdateTarget(FCk_Handle_RotateTowards& InRotateTowards, FCk_Handle_Transform InNewTarget)
    {
        auto& State = InRotateTowards.Get_Fragment(FMars_Fragment_RotateTowards);

        if (InNewTarget == State.GoalTargetPoint)
        { return; }

        const auto PreviousTarget = State.GoalTargetPoint;
        State.GoalTargetPoint = InNewTarget;
        State.HasReachedTarget = false;
        State.PreviousTarget = PreviousTarget;

        if (InRotateTowards.Has_Fragment(FMars_Fragment_RotateTowards_Signals))
        { InRotateTowards.Get_Fragment(FMars_Fragment_RotateTowards_Signals).OnTargetChanged.Broadcast(InRotateTowards, InNewTarget, PreviousTarget); }
    }

    private void HandleClearTarget(FCk_Handle_RotateTowards& InRotateTowards)
    {
        auto& State = InRotateTowards.Get_Fragment(FMars_Fragment_RotateTowards);

        const auto PreviousTarget = State.GoalTargetPoint;

        if (ck::Is_NOT_Valid(PreviousTarget))
        { return; }

        State.GoalTargetPoint = FCk_Handle_Transform();
        State.HasReachedTarget = false;
        State.PreviousTarget = PreviousTarget;

        if (InRotateTowards.Has_Fragment(FMars_Fragment_RotateTowards_Signals))
        { InRotateTowards.Get_Fragment(FMars_Fragment_RotateTowards_Signals).OnTargetCleared.Broadcast(InRotateTowards, PreviousTarget); }
    }
}
