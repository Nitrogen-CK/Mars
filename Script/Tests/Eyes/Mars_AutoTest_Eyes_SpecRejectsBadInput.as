// FMars_Eyes_Spec::Validate() (and the expression def's) rejects each bad input with its own message, the default spec
// passes, and a rejected utils_eyes::Add returns an invalid handle without adding any eyes fragment. Isolated Z band:
// -60000.
class UMars_AutoTest_Eyes_SpecRejectsBadInput : UCk_AutoTest_Base
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
        Assert_True(Validation.IsValid, f"Validate() on the default spec (got [{Validation.Get_Error()}])");
    }

    UFUNCTION()
    private void Step_AssertEachRuleRejects(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Spec = FMars_Eyes_Spec();
        Spec.Style.LeftCell = constants_eyes::k_CellCount;
        AssertRejected(Spec, "Style: LeftCell [32]", "is outside [0, 31]", "a style left cell past the atlas");

        Spec = FMars_Eyes_Spec();
        Spec.Style.RightCell = -1;
        AssertRejected(Spec, "Style: RightCell [-1]", "is outside [0, 31]", "a negative style right cell");

        Spec = FMars_Eyes_Spec();
        Spec.BlinkIntervalMinSeconds = -1.0f;
        AssertRejected(Spec, "BlinkIntervalMinSeconds", "is negative", "a negative interval min");

        Spec = FMars_Eyes_Spec();
        Spec.BlinkIntervalMaxSeconds = -1.0f;
        AssertRejected(Spec, "BlinkIntervalMaxSeconds", "is negative", "a negative interval max");

        Spec = FMars_Eyes_Spec();
        Spec.BlinkCloseSeconds = -0.1f;
        AssertRejected(Spec, "BlinkCloseSeconds", "is negative", "a negative close duration");

        Spec = FMars_Eyes_Spec();
        Spec.BlinkHoldSeconds = -0.1f;
        AssertRejected(Spec, "BlinkHoldSeconds", "is negative", "a negative hold duration");

        Spec = FMars_Eyes_Spec();
        Spec.BlinkOpenSeconds = -0.1f;
        AssertRejected(Spec, "BlinkOpenSeconds", "is negative", "a negative open duration");

        Spec = FMars_Eyes_Spec();
        Spec.BlinkIntervalMinSeconds = 4.0f;
        Spec.BlinkIntervalMaxSeconds = 3.0f;
        AssertRejected(Spec, "BlinkIntervalMinSeconds", "exceeds BlinkIntervalMaxSeconds", "an interval min above its max");

        Spec = FMars_Eyes_Spec();
        Spec.BlinkIntervalMinSeconds = 0.0f;
        AssertRejected(Spec, "BlinkIntervalMinSeconds", "must be > 0 while BlinkEnabled", "a zero interval min while blinking");

        Spec = FMars_Eyes_Spec();
        Spec.BlinkEnabled = false;
        Spec.BlinkIntervalMinSeconds = 0.0f;
        const auto NoBlinkValidation = Spec.Validate();
        Assert_True(NoBlinkValidation.IsValid,
            f"a zero interval min is fine while blinking is disabled (got [{NoBlinkValidation.Get_Error()}])");

        Spec = FMars_Eyes_Spec();
        Spec.DoubleBlinkChance = 1.5f;
        AssertRejected(Spec, "DoubleBlinkChance", "is outside [0, 1]", "a double-blink chance above 1");

        Spec = FMars_Eyes_Spec();
        Spec.DoubleBlinkChance = -0.5f;
        AssertRejected(Spec, "DoubleBlinkChance", "is outside [0, 1]", "a negative double-blink chance");

        Spec = FMars_Eyes_Spec();
        Spec.LookMaxYawDeg = 0.0f;
        AssertRejected(Spec, "LookMaxYawDeg", "must be > 0", "a zero max yaw");

        Spec = FMars_Eyes_Spec();
        Spec.LookMaxPitchDeg = -10.0f;
        AssertRejected(Spec, "LookMaxPitchDeg", "must be > 0", "a negative max pitch");

        Spec = FMars_Eyes_Spec();
        Spec.LookInterpSpeed = 0.0f;
        AssertRejected(Spec, "LookInterpSpeed", "must be > 0", "a zero look interp speed");

        const auto NotANumber = float32(Math::Sqrt(-1.0));
        Assert_True(Math::IsNaN(NotANumber), "the test input is NaN");

        Spec = FMars_Eyes_Spec();
        Spec.Style.EmissiveStrength = NotANumber;
        AssertRejected(Spec, "Style: EmissiveStrength", "is not finite", "a NaN style emissive strength");

        Spec = FMars_Eyes_Spec();
        Spec.Style.EmissiveStrength = -1.0f;
        AssertRejected(Spec, "Style: EmissiveStrength", "is negative", "a negative style emissive strength");

        Spec = FMars_Eyes_Spec();
        Spec.Style.Color.G = NotANumber;
        AssertRejected(Spec, "Style: Color", "has a channel that is not finite", "a NaN style color channel");

        Spec = FMars_Eyes_Spec();
        Spec.Style.Color.B = -0.5f;
        AssertRejected(Spec, "Style: Color", "has a negative channel", "a negative style color channel");

        Spec = FMars_Eyes_Spec();
        Spec.BlinkIntervalMinSeconds = NotANumber;
        AssertRejected(Spec, "BlinkIntervalMinSeconds", "is not finite", "a NaN interval min");

        Spec = FMars_Eyes_Spec();
        Spec.BlinkIntervalMaxSeconds = NotANumber;
        AssertRejected(Spec, "BlinkIntervalMaxSeconds", "is not finite", "a NaN interval max");

        Spec = FMars_Eyes_Spec();
        Spec.BlinkCloseSeconds = NotANumber;
        AssertRejected(Spec, "BlinkCloseSeconds", "is not finite", "a NaN close duration");

        Spec = FMars_Eyes_Spec();
        Spec.BlinkHoldSeconds = NotANumber;
        AssertRejected(Spec, "BlinkHoldSeconds", "is not finite", "a NaN hold duration");

        Spec = FMars_Eyes_Spec();
        Spec.BlinkOpenSeconds = NotANumber;
        AssertRejected(Spec, "BlinkOpenSeconds", "is not finite", "a NaN open duration");

        Spec = FMars_Eyes_Spec();
        Spec.DoubleBlinkChance = NotANumber;
        AssertRejected(Spec, "DoubleBlinkChance", "is not finite", "a NaN double-blink chance");

        Spec = FMars_Eyes_Spec();
        Spec.LookMaxYawDeg = NotANumber;
        AssertRejected(Spec, "LookMaxYawDeg", "is not finite", "a NaN max yaw");

        Spec = FMars_Eyes_Spec();
        Spec.LookMaxPitchDeg = NotANumber;
        AssertRejected(Spec, "LookMaxPitchDeg", "is not finite", "a NaN max pitch");

        Spec = FMars_Eyes_Spec();
        Spec.LookInterpSpeed = NotANumber;
        AssertRejected(Spec, "LookInterpSpeed", "is not finite", "a NaN look interp speed");

        auto Expression = FMars_Eyes_ExpressionDef();
        Expression.DurationSeconds = NotANumber;
        AssertExpressionRejected(Expression, "DurationSeconds", "is not finite", "a NaN expression duration");

        Expression = FMars_Eyes_ExpressionDef();
        Expression.BlendSeconds = NotANumber;
        AssertExpressionRejected(Expression, "BlendSeconds", "is not finite", "a NaN expression blend time");
    }

    UFUNCTION()
    private void Step_AssertAddRejected(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto FaceEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto FaceNode = utils_transform::Add(FaceEntity, FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, -60000.0)),
            ECk_Replication::DoesNotReplicate);

        auto Spec = FMars_Eyes_Spec();
        Spec.Style.LeftCell = constants_eyes::k_CellCount;

        auto Rejected = utils_eyes::Add(FaceNode, Spec);
        Assert_Invalid(Rejected, "Add with a style cell past the atlas returns an invalid handle");
        Assert_False(utils_eyes::Has(FaceEntity), "a rejected spec adds no feature fragment");
        Assert_False(FaceEntity.Has_Fragment(FMars_Fragment_Eyes_Params), "a rejected spec adds no params fragment");
        Assert_False(FaceEntity.Has_Fragment(FMars_Fragment_Eyes), "a rejected spec adds no logic fragment");
        Assert_False(FaceEntity.Has_Fragment(FMars_Fragment_Eyes_Presentation), "a rejected spec adds no presentation fragment");
    }

    // The message names the offending field first, then the rule it broke.
    private void AssertRejected(const FMars_Eyes_Spec& InSpec, const FString& InField, const FString& InRule, const FString& InWhat)
    {
        const auto Validation = InSpec.Validate();
        const auto Error = Validation.Get_Error();
        Assert_False(Validation.IsValid, f"Validate() on {InWhat}");
        Assert_True(Error.StartsWith(InField, ESearchCase::CaseSensitive) && Error.Contains(InRule),
            f"Validate() on {InWhat} reports [{InField} ... {InRule}] (got [{Error}])");
    }

    private void AssertExpressionRejected(const FMars_Eyes_ExpressionDef& InExpression, const FString& InField, const FString& InRule, const FString& InWhat)
    {
        const auto Validation = InExpression.Validate();
        const auto Error = Validation.Get_Error();
        Assert_False(Validation.IsValid, f"Validate() on {InWhat}");
        Assert_True(Error.StartsWith(InField, ESearchCase::CaseSensitive) && Error.Contains(InRule),
            f"Validate() on {InWhat} reports [{InField} ... {InRule}] (got [{Error}])");
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
