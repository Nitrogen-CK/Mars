// The catalog's Wink overrides only the right eye: played until cleared, it changes the right cell and leaves the left
// eye on the style's cell. Isolated Z band: -63000.
class UMars_AutoTest_Eyes_WinkKeepsOneEye : UCk_AutoTest_Base
{
    // Catalog indices are append-only (Mars_Eyes_Assets.as).
    private const int32 WinkIndex = 1;

    private FCk_Handle_Eyes _Eyes;
    private FMars_Eyes_ExpressionDef _Wink;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto FaceEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto FaceNode = utils_transform::Add(FaceEntity, FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, -63000.0)),
            ECk_Replication::DoesNotReplicate);

        auto Spec = FMars_Eyes_Spec();
        Spec.Style.LeftCell = 3;
        Spec.Style.RightCell = 3;
        Spec.BlinkEnabled = false;
        _Eyes = utils_eyes::Add(FaceNode, Spec);

        _Wink = mars_eyes::Catalog().Expressions[WinkIndex].Def;

        Add_Step("the eyes have a presentation", n"Step_AssertPresentation");
        Add_Step("play the wink (right eye only) until cleared", n"Step_PlayWink");
        Add_Step_WaitUntil("the right eye shows the wink", n"Check_RightWinked");
        Add_Step("the left eye kept the style's cell (3)", n"Step_AssertLeftKept");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AssertPresentation(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Valid(_Eyes, "Add with a valid spec returns a valid handle");
        if (_Eyes.Get_HasPresentation() == false)
        {
            FinishFailure("the eyes have no presentation in this world - Get_CanExecuteCosmeticEvents was false");
            return;
        }

        Assert_False(_Wink.OverrideLeft, "the catalog's Wink keeps the left eye");
        Assert_True(_Wink.OverrideRight && _Wink.RightCell != 3, "the catalog's Wink changes the right eye away from the style");
    }

    UFUNCTION()
    private void Step_PlayWink(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto UntilCleared = _Wink;
        UntilCleared.DurationSeconds.Reset();
        _Eyes.Request_PlayExpression(FMars_Request_Eyes_PlayExpression(UntilCleared));
    }

    UFUNCTION()
    private void Check_RightWinked(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Eyes.Get_HasEmote() && _Eyes.Get_ResolvedRightCell() == _Wink.RightCell);
    }

    UFUNCTION()
    private void Step_AssertLeftKept(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Eyes.Get_ResolvedLeftCell(), 3, "the left cell while winking");
        Assert_Equals_Int(_Eyes.Get_ResolvedRightCell(), _Wink.RightCell, "the right cell while winking");
    }
}
