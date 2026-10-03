// Each eye resolves its own layer: with the catalog's Downed as the State expression, the catalog's Wink (which
// overrides only the right eye) played on top changes the right eye and leaves the left eye on Downed - not on the
// style; clearing the emote puts both eyes back on Downed. Isolated Z band: -72000.
class UMars_AutoTest_Eyes_OneEyeEmoteKeepsStateOnOtherEye : UCk_AutoTest_Base
{
    private FCk_Handle_Eyes _Eyes;
    private FMars_Eyes_ExpressionDef _Wink;
    private FMars_Eyes_ExpressionDef _Downed;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto FaceEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto FaceNode = utils_transform::Add(FaceEntity, FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, -72000.0)),
            ECk_Replication::DoesNotReplicate);

        auto Spec = FMars_Eyes_Spec();
        Spec.Style.LeftCell = 3;
        Spec.Style.RightCell = 3;
        _Eyes = utils_eyes::Add(FaceNode, Spec);

        _Wink = utils_eyes::Expression_Wink().Def;
        _Downed = utils_eyes::Expression_Downed().Def;

        Add_Step("the eyes have a presentation", n"Step_AssertPresentation");
        Add_Step("set the State layer to Downed", n"Step_SetDowned");
        Add_Step_WaitUntil("both eyes show Downed", n"Check_DownedOnBoth");
        Add_Step("play the wink (right eye only) until cleared", n"Step_PlayWink");
        Add_Step_WaitUntil("the right eye shows the wink", n"Check_RightWinked");
        Add_Step("the left eye kept Downed, not the style", n"Step_AssertLeftOnDowned");
        Add_Step("clear the emote", n"Step_ClearEmote");
        Add_Step_WaitUntil("both eyes show Downed again", n"Check_DownedOnBoth");
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

        Assert_False(_Wink.LeftCell.IsSet(), "the catalog's Wink keeps the left eye");
        Assert_True(_Wink.RightCell.IsSet() && _Wink.RightCell != _Downed.RightCell, "the catalog's Wink changes the right eye away from Downed");
        Assert_True(_Downed.LeftCell.Get(3) != 3 && _Downed.RightCell.Get(3) != 3, "Downed sets both eyes away from the style");
    }

    UFUNCTION()
    private void Step_SetDowned(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Eyes.Request_SetStateExpression(FMars_Request_Eyes_SetStateExpression(_Downed));
    }

    UFUNCTION()
    private void Check_DownedOnBoth(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Eyes.Get_HasEmote() == false
            && _Eyes.Get_ResolvedLeftCell() == _Downed.LeftCell.Get(-1)
            && _Eyes.Get_ResolvedRightCell() == _Downed.RightCell.Get(-1));
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
        Res.Set(_Eyes.Get_HasEmote() && _Eyes.Get_ResolvedRightCell() == _Wink.RightCell.Get(-1));
    }

    UFUNCTION()
    private void Step_AssertLeftOnDowned(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Eyes.Get_ResolvedLeftCell(), _Downed.LeftCell.Get(-1), "the left cell while winking over Downed");
        Assert_Equals_Int(_Eyes.Get_ResolvedRightCell(), _Wink.RightCell.Get(-1), "the right cell while winking over Downed");
    }

    UFUNCTION()
    private void Step_ClearEmote(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Eyes.Request_ClearExpression(FMars_Request_Eyes_ClearExpression(EMars_Eyes_Layer::Emote));
    }
}
