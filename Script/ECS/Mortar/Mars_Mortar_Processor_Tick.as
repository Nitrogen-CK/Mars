// The mortar's clocks, while it is engaged. The timing window pans through its pass and starts again (Crush phase only).
// A strike counts down Spec.StrikeSeconds and lands (OnStrikeLanded; a hit crushes, and the last hit needed cracks the
// batch and opens the Grind phase), then its recover counts down as long; a long frame finishes at most one phase, so the
// landing is never skipped. In the Grind phase the pestle circles while it is held with no strike in flight, and the
// grind's progress fills over Spec.GrindSeconds of that; full, the batch is Ground and Done.
class UMars_Processor_Mortar_Tick : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _RunAfter.Add(n"/Script/Angelscript.Mars_Processor_Mortar_HandleRequests");

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Mortar);
        Query.Require(FMars_Tag_Mortar_Engaged);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_Fragment_Mortar& InState)
    {
        auto Self = InHandle.As_Mortar();
        const auto Spec = Self.Get_Spec();
        const auto DeltaSeconds = float32(InDeltaT.Get_Seconds());
        auto BatchChanged = false;
        auto Landed = TOptional<EMars_Mortar_Strike>();

        if (InState.Batch.Phase == EMars_Mortar_Phase::Crush)
        {
            InState.SweepSeconds += DeltaSeconds;
            while (InState.SweepSeconds >= Spec.Timing.SweepSeconds)
            { InState.SweepSeconds -= Spec.Timing.SweepSeconds; }
        }

        if (InState.Pestle.StrikePhase != EMars_Mortar_StrikePhase::Idle)
        {
            InState.Pestle.StrikeSecondsLeft = Math::Max(0.0f, InState.Pestle.StrikeSecondsLeft - DeltaSeconds);
            if (InState.Pestle.StrikeSecondsLeft <= 0.0f)
            {
                if (InState.Pestle.StrikePhase == EMars_Mortar_StrikePhase::Recovering)
                { InState.Pestle.StrikePhase = EMars_Mortar_StrikePhase::Idle; }
                else
                {
                    InState.Pestle.StrikePhase = EMars_Mortar_StrikePhase::Recovering;
                    InState.Pestle.StrikeSecondsLeft = Spec.StrikeSeconds;
                    Landed = InState.Pestle.Pending;
                    BatchChanged = Apply_Strike(InState.Batch, InState.Pestle.Pending, Spec);
                }
            }
        }

        const auto IsGrinding = InState.Batch.Phase == EMars_Mortar_Phase::Grind
            && InState.Pestle.Press == EMars_Mortar_Press::Held
            && InState.Pestle.StrikePhase == EMars_Mortar_StrikePhase::Idle;
        InState.Pestle.Motion = IsGrinding ? EMars_Mortar_Pestle::Grinding : EMars_Mortar_Pestle::Resting;
        if (IsGrinding)
        {
            InState.Batch.GrindProgress = Math::Min(1.0f, InState.Batch.GrindProgress + DeltaSeconds / Spec.GrindSeconds);
            if (InState.Batch.GrindProgress >= 1.0f)
            {
                InState.Batch.Stage = EMars_Mortar_Stage::Ground;
                InState.Batch.Phase = EMars_Mortar_Phase::Done;
                InState.Pestle.Motion = EMars_Mortar_Pestle::Resting;
                BatchChanged = true;
            }
        }

        const auto Batch = InState.Batch;

        // InState is not read past this line: a listener may add fragments to the station.
        if (Self.Has_Fragment(FMars_Fragment_Mortar_Signals) == false)
        { return; }

        auto& Signals = Self.Get_Fragment(FMars_Fragment_Mortar_Signals);
        if (Landed.IsSet())
        { Signals.OnStrikeLanded.Broadcast(Self, Landed.GetValue()); }

        if (BatchChanged)
        { Signals.OnBatchChanged.Broadcast(Self, Batch); }
    }

    // A hit in the Crush phase counts, and the last one needed cracks the batch and opens the Grind phase. True when the
    // batch changed.
    private bool Apply_Strike(FMars_Mortar_Batch& InOutBatch, EMars_Mortar_Strike InStrike, const FMars_Mortar_Spec& InSpec) const
    {
        if (InStrike != EMars_Mortar_Strike::Hit || InOutBatch.Phase != EMars_Mortar_Phase::Crush)
        { return false; }

        InOutBatch.CrushHits += 1;
        if (InOutBatch.CrushHits >= InSpec.CrushesNeeded)
        {
            InOutBatch.Stage = EMars_Mortar_Stage::Cracked;
            InOutBatch.Phase = EMars_Mortar_Phase::Grind;
        }

        return true;
    }
}
