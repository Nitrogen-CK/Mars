// Drains Reset -> Nudge -> Chop. Reset returns the pile, the band and the hand to a fresh session; nudges slide the hand
// (and the lateral node the cleaver hangs from) by the summed degrees, clamped to the board; a chop starts the cleaver's
// strike unless one is already in flight (one press = one chop). The strike resolves at contact in
// UMars_Processor_Dicing_Setup's OnArrived handler.
class UMars_Processor_Dicing_HandleRequests : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Fragment_Dicing_Requests;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Dicing);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle,
                       FMars_Fragment_Dicing_Requests& InRequests,
                       FMars_Fragment_Dicing& InState)
    {
        auto Self = InHandle.As_Dicing();

        const auto HasReset = InRequests.ResetRequests.Num() > 0;
        TArray<FMars_Request_Dicing_Nudge> NudgeRequests = InRequests.NudgeRequests;
        const auto ChopCount = InRequests.ChopRequests.Num();

        // Swap-and-pop - InRequests is dead past this line. Removing before broadcasting lets re-entrant requests survive.
        Self.Request_TryRemove(FMars_Fragment_Dicing_Requests);

        const auto Spec = Self.Get_Spec();

        const auto StartState = InState.MaterialState;
        const auto StartBand = InState.BandCenter;
        const auto StartHand = InState.HandLateral;

        if (HasReset)
        {
            InState.MaterialState = EMars_Dicing_State::WholeLeaves;
            InState.ChopsInState = 0;
            InState.UsefulChops = 0;
            InState.BandIndex = 0;
            InState.BandCenter = utils_dicing::Get_BandCenterAt(Spec, 0);
            InState.HandLateral = 0.0f;
        }

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
        { Apply_HandToNode(InState); }

        // Only the first chop of the drain can start a strike; the rest are presses during it.
        auto StartChop = false;
        if (ChopCount > 0)
        {
            if (InState.IsChopping)
            { ck::Trace(f"[Dicing] [{Self.ToString()}] chop ignored: the cleaver is still moving"); }
            else
            {
                InState.IsChopping = true;
                StartChop = true;
            }
        }

        const auto NewState = InState.MaterialState;
        const auto NewBand = InState.BandCenter;
        const auto NewHand = InState.HandLateral;

        if (StartChop)
        {
            auto Mover = InState.ChopMover;
            if (ck::IsValid(Mover))
            { Mover.Request_MoveTo(true); }
        }

        if (Self.Has_Fragment(FMars_Fragment_Dicing_Signals) == false)
        { return; }

        if (NewState != StartState)
        { Self.Get_Fragment(FMars_Fragment_Dicing_Signals).OnStateChanged.Broadcast(Self, NewState); }

        if (NewBand != StartBand && Self.Has_Fragment(FMars_Fragment_Dicing_Signals))
        { Self.Get_Fragment(FMars_Fragment_Dicing_Signals).OnBandMoved.Broadcast(Self, NewBand); }

        if (HandMoved && Self.Has_Fragment(FMars_Fragment_Dicing_Signals))
        { Self.Get_Fragment(FMars_Fragment_Dicing_Signals).OnHandMoved.Broadcast(Self, NewHand); }
    }

    // The lateral node's offset Y is the hand; X and Z stay where the entity script put them.
    private void Apply_HandToNode(const FMars_Fragment_Dicing& InState)
    {
        auto Node = InState.LateralNode;
        if (ck::Is_NOT_Valid(Node))
        { return; }

        auto Location = utils_scene_node::Get_Offset_Location(Node);
        Location.Y = InState.HandLateral;
        utils_scene_node::Request_UpdateOffset_Location(Node, Location, ECk_RelativeAbsolute::Absolute);
    }
}
