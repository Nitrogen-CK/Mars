// With blinking off, the catalog's Happy played until cleared overrides both cells and its crossfade completes;
// clearing it crossfades back to the style's cells. Played as authored (timed), Happy runs out on its own and the eyes
// return to the style's cells. Isolated Z band: -61000.
class UMars_AutoTest_Eyes_ExpressionOverridesThenExpires : UCk_AutoTest_Base
{
    // The timed Happy lasts 2 s.
    default _TimeoutSeconds = 8.0f;

    private FCk_Handle_Eyes _Eyes;
    private FMars_Eyes_ExpressionDef _Happy;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto FaceEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto FaceNode = utils_transform::Add(FaceEntity, FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, -61000.0)),
            ECk_Replication::DoesNotReplicate);

        auto Spec = FMars_Eyes_Spec();
        Spec.Style.LeftCell = 3;
        Spec.Style.RightCell = 3;
        _Eyes = utils_eyes::Add(FaceNode, Spec);

        _Happy = utils_eyes::Expression_Happy().Def;

        Add_Step("the eyes have a presentation and show the style", n"Step_AssertComposed");
        Add_Step("play Happy until cleared", n"Step_PlayHappyUntilCleared");
        Add_Step_WaitUntil("both eyes show Happy, fully blended", n"Check_HappyShown");
        Add_Step("clear the emote", n"Step_ClearEmote");
        Add_Step_WaitUntil("the style (3) is back, fully blended", n"Check_StyleBack");
        Add_Step("play Happy as authored (timed)", n"Step_PlayTimedHappy");
        Add_Step_WaitUntil("the timed Happy is playing", n"Check_EmotePlaying");
        Add_Step_WaitUntil("the timed Happy expired and the style (3) is back, fully blended", n"Check_StyleBack", 0, 5.0f);
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AssertComposed(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Valid(_Eyes, "Add with a valid spec returns a valid handle");
        if (_Eyes.Get_HasPresentation() == false)
        {
            FinishFailure("the eyes have no presentation in this world - Get_CanExecuteCosmeticEvents was false");
            return;
        }

        Assert_Equals_Int(_Eyes.Get_ResolvedLeftCell(), 3, "the left cell after Add");
        Assert_Equals_Int(_Eyes.Get_ResolvedRightCell(), 3, "the right cell after Add");
        Assert_True(_Happy.DurationSeconds.IsSet() && _Happy.DurationSeconds.GetValue() >= 1.0f,
            f"the catalog's Happy is timed for at least 1 s (set [{_Happy.DurationSeconds.IsSet()}], got [{_Happy.DurationSeconds.Get(0.0f)}])");
    }

    UFUNCTION()
    private void Step_PlayHappyUntilCleared(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto UntilCleared = _Happy;
        UntilCleared.DurationSeconds.Reset();
        _Eyes.Request_PlayExpression(FMars_Request_Eyes_PlayExpression(UntilCleared));
    }

    UFUNCTION()
    private void Check_HappyShown(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Eyes.Get_HasEmote()
            && _Eyes.Get_ResolvedLeftCell() == _Happy.LeftCell.Get(-1)
            && _Eyes.Get_ResolvedRightCell() == _Happy.RightCell.Get(-1)
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
    private void Check_StyleBack(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Eyes.Get_HasEmote() == false
            && _Eyes.Get_ResolvedLeftCell() == 3
            && _Eyes.Get_ResolvedRightCell() == 3
            && _Eyes.Get_Blend() >= 1.0f);
    }
}
