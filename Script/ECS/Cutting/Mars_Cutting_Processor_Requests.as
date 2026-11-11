// Drains PredictHand then ClearPrediction on every machine: they are this machine's presentation. A PredictHand (the last
// of the drain) holds the lateral node at its value; a ClearPrediction ends the prediction and returns the node to the
// ledger's hand. Then, with authority only, Reset -> Nudge -> Chop: a machine without authority drops them (the ledger
// replicates from the authority). Reset returns the hand to the board centre; nudges slide the hand by the summed
// centimetres, clamped to the board; a chop starts the chop clock unless one is already running (one press = one chop),
// first placing the hand at its aim when it carries one, counts ChopSerial and broadcasts OnChopStarted. The hand moves
// the lateral node unless a prediction stands. UMars_Processor_Cutting_Tick runs the clock and lands it. A changed ledger
// is marked for replication.
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

        TArray<FMars_Request_Cutting_PredictHand> PredictHandRequests = InRequests.PredictHandRequests;
        const auto HasClearPrediction = InRequests.ClearPredictionRequests.Num() > 0;
        const auto HasReset = InRequests.ResetRequests.Num() > 0;
        TArray<FMars_Request_Cutting_Nudge> NudgeRequests = InRequests.NudgeRequests;
        TArray<FMars_Request_Cutting_Chop> ChopRequests = InRequests.ChopRequests;

        // InRequests is invalid past this line; removing before broadcasting lets re-entrant requests survive.
        Self.Request_TryRemove(FMars_Fragment_Cutting_Requests);

        const auto Spec = Self.Get_Spec();
        const auto StartHand = InState.HandLateral;
        auto& Local = InHandle.Get_Fragment(FMars_Fragment_Cutting_Local);

        if (PredictHandRequests.Num() > 0)
        {
            const auto Predicted = PredictHandRequests.Last().LateralCm;
            Local.PredictedHand = TOptional<float32>(Predicted);
            utils_cutting::Apply_HandToNode(Spec.Nodes.LateralNode, Predicted);
        }

        if (HasClearPrediction && Local.PredictedHand.IsSet())
        {
            Local.PredictedHand = TOptional<float32>();
            utils_cutting::Apply_HandToNode(Spec.Nodes.LateralNode, InState.HandLateral);
        }

        if (utils_net::Get_HasAuthority(InHandle) == false)
        { return; }

        if (HasReset)
        { InState.HandLateral = 0.0f; }

        auto LateralCm = 0.0f;
        for (const auto& Request : NudgeRequests)
        { LateralCm += Request.LateralCm; }

        if (NudgeRequests.Num() > 0)
        { InState.HandLateral = Math::Clamp(InState.HandLateral + LateralCm, -Spec.BoardHalfWidth, Spec.BoardHalfWidth); }

        // Only the first chop of the drain can start a chop; the rest are presses during it. Its aim, if any, places the hand.
        const auto StartsChop = ChopRequests.Num() > 0 && Local.ChopPhase == EMars_Cutting_ChopPhase::Idle;
        if (StartsChop && ChopRequests[0].LateralCm.IsSet())
        { InState.HandLateral = Math::Clamp(ChopRequests[0].LateralCm.GetValue(), -Spec.BoardHalfWidth, Spec.BoardHalfWidth); }

        if (StartsChop)
        {
            Local.ChopPhase = EMars_Cutting_ChopPhase::Striking;
            Local.ChopSecondsLeft = Spec.ChopSeconds;
            InState.ChopSerial += 1;
        }

        const auto HandMoved = InState.HandLateral != StartHand;
        if (HandMoved && Local.PredictedHand.IsSet() == false)
        { utils_cutting::Apply_HandToNode(Spec.Nodes.LateralNode, InState.HandLateral); }

        if (HandMoved || StartsChop)
        { InHandle.Request_MarkReplicationDirty(FMars_Fragment_Cutting); }

        if (StartsChop == false)
        { return; }

        // InState and Local are not read past this line: a listener may add fragments to the station.
        if (Self.Has_Fragment(FMars_Tag_Cutting_Chopping) == false)
        { Self.Add_Fragment(FMars_Tag_Cutting_Chopping()); }

        if (Self.Has_Fragment(FMars_Fragment_Cutting_Signals))
        { Self.Get_Fragment(FMars_Fragment_Cutting_Signals).OnChopStarted.Broadcast(Self); }
    }
}
