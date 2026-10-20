// The gloves' spec rejects what would break them at runtime, each with its own message: a non-positive or non-finite
// focus lean rate (the lean would diverge), a negative side-switch margin, a reach-pose fraction or a push open fraction
// outside 0..1, and a socket handle with no size. The first-person view spec (on the character's config) rejects a scale
// outside (0, 1]. Validate() is called directly so the rejections do not trip Add's ensure.
class UMars_AutoTest_FPHands_SpecRejectsBadInput : UCk_AutoTest_Base
{
    private FMars_FPHands_Spec _Valid;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Root = utils_transform::Add(InHandle, FTransform::Identity, ECk_Replication::DoesNotReplicate);
        _Valid = FMars_FPHands_Spec();
        _Valid.HandNode = utils_scene_node::Create(Root, FTransform::Identity).As_Transform();
        Assert_True(_Valid.Validate().IsValid(), f"the default spec with a hand node is valid: {_Valid.Validate().Get_Error()}");

        const auto NotANumber = float32(Math::Sqrt(-1.0));

        auto NegativeRate = _Valid;
        NegativeRate.Reach.Focus.InterpSpeed = -1.0f;
        AssertRejects(NegativeRate, "Reach.Focus.InterpSpeed", "a negative focus lean rate");

        auto NanRate = _Valid;
        NanRate.Reach.Focus.InterpSpeed = NotANumber;
        AssertRejects(NanRate, "is not finite", "a NaN focus lean rate");

        auto NanLean = _Valid;
        NanLean.Reach.Focus.Lean = NotANumber;
        AssertRejects(NanLean, "is not finite", "a NaN focus lean");

        auto NegativeMargin = _Valid;
        NegativeMargin.Reach.Focus.SideSwitchMarginCm = -1.0f;
        AssertRejects(NegativeMargin, "SideSwitchMarginCm", "a negative side-switch margin");

        auto PoseFraction = _Valid;
        PoseFraction.Reach.Poses.ApproachUntilFraction = 1.2f;
        AssertRejects(PoseFraction, "Reach.Poses", "a reach-pose fraction above 1");

        auto CurlFraction = _Valid;
        CurlFraction.Reach.Poses.ContactCurlFromAlpha = -0.1f;
        AssertRejects(CurlFraction, "Reach.Poses", "a contact-curl alpha below 0");

        auto OpenFraction = _Valid;
        OpenFraction.Push.OpenAtOutFraction = 1.5f;
        AssertRejects(OpenFraction, "Push.OpenAtOutFraction", "a push open fraction above 1");

        auto FlatHandle = _Valid;
        FlatHandle.Contact.SocketHandleRadiusCm = 0.0f;
        AssertRejects(FlatHandle, "SocketHandleRadiusCm", "a zero socket handle radius");

        auto ShortHandle = _Valid;
        ShortHandle.Contact.SocketHandleHalfLengthCm = -2.0f;
        AssertRejects(ShortHandle, "SocketHandleHalfLengthCm", "a negative socket handle half length");

        Assert_True(FMars_FPHands_ViewSpec().Validate().IsValid(), "the default view spec is valid");
        auto NoScale = FMars_FPHands_ViewSpec();
        NoScale.FirstPersonScale = 0.0f;
        Assert_False(NoScale.Validate().IsValid(), "a zero first-person scale is rejected");
        auto OverScale = FMars_FPHands_ViewSpec();
        OverScale.FirstPersonScale = 1.5f;
        Assert_False(OverScale.Validate().IsValid(), "a first-person scale above 1 is rejected");

        Assert_True(mars::Mars_PlayerCharacter_Config.FPHandsView.Validate().IsValid(), "the player's configured view spec is valid");

        FinishSuccess();
    }

    private void AssertRejects(const FMars_FPHands_Spec& InSpec, const FString& InExpectedError, const FString& InCase)
    {
        const auto Validation = InSpec.Validate();
        Assert_False(Validation.IsValid(), f"{InCase} is rejected");
        Assert_True(Validation.Get_Error().Contains(InExpectedError), f"{InCase}: the error names it ([{Validation.Get_Error()}])");
    }
}
