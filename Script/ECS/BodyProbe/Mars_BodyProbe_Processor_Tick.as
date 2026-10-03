// Polls the capsule like EyeHeight does: the resize lands in a CharacterMovement tick, not when Crouch() is called, and an
// UnCrouch blocked by a ceiling never resizes at all.
class UMars_Processor_BodyProbe_Tick : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_BodyProbe);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_Fragment_BodyProbe& InState)
    {
        // The character tears the probe down with it; between its destruction and the probe's there is nothing to follow.
        auto Character = InHandle.Get_Fragment(FMars_Fragment_BodyProbe_Params).Spec.Character.Get();
        if (ck::Is_NOT_Valid(Character))
        { return; }

        const auto Capsule = Character.CapsuleComponent;
        const auto HalfHeight = Capsule.GetScaledCapsuleHalfHeight();
        const auto Radius = Capsule.GetScaledCapsuleRadius();
        if (HalfHeight == InState.HalfHeight && Radius == InState.Radius)
        { return; }

        InState.HalfHeight = HalfHeight;
        InState.Radius = Radius;
        auto Probe = InHandle.As_Probe();
        utils_probe::Request_ResizeCapsule(Probe, HalfHeight, Radius);
    }
}
