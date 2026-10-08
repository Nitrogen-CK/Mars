// Drains Cancel, then Start (the last one wins). A cancel turns the swing in flight into its recovery from the current
// pose: the arc's Strike key becomes that pose and the clock jumps to the strike's end, so the hand eases home with no
// jump. A start records where the hand is as the pose to leave from (identity at rest), so a restart mid-swing is
// continuous too. A request that fails Validate() ensures and is dropped.
class UMars_Processor_HandSwing_HandleRequests : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Fragment_HandSwing_Requests;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_HandSwing);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle,
                       FMars_Fragment_HandSwing_Requests& InRequests,
                       FMars_Fragment_HandSwing& InState)
    {
        auto Self = InHandle.As_HandSwing();

        const auto Cancel = InRequests.CancelRequests.Num() > 0;
        auto Start = TOptional<FMars_Request_HandSwing_Start>();
        if (InRequests.StartRequests.Num() > 0)
        { Start = TOptional<FMars_Request_HandSwing_Start>(InRequests.StartRequests.Last()); }

        // InRequests is invalid past this line; removing before broadcasting lets re-entrant requests survive.
        Self.Request_TryRemove(FMars_Fragment_HandSwing_Requests);

        const auto Previous = InState.Phase;

        if (Cancel)
        { HandleCancel(InState); }

        if (Start.IsSet())
        { HandleStart(Self, InState, Start.GetValue()); }

        if (InState.Phase == Previous)
        { return; }

        if (Self.Has_Fragment(FMars_Fragment_HandSwing_Signals))
        { Self.Get_Fragment(FMars_Fragment_HandSwing_Signals).OnPhaseChanged.Broadcast(Self, Previous, InState.Phase); }
    }

    private void HandleCancel(FMars_Fragment_HandSwing& InState)
    {
        if (InState.Phase == EMars_HandSwing_Phase::None)
        { return; }

        InState.Arc.Strike.Location = InState.Pose.GetLocation();
        InState.Arc.Strike.Rotation = InState.Pose.Rotator();
        InState.Elapsed = InState.Timeline.StrikeEnd;
        InState.Phase = EMars_HandSwing_Phase::Recover;
    }

    private void HandleStart(FCk_Handle_HandSwing& InSwing, FMars_Fragment_HandSwing& InState, const FMars_Request_HandSwing_Start& InRequest)
    {
        const auto Validation = InRequest.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[HandSwing] [{InSwing.ToString()}] rejected a start: {Validation.Get_Error()}"))
        { return; }

        InState.StartPose = InState.Pose;
        InState.Arc = InRequest.Arc;
        InState.Timeline = utils_hand_swing::Make_Timeline(InRequest.Arc, InRequest.ImpactSeconds, InRequest.RecoverySeconds);
        InState.Elapsed = 0.0f;
        InState.Phase = utils_hand_swing::Get_PhaseAt(InState.Timeline, 0.0f);
    }
}
