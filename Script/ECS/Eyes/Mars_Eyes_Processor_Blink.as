// Random blinking on the presentation (see FMars_Eyes_BlinkSpec). An active expression that forbids blinking holds the
// eyes open, drops a pending double blink and, as it starts, draws the next blink afresh, so blinking resumes a full
// interval after the suppression ends. Eyes without a blink spec stay open.
class UMars_Processor_Eyes_Blink : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Eyes);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_Fragment_Eyes_Presentation& InPresentation)
    {
        const auto& BlinkSpec = InHandle.Get_Fragment(FMars_Fragment_Eyes_Params).Blink;
        auto& State = InPresentation.Blink;

        if (BlinkSpec.IsSet() == false)
        {
            State.Closure = 0.0f;
            return;
        }

        const auto& Spec = BlinkSpec.GetValue();
        const auto DeltaSeconds = float32(InDeltaT.Get_Seconds());

        if (InPresentation.AllowBlink == false)
        {
            if (State.Stage != EMars_Eyes_BlinkStage::Suppressed)
            {
                State.Stage = EMars_Eyes_BlinkStage::Suppressed;
                State.SecondsToNextBlink = utils_eyes::DoDraw_BlinkInterval(Spec);
            }

            State.Closure = 0.0f;
            return;
        }

        if (State.Stage == EMars_Eyes_BlinkStage::Suppressed)
        { State.Stage = EMars_Eyes_BlinkStage::Waiting; }

        if (State.Stage == EMars_Eyes_BlinkStage::Waiting || State.Stage == EMars_Eyes_BlinkStage::WaitingForSecond)
        {
            State.SecondsToNextBlink -= DeltaSeconds;
            if (State.SecondsToNextBlink > 0.0f)
            { return; }

            State.Stage = State.Stage == EMars_Eyes_BlinkStage::WaitingForSecond
                ? EMars_Eyes_BlinkStage::BlinkingSecond
                : EMars_Eyes_BlinkStage::Blinking;
            State.PhaseSeconds = 0.0f;
        }
        else
        { State.PhaseSeconds += DeltaSeconds; }

        const auto Phase = State.PhaseSeconds;
        const auto ClosedAt = Spec.CloseSeconds;
        const auto HoldEndsAt = ClosedAt + Spec.HoldSeconds;
        const auto OpenedAt = HoldEndsAt + Spec.OpenSeconds;

        if (Phase < ClosedAt)
        {
            State.Closure = Math::SmoothStep(0.0f, ClosedAt, Phase);
            return;
        }

        if (Phase < HoldEndsAt)
        {
            State.Closure = 1.0f;
            return;
        }

        if (Phase < OpenedAt)
        {
            State.Closure = 1.0f - Math::SmoothStep(HoldEndsAt, OpenedAt, Phase);
            return;
        }

        State.Closure = 0.0f;
        ++State.Count;

        if (State.Stage == EMars_Eyes_BlinkStage::Blinking && Math::RandRange(0.0f, 1.0f) < Spec.DoubleBlinkChance)
        {
            State.Stage = EMars_Eyes_BlinkStage::WaitingForSecond;
            State.SecondsToNextBlink = constants_eyes::k_DoubleBlinkGapSeconds;
            return;
        }

        State.Stage = EMars_Eyes_BlinkStage::Waiting;
        State.SecondsToNextBlink = utils_eyes::DoDraw_BlinkInterval(Spec);
    }
}
