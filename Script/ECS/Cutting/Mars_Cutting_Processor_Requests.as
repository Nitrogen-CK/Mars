// Drains Reset -> Nudge -> Chop. Reset returns the hand to the board centre; nudges slide the hand (and the lateral node the
// cleaver hangs from) by the summed centimetres, clamped to the board; a chop starts the chop clock unless one is already
// running (one press = one chop) and broadcasts OnChopStarted. UMars_Processor_Cutting_Tick runs the clock and lands it.
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

        auto LateralCm = 0.0f;
        for (const auto& Request : NudgeRequests)
        { LateralCm += Request.LateralCm; }

        if (NudgeRequests.Num() > 0)
        { InState.HandLateral = Math::Clamp(InState.HandLateral + LateralCm, -Spec.BoardHalfWidth, Spec.BoardHalfWidth); }

        if (InState.HandLateral != StartHand)
        { Apply_HandToNode(Spec.Nodes.LateralNode, InState.HandLateral); }

        // Only the first chop of the drain can start a chop; the rest are presses during it.
        if (ChopCount == 0 || InState.ChopPhase != EMars_Cutting_ChopPhase::Idle)
        { return; }

        InState.ChopPhase = EMars_Cutting_ChopPhase::Striking;
        InState.ChopSecondsLeft = Spec.ChopSeconds;
        if (Self.Has_Fragment(FMars_Tag_Cutting_Chopping) == false)
        { Self.Add_Fragment(FMars_Tag_Cutting_Chopping()); }

        if (Self.Has_Fragment(FMars_Fragment_Cutting_Signals))
        { Self.Get_Fragment(FMars_Fragment_Cutting_Signals).OnChopStarted.Broadcast(Self); }
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
