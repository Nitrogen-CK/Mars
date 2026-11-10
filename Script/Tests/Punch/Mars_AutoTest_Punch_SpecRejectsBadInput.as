// The fists' spec rejects what would break them at runtime, each with its own message: a negative or non-finite damage, a
// reach or radius that sweeps nothing, a recovery that never brings the fist home, a negative interval, and a combo window
// shorter than the interval (the combo would end between two jabs of one string). The player's configured spec is valid.
// Validate() is called directly so the rejections do not trip Add's ensure.
class UMars_AutoTest_Punch_SpecRejectsBadInput : UCk_AutoTest_Base
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        const auto Valid = FMars_Punch_Spec();
        Assert_True(Valid.Validate().IsValid(), f"the default spec is valid: {Valid.Validate().Get_Error()}");
        Assert_True(mars::Mars_PlayerCharacter_Config.Punch.Validate().IsValid(), "the player's configured fists are valid");

        const auto NotANumber = float32(Math::Sqrt(-1.0));

        auto NegativeDamage = Valid;
        NegativeDamage.Blow.Damage = -1.0f;
        AssertRejects(NegativeDamage, "Blow.Damage", "a negative damage");

        auto NanDamage = Valid;
        NanDamage.Blow.Damage = NotANumber;
        AssertRejects(NanDamage, "Blow.Damage", "a NaN damage");

        auto NoReach = Valid;
        NoReach.Blow.Reach = 0.0f;
        AssertRejects(NoReach, "Blow.Reach", "a zero reach");

        auto NoRadius = Valid;
        NoRadius.Blow.Radius = 0.0f;
        AssertRejects(NoRadius, "Blow.Radius", "a zero radius");

        auto NegativeImpulse = Valid;
        NegativeImpulse.Blow.ImpulseSpeed = -5.0f;
        AssertRejects(NegativeImpulse, "Blow.ImpulseSpeed", "a negative impulse");

        auto NegativeImpact = Valid;
        NegativeImpact.Rhythm.ImpactSeconds = -0.1f;
        AssertRejects(NegativeImpact, "Rhythm.ImpactSeconds", "a negative impact time");

        auto NoRecovery = Valid;
        NoRecovery.Rhythm.RecoverySeconds = 0.0f;
        AssertRejects(NoRecovery, "Rhythm.RecoverySeconds", "a zero recovery");

        auto NegativeInterval = Valid;
        NegativeInterval.Rhythm.IntervalSeconds = -0.1f;
        AssertRejects(NegativeInterval, "Rhythm.IntervalSeconds", "a negative interval");

        auto ShortCombo = Valid;
        ShortCombo.Rhythm.IntervalSeconds = 0.5f;
        ShortCombo.Rhythm.ComboSeconds = 0.2f;
        AssertRejects(ShortCombo, "Rhythm.ComboSeconds", "a combo window shorter than the interval");

        // An instant blow is allowed: the fist deals it on the first frame after the throw.
        auto InstantBlow = Valid;
        InstantBlow.Rhythm.ImpactSeconds = 0.0f;
        Assert_True(InstantBlow.Validate().IsValid(), "a zero impact time is valid");

        FinishSuccess();
    }

    private void AssertRejects(const FMars_Punch_Spec& InSpec, const FString& InExpectedError, const FString& InCase)
    {
        const auto Validation = InSpec.Validate();
        Assert_False(Validation.IsValid(), f"{InCase} is rejected");
        Assert_True(Validation.Get_Error().Contains(InExpectedError), f"{InCase}: the error names it ([{Validation.Get_Error()}])");
    }
}
