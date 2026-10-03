// Eases the presentation's look offset toward the node's Gaze target (yaw / pitch scaled by MaxYawDeg / MaxPitchDeg,
// clamped to -1..1), or back to centre when there is no Gaze, no target, or the active expression forbids it.
// Frame-rate independent exponential ease at InterpSpeed. Eyes without a look spec stay centred.
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
        const auto& LookSpec = InHandle.Get_Fragment(FMars_Fragment_Eyes_Params).Look;
        if (LookSpec.IsSet() == false)
        { return; }

        const auto& Spec = LookSpec.GetValue();
        const auto DeltaSeconds = float32(InDeltaT.Get_Seconds());

        auto Goal = FVector2D(0.0, 0.0);
        // Gaze is optional: an eye node without one looks straight ahead.
        const auto Gaze = InHandle.As_Gaze(ECk_SanityCheck::UnChecked);
        if (InPresentation.AllowLook && ck::IsValid(Gaze) && Gaze.Get_HasTarget())
        {
            const auto AimDeg = Gaze.Get_AimYawPitchDeg();
            Goal = FVector2D(
                Math::Clamp(AimDeg.X / Spec.MaxYawDeg, -1.0, 1.0),
                Math::Clamp(AimDeg.Y / Spec.MaxPitchDeg, -1.0, 1.0));
        }

        const auto Alpha = 1.0f - Math::Exp(-Spec.InterpSpeed * DeltaSeconds);
        InPresentation.LookOffset += (Goal - InPresentation.LookOffset) * Alpha;
    }
}
