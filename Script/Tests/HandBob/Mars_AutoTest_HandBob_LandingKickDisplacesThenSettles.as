// Landing from a fall kicks the hands down (the vertical spring dips), then the spring bounces back and settles at rest.
// Falling itself adds no offset: CkSway on the hand node owns the airborne lag. Kernel level (utils_hand_bob::Advance):
// the HandBob processor only animates a locally controlled character.
class UMars_AutoTest_HandBob_LandingKickDisplacesThenSettles : UCk_AutoTest_Base
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("a landing dips the hands, then they settle", n"Step_Land");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Land(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Spec = FMars_HandBob_Spec();
        const auto DeltaSeconds = 1.0f / 60.0f;
        auto State = FMars_Fragment_HandBob();

        auto Falling = FMars_HandBob_Input();
        Falling.DeltaSeconds = DeltaSeconds;
        Falling.IsFalling = true;
        Falling.VerticalSpeed = -600.0f;
        for (int32 Frame = 0; Frame < 30; ++Frame)
        { utils_hand_bob::Advance(Spec, State, Falling); }

        Assert_Equals_Float(State.SpringOffset, 0.0, 0.0001, "falling adds no offset of its own");

        auto Landed = FMars_HandBob_Input();
        Landed.DeltaSeconds = DeltaSeconds;
        auto Lowest = 0.0f;
        for (int32 Frame = 0; Frame < 30; ++Frame)
        {
            utils_hand_bob::Advance(Spec, State, Landed);
            Lowest = Math::Min(Lowest, State.SpringOffset);
        }

        Assert_True(Lowest < -1.0f, f"the landing dips the hands (lowest [{Lowest :.3}] cm)");

        for (int32 Frame = 0; Frame < 600; ++Frame)
        { utils_hand_bob::Advance(Spec, State, Landed); }

        Assert_Equals_Float(State.SpringOffset, 0.0, 0.01, "the hands settle back at rest");
        Assert_Equals_Float(State.SpringVelocity, 0.0, 0.01, "and stop moving");
    }
}
