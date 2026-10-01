// Eases the presentation's look offset toward the node's Gaze target (yaw / pitch scaled by LookMaxYawDeg /
// LookMaxPitchDeg, clamped to -1..1), or back to centre when there is no Gaze, no target, look is disabled in the spec
// or the active expression forbids it. Frame-rate independent exponential ease at LookInterpSpeed.
class UMars_Processor_Eyes_Look : UCk_Processor_Script_Base_UE
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

        auto Goal = FVector2D(0.0, 0.0);
        if (Tuning.LookEnabled && InPresentation.AllowLook && utils_gaze::Has(InHandle))
        {
            const auto Gaze = InHandle.As_Gaze();
            if (Gaze.Get_HasTarget())
            {
                const auto AimDeg = Gaze.Get_AimYawPitchDeg();
                Goal = FVector2D(
                    Math::Clamp(AimDeg.X / Tuning.LookMaxYawDeg, -1.0, 1.0),
                    Math::Clamp(AimDeg.Y / Tuning.LookMaxPitchDeg, -1.0, 1.0));
            }
        }

        const auto Alpha = 1.0f - Math::Exp(-Tuning.LookInterpSpeed * DeltaSeconds);
        InPresentation.LookOffset += (Goal - InPresentation.LookOffset) * Alpha;
    }
}
