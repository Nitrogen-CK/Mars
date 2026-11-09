// The bed's Pull tuner validates: the defaults and a hand-set tuner are accepted, and each rule rejects its own field - a
// travel of 0 or NaN, a travel under or over the mesh's safe range (constants_screaming_turnip_assets 20 .. 230 cm), a NaN
// lift, no stiffness, a negative damping, a threshold of 0 or past 1, no Grip span, no Cancel
// span, no turn. A bed spawned with an invalid Pull (travel 0) ensures once (expected: this file's hand-authored wrapper)
// and destroys itself before composing anything: no Forage, no Control is left on it.
class UMars_AutoTest_ScreamingTurnipBed_PullSpecValidateRejectsBadTuners : UCk_AutoTest_Base
{
    private const FVector k_Origin = FVector(430000.0, 36000.0, -30000.0);

    private FCk_Handle _RejectedBed;
    private bool _RejectedConstructed = false;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("validate the defaults, a hand-set tuner and one break per rule", n"Step_Validate");
        Add_Step("spawn a bed whose Pull has no travel", n"Step_SpawnRejected");
        Add_Step_WaitUntil("the rejected bed's construction returned", n"Check_RejectedConstructed", 0, 0);
        Add_Step_WaitFrames("let the self-destroy settle", 10);
        Add_Step("the rejected bed composed nothing", n"Step_AssertRejectedComposedNothing");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Validate(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Defaults = FMars_ScreamingTurnipBed_PullSpec();
        AssertValid(Defaults, "the defaults");

        const auto HandSet = FMars_ScreamingTurnipBed_PullSpec(FMars_ScreamingTurnipBed_StretchSpec(74.0f, -5.0f),
            FMars_ScreamingTurnipBed_SpringSpec(60.0f, 0.0f, 1.0f), FMars_ScreamingTurnipBed_TimingSpec(0.1f, 0.3f, 90.0f));
        AssertValid(HandSet, "a hand-set tuner (a negative lift, no damping and a threshold of 1 are allowed)");

        const auto NaN = float32(Math::Sqrt(-1.0f));

        auto NoTravel = Defaults;
        NoTravel.Stretch.TravelCm = 0.0f;
        AssertInvalid(NoTravel, "a travel of 0", "Pull.Stretch.TravelCm");

        auto NaNTravel = Defaults;
        NaNTravel.Stretch.TravelCm = NaN;
        AssertInvalid(NaNTravel, "a NaN travel", "Pull.Stretch.TravelCm");

        auto ShortTravel = Defaults;
        ShortTravel.Stretch.TravelCm = constants_screaming_turnip_assets::k_StretchTravelSafeMinCm - 1.0f;
        AssertInvalid(ShortTravel, "a travel under the safe range", "safe range");

        auto LongTravel = Defaults;
        LongTravel.Stretch.TravelCm = constants_screaming_turnip_assets::k_StretchTravelSafeMaxCm + 1.0f;
        AssertInvalid(LongTravel, "a travel over the safe range", "safe range");

        auto EdgeTravel = Defaults;
        EdgeTravel.Stretch.TravelCm = constants_screaming_turnip_assets::k_StretchTravelSafeMaxCm;
        AssertValid(EdgeTravel, "a travel at the safe range's maximum");

        auto NaNLift = Defaults;
        NaNLift.Stretch.LiftCm = NaN;
        AssertInvalid(NaNLift, "a NaN lift", "Pull.Stretch.LiftCm");

        auto NoStiffness = Defaults;
        NoStiffness.Spring.Stiffness = 0.0f;
        AssertInvalid(NoStiffness, "no stiffness", "Pull.Spring.Stiffness");

        auto PushingDamper = Defaults;
        PushingDamper.Spring.Damping = -1.0f;
        AssertInvalid(PushingDamper, "a negative damping", "Pull.Spring.Damping");

        auto NoThreshold = Defaults;
        NoThreshold.Spring.EngageAlpha = 0.0f;
        AssertInvalid(NoThreshold, "a threshold of 0", "Pull.Spring.EngageAlpha");

        auto PastEnd = Defaults;
        PastEnd.Spring.EngageAlpha = 1.2f;
        AssertInvalid(PastEnd, "a threshold of 1.2", "Pull.Spring.EngageAlpha");

        auto NoGrip = Defaults;
        NoGrip.Timing.GripSeconds = 0.0f;
        AssertInvalid(NoGrip, "no Grip span", "Pull.Timing.GripSeconds");

        auto NoCancel = Defaults;
        NoCancel.Timing.CancelSecondsFromFullStrain = 0.0f;
        AssertInvalid(NoCancel, "no Cancel span", "Pull.Timing.CancelSecondsFromFullStrain");

        auto NoTurn = Defaults;
        NoTurn.Timing.TurnDegreesPerSecond = 0.0f;
        AssertInvalid(NoTurn, "no turn", "Pull.Timing.TurnDegreesPerSecond");
    }

