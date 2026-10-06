// What a rejection must report: the offending field first, then the rule it broke; What names the case.
struct FMars_AutoTest_EyesRejection
{
    UPROPERTY()
    FString Field;

    UPROPERTY()
    FString Rule;

    UPROPERTY()
    FString What;

    FMars_AutoTest_EyesRejection() {}

    FMars_AutoTest_EyesRejection(const FString& InField, const FString& InRule, const FString& InWhat)
    {
        Field = InField;
        Rule = InRule;
        What = InWhat;
    }
}

// FMars_Eyes_Spec::Validate() (and the expression def's) rejects each bad input with its own message, prefixed with its
// group; the default spec and the default blink and look groups pass; and a rejected utils_eyes::Add returns an invalid
// handle without adding any eyes fragment. Isolated Z band: -60000.
class UMars_AutoTest_Eyes_SpecRejectsBadInput : UMars_AutoTestRig_Eyes
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("the default spec is valid", n"Step_AssertDefaultValid");
        Add_Step("each bad input fails Validate() with its own message", n"Step_AssertEachRuleRejects");
        Add_Step("a rejected Add adds nothing", n"Step_AssertAddRejected");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AssertDefaultValid(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto DefaultSpec = FMars_Eyes_Spec();
        const auto Validation = DefaultSpec.Validate();
        Assert_True(Validation.IsValid(), f"Validate() on the default spec (got [{Validation.Get_Error()}])");
    }

    UFUNCTION()
    private void Step_AssertEachRuleRejects(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Blink = FMars_Eyes_BlinkSpec();
        auto Look = FMars_Eyes_LookSpec();

        auto Spec = FMars_Eyes_Spec();
        Spec.Style.LeftCell = constants_eyes::k_CellCount;
        AssertRejected(Spec.Validate(),
            FMars_AutoTest_EyesRejection("Style: LeftCell [32]", "is outside [0, 31]", "a style left cell past the atlas"));

        Spec = FMars_Eyes_Spec();
        Spec.Style.RightCell = -1;
        AssertRejected(Spec.Validate(),
            FMars_AutoTest_EyesRejection("Style: RightCell [-1]", "is outside [0, 31]", "a negative style right cell"));

        Spec = FMars_Eyes_Spec();
        Spec.Blink = FMars_Eyes_BlinkSpec();
        Spec.Look = FMars_Eyes_LookSpec();
        const auto DefaultGroupsValidation = Spec.Validate();
        Assert_True(DefaultGroupsValidation.IsValid(),
            f"the default blink and look groups are valid (got [{DefaultGroupsValidation.Get_Error()}])");

        Blink = FMars_Eyes_BlinkSpec();
        Blink.IntervalMinSeconds = -1.0f;
        AssertRejected(Make_SpecWithBlink(Blink).Validate(),
            FMars_AutoTest_EyesRejection("Blink: IntervalMinSeconds", "is negative", "a negative interval min"));

        Blink = FMars_Eyes_BlinkSpec();
        Blink.IntervalMaxSeconds = -1.0f;
        AssertRejected(Make_SpecWithBlink(Blink).Validate(),
            FMars_AutoTest_EyesRejection("Blink: IntervalMaxSeconds", "is negative", "a negative interval max"));

        Blink = FMars_Eyes_BlinkSpec();
        Blink.CloseSeconds = -0.1f;
        AssertRejected(Make_SpecWithBlink(Blink).Validate(),
            FMars_AutoTest_EyesRejection("Blink: CloseSeconds", "is negative", "a negative close duration"));

        Blink = FMars_Eyes_BlinkSpec();
        Blink.HoldSeconds = -0.1f;
        AssertRejected(Make_SpecWithBlink(Blink).Validate(),
            FMars_AutoTest_EyesRejection("Blink: HoldSeconds", "is negative", "a negative hold duration"));

        Blink = FMars_Eyes_BlinkSpec();
        Blink.OpenSeconds = -0.1f;
        AssertRejected(Make_SpecWithBlink(Blink).Validate(),
            FMars_AutoTest_EyesRejection("Blink: OpenSeconds", "is negative", "a negative open duration"));

        Blink = FMars_Eyes_BlinkSpec();
        Blink.IntervalMinSeconds = 4.0f;
        Blink.IntervalMaxSeconds = 3.0f;
        AssertRejected(Make_SpecWithBlink(Blink).Validate(),
            FMars_AutoTest_EyesRejection("Blink: IntervalMinSeconds", "exceeds IntervalMaxSeconds", "an interval min above its max"));

        Blink = FMars_Eyes_BlinkSpec();
        Blink.IntervalMinSeconds = 0.0f;
        AssertRejected(Make_SpecWithBlink(Blink).Validate(),
            FMars_AutoTest_EyesRejection("Blink: IntervalMinSeconds", "must be > 0", "a zero interval min"));

        Blink = FMars_Eyes_BlinkSpec();
        Blink.DoubleBlinkChance = 1.5f;
        AssertRejected(Make_SpecWithBlink(Blink).Validate(),
            FMars_AutoTest_EyesRejection("Blink: DoubleBlinkChance", "is outside [0, 1]", "a double-blink chance above 1"));

        Blink = FMars_Eyes_BlinkSpec();
        Blink.DoubleBlinkChance = -0.5f;
        AssertRejected(Make_SpecWithBlink(Blink).Validate(),
            FMars_AutoTest_EyesRejection("Blink: DoubleBlinkChance", "is outside [0, 1]", "a negative double-blink chance"));

        Look = FMars_Eyes_LookSpec();
        Look.MaxYawDeg = 0.0f;
        AssertRejected(Make_SpecWithLook(Look).Validate(),
            FMars_AutoTest_EyesRejection("Look: MaxYawDeg", "must be > 0", "a zero max yaw"));

        Look = FMars_Eyes_LookSpec();
        Look.MaxPitchDeg = -10.0f;
        AssertRejected(Make_SpecWithLook(Look).Validate(),
            FMars_AutoTest_EyesRejection("Look: MaxPitchDeg", "must be > 0", "a negative max pitch"));

        Look = FMars_Eyes_LookSpec();
        Look.InterpSpeed = 0.0f;
        AssertRejected(Make_SpecWithLook(Look).Validate(),
            FMars_AutoTest_EyesRejection("Look: InterpSpeed", "must be > 0", "a zero look interp speed"));

        const auto NotANumber = float32(Math::Sqrt(-1.0));
        Assert_True(Math::IsNaN(NotANumber), "the test input is NaN");

        Spec = FMars_Eyes_Spec();
        Spec.Style.EmissiveStrength = NotANumber;
        AssertRejected(Spec.Validate(),
            FMars_AutoTest_EyesRejection("Style: EmissiveStrength", "is not finite", "a NaN style emissive strength"));

        Spec = FMars_Eyes_Spec();
        Spec.Style.EmissiveStrength = -1.0f;
        AssertRejected(Spec.Validate(),
            FMars_AutoTest_EyesRejection("Style: EmissiveStrength", "is negative", "a negative style emissive strength"));

        Spec = FMars_Eyes_Spec();
        Spec.Style.Color.G = NotANumber;
        AssertRejected(Spec.Validate(),
            FMars_AutoTest_EyesRejection("Style: Color", "has a channel that is not finite", "a NaN style color channel"));

        Spec = FMars_Eyes_Spec();
        Spec.Style.Color.B = -0.5f;
        AssertRejected(Spec.Validate(),
            FMars_AutoTest_EyesRejection("Style: Color", "has a negative channel", "a negative style color channel"));

        Blink = FMars_Eyes_BlinkSpec();
        Blink.IntervalMinSeconds = NotANumber;
        AssertRejected(Make_SpecWithBlink(Blink).Validate(),
            FMars_AutoTest_EyesRejection("Blink: IntervalMinSeconds", "is not finite", "a NaN interval min"));

        Blink = FMars_Eyes_BlinkSpec();
        Blink.IntervalMaxSeconds = NotANumber;
        AssertRejected(Make_SpecWithBlink(Blink).Validate(),
            FMars_AutoTest_EyesRejection("Blink: IntervalMaxSeconds", "is not finite", "a NaN interval max"));

        Blink = FMars_Eyes_BlinkSpec();
        Blink.CloseSeconds = NotANumber;
        AssertRejected(Make_SpecWithBlink(Blink).Validate(),
            FMars_AutoTest_EyesRejection("Blink: CloseSeconds", "is not finite", "a NaN close duration"));

        Blink = FMars_Eyes_BlinkSpec();
        Blink.HoldSeconds = NotANumber;
        AssertRejected(Make_SpecWithBlink(Blink).Validate(),
            FMars_AutoTest_EyesRejection("Blink: HoldSeconds", "is not finite", "a NaN hold duration"));

        Blink = FMars_Eyes_BlinkSpec();
        Blink.OpenSeconds = NotANumber;
        AssertRejected(Make_SpecWithBlink(Blink).Validate(),
            FMars_AutoTest_EyesRejection("Blink: OpenSeconds", "is not finite", "a NaN open duration"));

        Blink = FMars_Eyes_BlinkSpec();
        Blink.DoubleBlinkChance = NotANumber;
        AssertRejected(Make_SpecWithBlink(Blink).Validate(),
            FMars_AutoTest_EyesRejection("Blink: DoubleBlinkChance", "is not finite", "a NaN double-blink chance"));

        Look = FMars_Eyes_LookSpec();
        Look.MaxYawDeg = NotANumber;
        AssertRejected(Make_SpecWithLook(Look).Validate(),
            FMars_AutoTest_EyesRejection("Look: MaxYawDeg", "is not finite", "a NaN max yaw"));

        Look = FMars_Eyes_LookSpec();
        Look.MaxPitchDeg = NotANumber;
        AssertRejected(Make_SpecWithLook(Look).Validate(),
            FMars_AutoTest_EyesRejection("Look: MaxPitchDeg", "is not finite", "a NaN max pitch"));

        Look = FMars_Eyes_LookSpec();
        Look.InterpSpeed = NotANumber;
        AssertRejected(Make_SpecWithLook(Look).Validate(),
            FMars_AutoTest_EyesRejection("Look: InterpSpeed", "is not finite", "a NaN look interp speed"));

        auto Expression = FMars_Eyes_ExpressionDef();
        Expression.DurationSeconds = NotANumber;
        AssertRejected(Expression.Validate(),
            FMars_AutoTest_EyesRejection("DurationSeconds", "is not finite", "a NaN expression duration"));

        Expression = FMars_Eyes_ExpressionDef();
        Expression.BlendSeconds = NotANumber;
        AssertRejected(Expression.Validate(),
            FMars_AutoTest_EyesRejection("BlendSeconds", "is not finite", "a NaN expression blend time"));
    }

    UFUNCTION()
    private void Step_AssertAddRejected(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto FaceNode = Make_FaceNode(InHandle, FVector(0.0, 0.0, -60000.0));

        auto Spec = FMars_Eyes_Spec();
        Spec.Style.LeftCell = constants_eyes::k_CellCount;

        auto Rejected = utils_eyes::Add(FaceNode, Spec);
        Assert_Invalid(Rejected, "Add with a style cell past the atlas returns an invalid handle");
        Assert_False(FaceNode.Is_Eyes(), "a rejected spec adds no feature fragment");
        Assert_False(FaceNode.Has_Fragment(FMars_Fragment_Eyes_Params), "a rejected spec adds no params fragment");
        Assert_False(FaceNode.Has_Fragment(FMars_Fragment_Eyes), "a rejected spec adds no logic fragment");
        Assert_False(FaceNode.Has_Fragment(FMars_Fragment_Eyes_Presentation), "a rejected spec adds no presentation fragment");
    }

    private FMars_Eyes_Spec Make_SpecWithBlink(const FMars_Eyes_BlinkSpec& InBlink) const
    {
        auto Spec = FMars_Eyes_Spec();
        Spec.Blink = InBlink;
        return Spec;
    }

    private FMars_Eyes_Spec Make_SpecWithLook(const FMars_Eyes_LookSpec& InLook) const
    {
        auto Spec = FMars_Eyes_Spec();
        Spec.Look = InLook;
        return Spec;
    }

    // The message names the offending field first, then the rule it broke.
    private void AssertRejected(const FMars_Validation& InValidation, const FMars_AutoTest_EyesRejection& InExpected)
    {
        const auto Error = InValidation.Get_Error();
        Assert_False(InValidation.IsValid(), f"Validate() on {InExpected.What}");
        Assert_True(Error.StartsWith(InExpected.Field, ESearchCase::CaseSensitive) && Error.Contains(InExpected.Rule),
            f"Validate() on {InExpected.What} reports [{InExpected.Field} ... {InExpected.Rule}] (got [{Error}])");
    }
}

// Hand-authored so the deliberate rejected-spec ensure is an expected error rather than a failure.
class AMars_AutoTest_Eyes_SpecRejectsBadInput_Actor : ACk_AutoTestRunner
{
    default _TestEntityScriptClass = UMars_AutoTest_Eyes_SpecRejectsBadInput;

    UFUNCTION(BlueprintOverride)
    TArray<FString> Get_ExpectedLogErrors() const
    {
        TArray<FString> Out;
        Out.Add("rejected the spec: Style: LeftCell [32] is outside [0, 31]");
        return Out;
    }
}
