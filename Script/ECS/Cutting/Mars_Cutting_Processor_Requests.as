// Drains Reset -> Nudge -> Chop. Reset returns the hand to the board centre; nudges slide the hand (and the lateral node the
// cleaver hangs from) by the summed degrees, clamped to the board; a chop starts the cleaver's strike unless one is already
// in flight (one press = one chop). The strike lands at contact in UMars_Processor_Cutting_Setup's OnArrived handler.
class UMars_Processor_Cutting_HandleRequests : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Fragment_Cutting_Requests;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Cutting);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle,
                       FMars_Fragment_Cutting_Requests& InRequests,
                       FMars_Fragment_Cutting& InState)
    {
        auto Self = InHandle.As_Cutting();

        const auto HasReset = InRequests.ResetRequests.Num() > 0;
        TArray<FMars_Request_Cutting_Nudge> NudgeRequests = InRequests.NudgeRequests;
        const auto ChopCount = InRequests.ChopRequests.Num();

        // InRequests is invalid past this line; removing before broadcasting lets re-entrant requests survive.
        Self.Request_TryRemove(FMars_Fragment_Cutting_Requests);

        const auto Spec = Self.Get_Spec();
        const auto StartHand = InState.HandLateral;

        if (HasReset)
        { InState.HandLateral = 0.0f; }

        auto Degrees = 0.0f;
        for (const auto& Request : NudgeRequests)
        { Degrees += Request.LateralDegrees; }

        if (NudgeRequests.Num() > 0)
        {
            InState.HandLateral = Math::Clamp(InState.HandLateral + Degrees * Spec.LateralPerDegree,
                -Spec.BoardHalfWidth, Spec.BoardHalfWidth);
        }

        const auto HandMoved = InState.HandLateral != StartHand;
        if (HandMoved)
        { Apply_HandToNode(Spec.Nodes.LateralNode, InState.HandLateral); }

        // Only the first chop of the drain can start a strike; the rest are presses during it.
        if (ChopCount > 0)
        { Try_StartChop(Self, InState, Spec.Nodes.ChopMover); }

        const auto NewHand = InState.HandLateral;

        if (Self.Has_Fragment(FMars_Fragment_Cutting_Signals) == false)
        { return; }

        if (HasReset)
        { Self.Get_Fragment(FMars_Fragment_Cutting_Signals).OnReset.Broadcast(Self); }

        if (HandMoved && Self.Has_Fragment(FMars_Fragment_Cutting_Signals))
        { Self.Get_Fragment(FMars_Fragment_Cutting_Signals).OnHandMoved.Broadcast(Self, NewHand); }
    }

    // The cleaver is armed only once its Mover is known to take the strike, so a missing Mover cannot leave chopping
    // locked.
    private void Try_StartChop(FCk_Handle_Cutting& InCutting, FMars_Fragment_Cutting& InState, FCk_Handle_Mover InChopMover)
    {
        if (InState.IsChopping)
        {
            ck::Trace(f"[Cutting] [{InCutting.ToString()}] chop ignored: the cleaver is still moving");
            return;
        }

        if (ck::EnsureIfNot(ck::IsValid(InChopMover), f"[Cutting] [{InCutting.ToString()}] has no chop Mover; the chop is dropped"))
        { return; }

        InState.IsChopping = true;
        auto ChopMover = InChopMover;
        ChopMover.Request_MoveTo(FMars_Request_Mover_MoveTo(EMars_Mover_Pose::End));
    }

    // The lateral node's offset Y is the hand; X and Z stay where the entity script put them.
    private void Apply_HandToNode(FCk_Handle_SceneNode InLateralNode, float32 InHandLateral)
    {
        auto LateralNode = InLateralNode;
        auto Location = utils_scene_node::Get_Offset_Location(LateralNode);
        Location.Y = InHandLateral;
        utils_scene_node::Request_UpdateOffset_Location(LateralNode, Location, ECk_RelativeAbsolute::Absolute);
    }
}
