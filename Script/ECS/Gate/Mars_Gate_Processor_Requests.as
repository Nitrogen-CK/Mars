// The latest SetPosition wins; a RetryClose in the same drain is then moot (the SetPosition already decided). A close
// while the gate is open and its threshold occupied is deferred: the gate stays open until a RetryClose finds the
// threshold clear.
class UMars_Processor_Gate_HandleRequests : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Fragment_Gate_Requests;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Gate);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle,
                       FMars_Fragment_Gate_Requests& InRequests,
                       FMars_Fragment_Gate& InState)
    {
        auto Self = InHandle.As_Gate();

        const auto HasSetPosition = InRequests.SetPositionRequests.Num() > 0;
        auto TargetPosition = EMars_Gate_Position::Closed;
        if (HasSetPosition)
        { TargetPosition = InRequests.SetPositionRequests.Last().Position; }

        const auto HasRetryClose = InRequests.RetryCloseRequests.Num() > 0;

        // InRequests is invalid past this line; removing before broadcasting lets re-entrant requests survive.
        Self.Request_TryRemove(FMars_Fragment_Gate_Requests);

        if (HasSetPosition)
        {
            DoHandle_SetPosition(Self, InState, TargetPosition);
            return;
        }

        if (HasRetryClose && InState.State == EMars_Gate_State::CloseDeferred)
        { DoHandle_SetPosition(Self, InState, EMars_Gate_Position::Closed); }
    }

    private void DoHandle_SetPosition(FCk_Handle_Gate& InGate, FMars_Fragment_Gate& InState, EMars_Gate_Position InPosition)
    {
        const auto WasOpen = InState.State != EMars_Gate_State::Closed;
        const auto Open = InPosition == EMars_Gate_Position::Open;

        if (Open == false && WasOpen && InGate.Get_IsThresholdOccupied())
        {
            InState.State = EMars_Gate_State::CloseDeferred;
            return;
        }

        InState.State = Open ? EMars_Gate_State::Open : EMars_Gate_State::Closed;

        if (WasOpen == Open)
        { return; }

        auto Mover = InState.MovingNode.As_Mover();
        Mover.Request_MoveTo(FMars_Request_Mover_MoveTo(Open ? EMars_Mover_Pose::End : EMars_Mover_Pose::Start));

        if (InGate.Has_Fragment(FMars_Fragment_Gate_Signals))
        { InGate.Get_Fragment(FMars_Fragment_Gate_Signals).OnOpenChanged.Broadcast(InGate, InPosition); }
    }
}
