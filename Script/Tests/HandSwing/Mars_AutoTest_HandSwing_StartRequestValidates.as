// The authored arcs validate; an arc with no strike travel, an impact fraction outside 0..1 or a non-finite key does not,
// nor does a start with a negative impact time or no recovery. A short request still leaves a minimum recovery, and a
// request whose impact comes sooner than the strike's lead collapses the windup to nothing rather than going negative.
class UMars_AutoTest_HandSwing_StartRequestValidates : UCk_AutoTest_Base
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("arcs and requests validate", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(utils_hand_swing::Make_ChopArc().Validate().IsValid(), "the chop arc validates");
        Assert_True(utils_hand_swing::Make_OverheadArc().Validate().IsValid(), "the overhead arc validates");
        Assert_True(utils_hand_swing::Make_SwipeArc().Validate().IsValid(), "the swipe arc validates");

        auto NoTravel = utils_hand_swing::Make_ChopArc();
        NoTravel.StrikeSeconds = 0.0f;
        Assert_False(NoTravel.Validate().IsValid(), "an arc with no strike travel does not validate");

        auto LateImpact = utils_hand_swing::Make_ChopArc();
        LateImpact.ImpactFraction = 1.5f;
        Assert_False(LateImpact.Validate().IsValid(), "an impact fraction past 1 does not validate");

        auto NotFinite = utils_hand_swing::Make_ChopArc();
        NotFinite.Strike.Location = FVector(0.0, 0.0, 1.0e308 * 10.0);
        Assert_False(NotFinite.Validate().IsValid(), "a non-finite strike key does not validate");

        Assert_True(FMars_Request_HandSwing_Start(utils_hand_swing::Make_ChopArc(), 0.15f, 0.35f).Validate().IsValid(),
            "the cleaver's request validates");
        Assert_False(FMars_Request_HandSwing_Start(utils_hand_swing::Make_ChopArc(), -0.1f, 0.35f).Validate().IsValid(),
            "a negative impact time does not validate");
        Assert_False(FMars_Request_HandSwing_Start(utils_hand_swing::Make_ChopArc(), 0.15f, 0.0f).Validate().IsValid(),
            "a request with no recovery does not validate");
        Assert_False(FMars_Request_HandSwing_Start(NoTravel, 0.15f, 0.35f).Validate().IsValid(),
            "a request with an invalid arc does not validate");

        // Impact 0.02 s with a 0.12 s travel landing at 65%: the windup would start 0.058 s before the swing.
        const auto Sudden = utils_hand_swing::Make_Timeline(utils_hand_swing::Make_ChopArc(), 0.02f, 0.01f);
        Assert_Equals_Float(Sudden.WindupEnd, 0.0f, 0.0001, "an impact sooner than the strike's lead collapses the windup");
        Assert_Equals_Float(Sudden.StrikeEnd, 0.12f, 0.0001, "the strike travel keeps its length");
        Assert_Equals_Float(Sudden.RecoverEnd, 0.12f + constants_hand_swing::k_MinRecoverSeconds, 0.0001,
            "a recovery that would end inside the strike travel is pushed past it by the minimum");
    }
}
