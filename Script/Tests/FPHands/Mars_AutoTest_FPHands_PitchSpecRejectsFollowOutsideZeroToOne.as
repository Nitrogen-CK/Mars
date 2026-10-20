// A pitch spec is valid only with both follow fractions within 0..1 and an InterpSpeed that is unset (a snap) or positive.
// Validate() is called directly so the rejections do not trip Add's ensure.
class UMars_AutoTest_FPHands_PitchSpecRejectsFollowOutsideZeroToOne : UCk_AutoTest_Base
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Assert_True(FMars_FPHands_PitchSpec().Validate().IsValid(), "the default pitch spec is valid");

        auto Edges = FMars_FPHands_PitchSpec();
        Edges.FollowUp = 0.0f;
        Edges.FollowDown = 1.0f;
        Edges.InterpSpeed.Reset();
        Assert_True(Edges.Validate().IsValid(), "follow fractions of 0 and 1 and a snap are valid");

        auto OverUp = FMars_FPHands_PitchSpec();
        OverUp.FollowUp = 1.5f;
        Assert_False(OverUp.Validate().IsValid(), "FollowUp above 1 is rejected");

        auto NegativeUp = FMars_FPHands_PitchSpec();
        NegativeUp.FollowUp = -0.1f;
        Assert_False(NegativeUp.Validate().IsValid(), "a negative FollowUp is rejected");

        auto OverDown = FMars_FPHands_PitchSpec();
        OverDown.FollowDown = 1.5f;
        Assert_False(OverDown.Validate().IsValid(), "FollowDown above 1 is rejected");

        auto NegativeSpeed = FMars_FPHands_PitchSpec();
        NegativeSpeed.InterpSpeed = TOptional<float32>(-1.0f);
        Assert_False(NegativeSpeed.Validate().IsValid(), "a negative InterpSpeed is rejected");

        auto ZeroSpeed = FMars_FPHands_PitchSpec();
        ZeroSpeed.InterpSpeed = TOptional<float32>(0.0f);
        Assert_False(ZeroSpeed.Validate().IsValid(), "a zero InterpSpeed is rejected (unset is the snap)");

        FinishSuccess();
    }
}
