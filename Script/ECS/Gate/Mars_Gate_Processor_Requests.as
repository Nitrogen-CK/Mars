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

        const auto HasRequest = InRequests.SetOpenRequest.IsSet();
        auto TargetOpen = false;
        if (HasRequest)
        { TargetOpen = InRequests.SetOpenRequest.GetValue().Open; }

        // Swap-and-pop - InRequests is dead past this line. Removing before broadcasting lets re-entrant requests survive.
        Self.Request_TryRemove(FMars_Fragment_Gate_Requests);

        if (HasRequest == false || InState.IsOpen == TargetOpen)
        { return; }

        InState.IsOpen = TargetOpen;

        auto Mover = InState.MovingNode.As_Mover(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(Mover))
        { Mover.Request_MoveTo(TargetOpen); }

        if (Self.Has_Fragment(FMars_Fragment_Gate_Signals))
        { Self.Get_Fragment(FMars_Fragment_Gate_Signals).OnOpenChanged.Broadcast(Self, TargetOpen); }
    }
}
