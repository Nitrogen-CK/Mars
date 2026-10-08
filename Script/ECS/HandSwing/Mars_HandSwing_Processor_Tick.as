// Every frame of a swing in flight: advances the clock, evaluates the pose, writes it to the node (when the spec gave
// one) and announces the phase it has reached. The pose is identity again by the time the swing ends, so the node is
// left at rest.
class UMars_Processor_HandSwing_Tick : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_HandSwing);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_Fragment_HandSwing& InState)
    {
        if (InState.Phase == EMars_HandSwing_Phase::None)
        { return; }

        InState.Elapsed += float32(InDeltaT.Get_Seconds());
        InState.Pose = utils_hand_swing::Evaluate(InState.Arc, InState.Timeline, InState.StartPose, InState.Elapsed);

        auto Node = InHandle.Get_Fragment(FMars_Fragment_HandSwing_Params).Node;
        if (ck::IsValid(Node))
        { utils_scene_node::Request_UpdateOffset(Node, FCk_Request_SceneNode_UpdateRelativeTransform(InState.Pose)); }

        const auto Previous = InState.Phase;
        InState.Phase = utils_hand_swing::Get_PhaseAt(InState.Timeline, InState.Elapsed);
        if (InState.Phase == Previous)
        { return; }

        auto Self = InHandle.As_HandSwing();
        if (Self.Has_Fragment(FMars_Fragment_HandSwing_Signals))
        { Self.Get_Fragment(FMars_Fragment_HandSwing_Signals).OnPhaseChanged.Broadcast(Self, Previous, InState.Phase); }
    }
}
