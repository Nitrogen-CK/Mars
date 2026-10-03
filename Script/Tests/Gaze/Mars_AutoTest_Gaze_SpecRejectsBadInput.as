// FMars_Gaze_Spec::Validate rejects each bad field with its own message and accepts the edge values, and a rejected
// utils_gaze::Add returns an invalid handle without adding a fragment or a child node to the eye node. Isolated Z band:
// -55000.
class UMars_AutoTest_Gaze_SpecRejectsBadInput : UCk_AutoTest_Base
{
    private FCk_Handle_Transform _EyeNode;
    private int32 _DependentsBeforeAdd = 0;
    private FCk_Handle_Gaze _Rejected;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto EyeEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        _EyeNode = utils_transform::Add(EyeEntity, FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, -55000.0)),
            ECk_Replication::DoesNotReplicate);

        Add_Step("each bad field fails Validate() with its own message", n"Step_AssertRules");
        Add_Step("the edge values pass Validate()", n"Step_AssertEdgesValid");
        Add_Step("add a spec with an empty DetectionFilter", n"Step_AddRejected");
        Add_Step("the rejected Add left the eye node untouched", n"Step_AssertNothingAdded");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AssertRules(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto EmptyFilter = MakeSpec();
        EmptyFilter.DetectionFilter = FGameplayTagContainer();
        AssertRejected(EmptyFilter, "DetectionFilter is empty", "an empty DetectionFilter");

        auto NoAimPoint = MakeSpec();
        NoAimPoint.AimPoint = FGameplayTag();
        AssertRejected(NoAimPoint, "AimPoint has no tag", "an invalid AimPoint");

        auto NegativeMinRange = MakeSpec();
        NegativeMinRange.MinRangeCm = -1.0f;
        AssertRejected(NegativeMinRange, "is negative", "a negative MinRangeCm");

        auto RangeAtMinRange = MakeSpec();
        RangeAtMinRange.RangeCm = 20.0f;
        RangeAtMinRange.MinRangeCm = 20.0f;
        AssertRejected(RangeAtMinRange, "does not exceed MinRangeCm", "RangeCm equal to MinRangeCm");

        auto ZeroCone = MakeSpec();
        ZeroCone.ConeHalfAngleDeg = 0.0f;
        AssertRejected(ZeroCone, "ConeHalfAngleDeg", "a zero ConeHalfAngleDeg");

        auto WideCone = MakeSpec();
        WideCone.ConeHalfAngleDeg = 181.0f;
        AssertRejected(WideCone, "ConeHalfAngleDeg", "a ConeHalfAngleDeg over 180");

        auto NegativeRatio = MakeSpec();
        NegativeRatio.SwitchCloserRatio = -0.1f;
        AssertRejected(NegativeRatio, "SwitchCloserRatio", "a negative SwitchCloserRatio");

        auto WholeRatio = MakeSpec();
        WholeRatio.SwitchCloserRatio = 1.0f;
        AssertRejected(WholeRatio, "SwitchCloserRatio", "a SwitchCloserRatio of 1");

        const auto NotANumber = float32(Math::Sqrt(-1.0));
        Assert_True(Math::IsNaN(NotANumber), "the test input is NaN");

        auto NaNRange = MakeSpec();
        NaNRange.RangeCm = NotANumber;
        AssertNotFiniteRejected(NaNRange, "RangeCm", "a NaN RangeCm");

        auto NaNMinRange = MakeSpec();
        NaNMinRange.MinRangeCm = NotANumber;
        AssertNotFiniteRejected(NaNMinRange, "MinRangeCm", "a NaN MinRangeCm");

        auto NaNCone = MakeSpec();
        NaNCone.ConeHalfAngleDeg = NotANumber;
        AssertNotFiniteRejected(NaNCone, "ConeHalfAngleDeg", "a NaN ConeHalfAngleDeg");

        auto NaNRatio = MakeSpec();
        NaNRatio.SwitchCloserRatio = NotANumber;
        AssertNotFiniteRejected(NaNRatio, "SwitchCloserRatio", "a NaN SwitchCloserRatio");
    }

    UFUNCTION()
    private void Step_AssertEdgesValid(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Defaults = MakeSpec().Validate();
        Assert_True(Defaults.IsValid(), f"Validate() on the default spec with a filter and an aim point (got [{Defaults.Get_Error()}])");

        auto Edges = MakeSpec();
        Edges.MinRangeCm = 0.0f;
        Edges.ConeHalfAngleDeg = 180.0f;
        Edges.SwitchCloserRatio = 0.0f;
        const auto EdgesValidation = Edges.Validate();
        Assert_True(EdgesValidation.IsValid(),
            f"Validate() on MinRangeCm 0, ConeHalfAngleDeg 180, SwitchCloserRatio 0 (got [{EdgesValidation.Get_Error()}])");
    }

    UFUNCTION()
    private void Step_AddRejected(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _DependentsBeforeAdd = utils_entity_lifetime::Get_LifetimeDependents(_EyeNode).Num();

        auto Spec = MakeSpec();
        Spec.DetectionFilter = FGameplayTagContainer();
        _Rejected = utils_gaze::Add(_EyeNode, Spec);
    }

    UFUNCTION()
    private void Step_AssertNothingAdded(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Invalid(_Rejected, "Add with an empty DetectionFilter returns an invalid handle");
        Assert_False(_EyeNode.Is_Gaze(), "a rejected spec adds no feature fragment");
        Assert_False(_EyeNode.Has_Fragment(FMars_Fragment_Gaze_Params), "a rejected spec adds no params fragment");
        Assert_False(_EyeNode.Has_Fragment(FMars_Fragment_Gaze), "a rejected spec adds no state fragment");
        Assert_Equals_Int(utils_entity_lifetime::Get_LifetimeDependents(_EyeNode).Num(), _DependentsBeforeAdd,
            "a rejected spec creates no sense node under the eye node");
    }

    private void AssertRejected(const FMars_Gaze_Spec& InSpec, const FString& InExpectedError, const FString& InWhat)
    {
        const auto Validation = InSpec.Validate();
        Assert_False(Validation.IsValid(), f"Validate() rejects {InWhat}");
        Assert_True(Validation.Get_Error().Contains(InExpectedError),
            f"Validate() on {InWhat} says [{InExpectedError}] (got [{Validation.Get_Error()}])");
    }

    // The message names the offending field first, then says it is not finite.
    private void AssertNotFiniteRejected(const FMars_Gaze_Spec& InSpec, const FString& InField, const FString& InWhat)
    {
        const auto Validation = InSpec.Validate();
        const auto Error = Validation.Get_Error();
        Assert_False(Validation.IsValid(), f"Validate() rejects {InWhat}");
        Assert_True(Error.StartsWith(InField, ESearchCase::CaseSensitive) && Error.Contains("is not finite"),
            f"Validate() on {InWhat} reports [{InField} ... is not finite] (got [{Error}])");
    }

    private FMars_Gaze_Spec MakeSpec() const
    {
        auto Spec = FMars_Gaze_Spec();
        Spec.DetectionFilter.AddTag(GameplayTags::Probe_Mars_Player);
        Spec.AimPoint = GameplayTags::AttachPoint_Mars_Head;
        Spec.RangeCm = 300.0f;
        return Spec;
    }
}

// Hand-authored so the deliberate empty-filter ensure is an expected error rather than a failure.
class AMars_AutoTest_Gaze_SpecRejectsBadInput_Actor : ACk_AutoTestRunner
{
    default _TestEntityScriptClass = UMars_AutoTest_Gaze_SpecRejectsBadInput;

    UFUNCTION(BlueprintOverride)
    TArray<FString> Get_ExpectedLogErrors() const
    {
        TArray<FString> Out;
        Out.Add("rejected the spec: DetectionFilter is empty - an empty filter detects every probe");
        return Out;
    }
}
