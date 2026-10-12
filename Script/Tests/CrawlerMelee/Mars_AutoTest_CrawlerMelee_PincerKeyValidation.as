// The pincer's Validate(): the default keys are admitted on both rigs; an enabled pincer is rejected when a key lies past
// the front leg's reach, on the wrong side of the body, or on a leg count with no rig; a disabled one is never checked,
// however broken. Pure: nothing is spawned.
class UMars_AutoTest_CrawlerMelee_PincerKeyValidation : UMars_AutoTestRig_CrawlerMelee
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("Validate() admits the default keys and names the broken rule of an enabled pincer", n"Step_Assert");
        Run_Steps(InHandle);
    }

    private FMars_Crawler_AttackPincer Make_Pincer() const
    {
        auto Pincer = FMars_Crawler_AttackPincer();
        Pincer.Enabled = true;
        return Pincer;
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto OnFour = Make_Pincer().Validate(4);
        const auto OnSix = Make_Pincer().Validate(6);
        Assert_True(OnFour.IsValid() && OnSix.IsValid(),
            f"the default keys are within reach of both rigs' front hips (4 legs: [{OnFour.Get_Error()}], 6 legs: [{OnSix.Get_Error()}])");

        auto TooFar = Make_Pincer();
        TooFar.Strike = FVector(200.0, 12.0, 0.0);
        const auto TooFarValidation = TooFar.Validate(4);
        Assert_True(TooFarValidation.IsValid() == false && TooFarValidation.Get_Error().Contains("from the front hip"),
            f"a strike key past the front leg's reach is rejected by name (got [{TooFarValidation.Get_Error()}])");

        auto TooNear = Make_Pincer();
        TooNear.Windup = FVector(25.0, 25.0, 0.0);
        const auto TooNearValidation = TooNear.Validate(4);
        Assert_True(TooNearValidation.IsValid() == false && TooNearValidation.Get_Error().Contains("from the front hip"),
            f"a windup key folded onto the hip is rejected by name (got [{TooNearValidation.Get_Error()}])");

        auto WrongSide = Make_Pincer();
        WrongSide.Windup = FVector(55.0, -100.0, 35.0);
        const auto WrongSideValidation = WrongSide.Validate(4);
        Assert_True(WrongSideValidation.IsValid() == false && WrongSideValidation.Get_Error().Contains("on the body's right"),
            f"a key on the left of the body is rejected by name (got [{WrongSideValidation.Get_Error()}])");

        const auto NoRigValidation = Make_Pincer().Validate(5);
        Assert_True(NoRigValidation.IsValid() == false && NoRigValidation.Get_Error().Contains("no rig"),
            f"an enabled pincer on a leg count with no rig is rejected by name (got [{NoRigValidation.Get_Error()}])");

        auto Disabled = FMars_Crawler_AttackPincer();
        Disabled.Strike = FVector(2000.0, -50.0, 0.0);
        Disabled.MaxReachFraction = 7.0f;
        Assert_True(Disabled.Validate(4).IsValid(), "a disabled pincer is never checked");
    }
}
