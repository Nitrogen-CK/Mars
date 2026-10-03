// A PlayExpression whose left cell is past the atlas, a PlayExpression with a NaN BlendSeconds and a SetStyle with a
// NaN EmissiveStrength each fire the request ensure and change nothing: no emote, the cells and the style stay as they
// were. Isolated Z band: -64000.
class UMars_AutoTest_Eyes_RejectsBadRequest : UCk_AutoTest_Base
{
    private FCk_Handle_Eyes _Eyes;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto FaceEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto FaceNode = utils_transform::Add(FaceEntity, FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, -64000.0)),
            ECk_Replication::DoesNotReplicate);

        auto Spec = FMars_Eyes_Spec();
        Spec.Style.LeftCell = 3;
        Spec.Style.RightCell = 3;
        _Eyes = utils_eyes::Add(FaceNode, Spec);

        Add_Step("the eyes have a presentation", n"Step_AssertPresentation");
        Add_Step("play two bad expressions (cell 32, NaN blend) and set a style with a NaN strength", n"Step_PlayBadExpression");
        Add_Step_WaitUntil("the request was drained", n"Check_RequestDrained");
        Add_Step("nothing changed", n"Step_AssertUnchanged");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AssertPresentation(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Valid(_Eyes, "Add with a valid spec returns a valid handle");
        if (_Eyes.Get_HasPresentation() == false)
        { FinishFailure("the eyes have no presentation in this world - Get_CanExecuteCosmeticEvents was false"); }
    }

    UFUNCTION()
    private void Step_PlayBadExpression(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Bad = FMars_Eyes_ExpressionDef();
        Bad.LeftCell = constants_eyes::k_CellCount;
        Bad.RightCell = 13;
        _Eyes.Request_PlayExpression(FMars_Request_Eyes_PlayExpression(Bad));

        const auto NotANumber = float32(Math::Sqrt(-1.0));

        auto NonFiniteBlend = FMars_Eyes_ExpressionDef();
        NonFiniteBlend.LeftCell = 13;
        NonFiniteBlend.RightCell = 13;
        NonFiniteBlend.BlendSeconds = NotANumber;
        _Eyes.Request_PlayExpression(FMars_Request_Eyes_PlayExpression(NonFiniteBlend));

        auto NonFiniteStyle = FMars_Eyes_StyleDef();
        NonFiniteStyle.LeftCell = 5;
        NonFiniteStyle.RightCell = 5;
        NonFiniteStyle.EmissiveStrength = NotANumber;
        _Eyes.Request_SetStyle(FMars_Request_Eyes_SetStyle(NonFiniteStyle));
    }

    UFUNCTION()
    private void Check_RequestDrained(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Eyes.Has_Fragment(FMars_Fragment_Eyes_Requests) == false);
    }

    UFUNCTION()
    private void Step_AssertUnchanged(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(_Eyes.Get_HasEmote(), "a rejected PlayExpression starts no emote");
        Assert_Equals_Int(_Eyes.Get_ResolvedLeftCell(), 3, "the left cell after the rejected request");
        Assert_Equals_Int(_Eyes.Get_ResolvedRightCell(), 3, "the right cell after the rejected request");
        Assert_Equals_Int(_Eyes.Get_Style().LeftCell, 3, "the style after the rejected requests");
        Assert_True(Math::IsFinite(_Eyes.Get_Style().EmissiveStrength), "the style strength is still finite after the rejected SetStyle");
    }
}

// Hand-authored so the deliberate rejected-request ensure is an expected error rather than a failure.
class AMars_AutoTest_Eyes_RejectsBadRequest_Actor : ACk_AutoTestRunner
{
    default _TestEntityScriptClass = UMars_AutoTest_Eyes_RejectsBadRequest;

    UFUNCTION(BlueprintOverride)
    TArray<FString> Get_ExpectedLogErrors() const
    {
        TArray<FString> Out;
        Out.Add("rejected PlayExpression: LeftCell [32] is outside [0, 31]");
        Out.Add("rejected PlayExpression: BlendSeconds [");
        Out.Add("rejected SetStyle: EmissiveStrength [");
        return Out;
    }
}