    UFUNCTION()
    private void Step_SpawnRejected(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Params = UMars_ScreamingTurnipBed_EntityScript::Params();
        Params.SpawnTransform = FTransform(FRotator::ZeroRotator, k_Origin);
        Params.Pull.Stretch.TravelCm = 0.0f;

        auto Owner = InHandle;
        auto Pending = utils_entity_script::Request_SpawnEntity(Owner, UMars_ScreamingTurnipBed_EntityScript, Params);
        utils_pending_entity_script::Promise_OnConstructed(Pending, FCk_Delegate_EntityScript_Constructed(this, n"OnRejectedConstructed"));
    }

    UFUNCTION()
    private void OnRejectedConstructed(FCk_Handle_EntityScript InEntityScriptHandle)
    {
        _RejectedBed = InEntityScriptHandle;
        _RejectedConstructed = true;
    }

    UFUNCTION()
    private void Check_RejectedConstructed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_RejectedConstructed);
    }

    UFUNCTION()
    private void Step_AssertRejectedComposedNothing(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        if (ck::Is_NOT_Valid(_RejectedBed))
        { return; }

        Assert_False(_RejectedBed.Has_Fragment(FMars_Feature_Forage), "the rejected bed composed no Forage");
        Assert_False(_RejectedBed.Has_Fragment(FMars_Feature_Control), "the rejected bed composed no Control");
    }

    private void AssertValid(const FMars_ScreamingTurnipBed_PullSpec& InSpec, const FString& InCase)
    {
        const auto Validation = InSpec.Validate();
        Assert_True(Validation.IsValid(), f"{InCase} is accepted (error: {Validation.Get_Error()})");
    }

    // InField is the tuner field the rejection must name.
    private void AssertInvalid(const FMars_ScreamingTurnipBed_PullSpec& InSpec, const FString& InCase, const FString& InField)
    {
        const auto Validation = InSpec.Validate();
        Assert_False(Validation.IsValid(), f"{InCase} is rejected");
        Assert_True(Validation.Get_Error().Contains(InField), f"{InCase} names [{InField}] (error: {Validation.Get_Error()})");
    }
}

// Hand-authored so the bed's one expected rejection (the ensure in its DoConstruct on a Pull with no travel) is an expected
// error rather than a failure. Pinned to the rule's own wording, so any other rejection still fails the test.
class AMars_AutoTest_ScreamingTurnipBed_PullSpecValidateRejectsBadTuners_Actor : ACk_AutoTestRunner
{
    default _TestEntityScriptClass = UMars_AutoTest_ScreamingTurnipBed_PullSpecValidateRejectsBadTuners;

    UFUNCTION(BlueprintOverride)
    TArray<FString> Get_ExpectedLogErrors() const
    {
        TArray<FString> Out;
        Out.Add("rejected the Pull: Pull.Stretch.TravelCm [0");
        return Out;
    }
}
