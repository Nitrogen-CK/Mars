// Drains Disengage -> Engage -> SwitchSeasoning -> Collect -> Release -> Press. Disengage lets the pestle go and stops the
// clocks; Engage starts them with the timing window at the start of a pass; SwitchSeasoning swaps a batch that has taken
// no hit; Collect empties a Done batch into the tally and loads a fresh one; Release and Press move the pestle's press,
// and a press in the Crush phase with no strike in flight starts a strike, judged against the timing window there and
// then. UMars_Processor_Mortar_Tick runs the clocks, lands the strike and grinds.
class UMars_Processor_Mortar_HandleRequests : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Fragment_Mortar_Requests;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Mortar);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle,
                       FMars_Fragment_Mortar_Requests& InRequests,
                       FMars_Fragment_Mortar& InState)
    {
        auto Self = InHandle.As_Mortar();

        const auto HasDisengage = InRequests.DisengageRequests.Num() > 0;
        const auto HasEngage = InRequests.EngageRequests.Num() > 0;
        // Two switches in one drain cancel out.
        const auto HasSwitch = InRequests.SwitchSeasoningRequests.Num() % 2 == 1;
        const auto HasCollect = InRequests.CollectRequests.Num() > 0;
        const auto HasRelease = InRequests.ReleaseRequests.Num() > 0;
        const auto HasPress = InRequests.PressRequests.Num() > 0;

        // InRequests is invalid past this line; removing before broadcasting lets re-entrant requests survive.
        Self.Request_TryRemove(FMars_Fragment_Mortar_Requests);

        const auto Spec = Self.Get_Spec();
        auto IsEngaged = Self.Has_Fragment(FMars_Tag_Mortar_Engaged);
        const auto WasEngaged = IsEngaged;
        auto BatchChanged = false;
        auto StrikeStarted = false;

        if (HasDisengage)
        {
            IsEngaged = false;
            InState.Pestle = FMars_Mortar_PestleState();
        }

        if (HasEngage)
        {
            IsEngaged = true;
            InState.SweepSeconds = 0.0f;
        }

        if (HasSwitch && utils_mortar::Get_IsFresh(InState.Batch))
        {
            InState.Batch.Seasoning = EMars_Mortar_Seasoning((int32(InState.Batch.Seasoning) + 1) % constants_mortar::k_SeasoningCount);
            BatchChanged = true;
        }

        if (HasCollect && InState.Batch.Phase == EMars_Mortar_Phase::Done)
        {
            const auto Seasoning = InState.Batch.Seasoning;
            InState.Tally.Counts[int32(Seasoning)] += 1;
            InState.Batch = FMars_Mortar_Batch();
            InState.Batch.Seasoning = Seasoning;
            InState.SweepSeconds = 0.0f;
            BatchChanged = true;
        }

        // The pestle is only in a hand while engaged.
        if (IsEngaged && HasRelease)
        { InState.Pestle.Press = EMars_Mortar_Press::Released; }

        if (IsEngaged && HasPress)
        {
            InState.Pestle.Press = EMars_Mortar_Press::Held;

            const auto CanStrike = InState.Batch.Phase == EMars_Mortar_Phase::Crush
                && InState.Pestle.StrikePhase == EMars_Mortar_StrikePhase::Idle;
            if (CanStrike)
            {
                const auto Window = utils_mortar::Make_Window(Spec.Timing, InState.SweepSeconds);
                InState.Pestle.Pending = utils_mortar::Get_IsOnMarker(Window) ? EMars_Mortar_Strike::Hit : EMars_Mortar_Strike::Miss;
                InState.Pestle.StrikePhase = EMars_Mortar_StrikePhase::Striking;
                InState.Pestle.StrikeSecondsLeft = Spec.StrikeSeconds;
                StrikeStarted = true;
            }
        }

        // A released or dropped pestle stops circling here; the Tick starts it.
        if (InState.Pestle.Press == EMars_Mortar_Press::Released)
        { InState.Pestle.Motion = EMars_Mortar_Pestle::Resting; }

        const auto Batch = InState.Batch;

        // InState is not read past this line: the tag moves, and a listener may add fragments to the station.
        if (IsEngaged && WasEngaged == false)
        { Self.Add_Fragment(FMars_Tag_Mortar_Engaged()); }
        else if (IsEngaged == false && WasEngaged)
        { Self.Request_TryRemove(FMars_Tag_Mortar_Engaged); }

        if (Self.Has_Fragment(FMars_Fragment_Mortar_Signals) == false)
        { return; }

        auto& Signals = Self.Get_Fragment(FMars_Fragment_Mortar_Signals);
        if (BatchChanged)
        { Signals.OnBatchChanged.Broadcast(Self, Batch); }

        if (StrikeStarted)
        { Signals.OnStrikeStarted.Broadcast(Self); }
    }
}
