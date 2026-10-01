// The catalog's Downed set as the State expression shows over the style; Happy played on top until cleared shows
// instead, fully blended, and clearing it returns the eyes to Downed, not to the style; Happy played as authored
// (timed) over Downed also runs out back to Downed; clearing the State layer returns the eyes to the style. Isolated Z
// band: -62000.
class UMars_AutoTest_Eyes_EmoteOverStateLayer : UCk_AutoTest_Base
{
    // The timed Happy lasts 2 s.
    default _TimeoutSeconds = 8.0f;

    // Catalog indices are append-only (Mars_Eyes_Assets.as).
    private const int32 HappyIndex = 0;
    private const int32 DownedIndex = 8;

    private FCk_Handle_Eyes _Eyes;
    private FMars_Eyes_ExpressionDef _Happy;
    private FMars_Eyes_ExpressionDef _Downed;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto FaceEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto FaceNode = utils_transform::Add(FaceEntity, FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, -62000.0)),
            ECk_Replication::DoesNotReplicate);

        auto Spec = FMars_Eyes_Spec();
        Spec.Style.LeftCell = 3;
        Spec.Style.RightCell = 3;
        Spec.BlinkEnabled = false;
        _Eyes = utils_eyes::Add(FaceNode, Spec);

        _Happy = mars_eyes::Catalog().Expressions[HappyIndex].Def;
        _Downed = mars_eyes::Catalog().Expressions[DownedIndex].Def;

        Add_Step("the eyes have a presentation", n"Step_AssertPresentation");
        Add_Step("set the State layer to Downed", n"Step_SetDowned");
        Add_Step_WaitUntil("both eyes show Downed", n"Check_DownedShown");
        Add_Step("play Happy over it until cleared", n"Step_PlayHappyUntilCleared");
        Add_Step_WaitUntil("both eyes show Happy, fully blended", n"Check_HappyShown");
        Add_Step("clear the emote", n"Step_ClearEmote");
        Add_Step_WaitUntil("both eyes show Downed again, not the style", n"Check_DownedShown");
        Add_Step("play Happy as authored (timed) over Downed", n"Step_PlayTimedHappy");
        Add_Step_WaitUntil("the timed Happy is playing", n"Check_EmotePlaying");
        Add_Step_WaitUntil("the timed Happy expired and Downed is back", n"Check_DownedShown", 0, 5.0f);
        Add_Step("clear the State layer", n"Step_ClearState");
        Add_Step_WaitUntil("both eyes show the style (3)", n"Check_StyleShown");
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

        Assert_True(_Downed.DurationSeconds <= 0.0f, "the catalog's Downed stays until cleared");
        Assert_True(_Happy.DurationSeconds >= 1.0f, f"the catalog's Happy is timed for at least 1 s (got [{_Happy.DurationSeconds}])");
        Assert_True(_Downed.LeftCell != 3 && _Downed.RightCell != 3, "Downed differs from the style on both eyes");
        Assert_True(_Happy.LeftCell != _Downed.LeftCell && _Happy.RightCell != _Downed.RightCell, "Happy differs from Downed on both eyes");
    }

    UFUNCTION()
    private void Step_SetDowned(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Eyes.Request_SetStateExpression(FMars_Request_Eyes_SetStateExpression(_Downed));
    }

    UFUNCTION()
    private void Check_DownedShown(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Eyes.Get_HasEmote() == false
            && _Eyes.Get_ResolvedLeftCell() == _Downed.LeftCell
            && _Eyes.Get_ResolvedRightCell() == _Downed.RightCell);
    }

    UFUNCTION()
    private void Step_PlayHappyUntilCleared(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto UntilCleared = _Happy;
        UntilCleared.DurationSeconds = 0.0f;
        _Eyes.Request_PlayExpression(FMars_Request_Eyes_PlayExpression(UntilCleared));
    }

    UFUNCTION()
    private void Check_HappyShown(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Eyes.Get_HasEmote()
            && _Eyes.Get_ResolvedLeftCell() == _Happy.LeftCell
            && _Eyes.Get_ResolvedRightCell() == _Happy.RightCell
            && _Eyes.Get_Blend() >= 1.0f);
    }

    UFUNCTION()
    private void Step_ClearEmote(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Eyes.Request_ClearExpression(FMars_Request_Eyes_ClearExpression(EMars_Eyes_Layer::Emote));
    }

    UFUNCTION()
    private void Step_PlayTimedHappy(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Eyes.Request_PlayExpression(FMars_Request_Eyes_PlayExpression(_Happy));
    }

    UFUNCTION()
    private void Check_EmotePlaying(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Eyes.Get_HasEmote());
    }

    UFUNCTION()
    private void Step_ClearState(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Eyes.Request_ClearExpression(FMars_Request_Eyes_ClearExpression(EMars_Eyes_Layer::State));
    }

    UFUNCTION()
    private void Check_StyleShown(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Eyes.Get_ResolvedLeftCell() == 3 && _Eyes.Get_ResolvedRightCell() == 3);
    }
}
