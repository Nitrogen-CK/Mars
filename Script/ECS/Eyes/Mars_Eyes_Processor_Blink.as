// Random blinking on the presentation: counts down to the next blink, then closes (smoothstep over BlinkCloseSeconds),
// holds, and opens again (smoothstep over BlinkOpenSeconds). After a blink a second one may follow after a short gap
// (DoubleBlinkChance, never chained into a third); otherwise the next one is drawn from the blink interval. A disabled
// spec or an active expression that forbids blinking holds the eyes open, drops a pending double blink and, as it
// starts, draws the next blink afresh, so blinking resumes a full interval after the suppression ends.
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
        const auto& Tuning = InHandle.Get_Fragment(FMars_Fragment_Eyes_Params).Tuning;
        const auto DeltaSeconds = float32(InDeltaT.Get_Seconds());

        if (Tuning.BlinkEnabled == false || InPresentation.AllowBlink == false)
        {
            if (InPresentation.BlinkSuppressed == false)
            {
                InPresentation.BlinkSuppressed = true;
                InPresentation.SecondsToNextBlink = utils_eyes::DoDraw_BlinkInterval(Tuning);
            }

            InPresentation.Blink = 0.0f;
            InPresentation.BlinkPhaseSeconds = -1.0f;
            InPresentation.DoubleBlinkPending = false;
            return;
        }

        InPresentation.BlinkSuppressed = false;

        if (InPresentation.BlinkPhaseSeconds < 0.0f)
        {
            InPresentation.SecondsToNextBlink -= DeltaSeconds;
            if (InPresentation.SecondsToNextBlink > 0.0f)
            { return; }

            InPresentation.BlinkPhaseSeconds = 0.0f;
        }
        else
        { InPresentation.BlinkPhaseSeconds += DeltaSeconds; }

        const auto Phase = InPresentation.BlinkPhaseSeconds;
        const auto ClosedAt = Tuning.BlinkCloseSeconds;
        const auto HoldEndsAt = ClosedAt + Tuning.BlinkHoldSeconds;
        const auto OpenedAt = HoldEndsAt + Tuning.BlinkOpenSeconds;

        if (Phase < ClosedAt)
        {
            InPresentation.Blink = Math::SmoothStep(0.0f, ClosedAt, Phase);
            return;
        }

        if (Phase < HoldEndsAt)
        {
            InPresentation.Blink = 1.0f;
            return;
        }

        if (Phase < OpenedAt)
        {
            InPresentation.Blink = 1.0f - Math::SmoothStep(HoldEndsAt, OpenedAt, Phase);
            return;
        }

        InPresentation.Blink = 0.0f;
        InPresentation.BlinkPhaseSeconds = -1.0f;
        ++InPresentation.BlinkCount;

        if (InPresentation.DoubleBlinkPending)
        {
            InPresentation.DoubleBlinkPending = false;
            InPresentation.SecondsToNextBlink = utils_eyes::DoDraw_BlinkInterval(Tuning);
            return;
        }

        if (Math::RandRange(0.0f, 1.0f) < Tuning.DoubleBlinkChance)
        {
            InPresentation.DoubleBlinkPending = true;
            InPresentation.SecondsToNextBlink = constants_eyes::k_DoubleBlinkGapSeconds;
            return;
        }

        InPresentation.SecondsToNextBlink = utils_eyes::DoDraw_BlinkInterval(Tuning);
    }
}
