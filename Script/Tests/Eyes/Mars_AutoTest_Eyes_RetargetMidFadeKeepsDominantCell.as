// A change of cells that lands while a crossfade is still mostly showing the previous cells fades from those previous
// cells, not from the in-flight destination: from the style (3) toward A (13) over 1 s, B (16) played while Blend is
// still between 0.1 and 0.4 makes the previous cells 3 again, so nothing on screen jumps. Isolated Z band: -73000.
class UMars_AutoTest_Eyes_RetargetMidFadeKeepsDominantCell : UCk_AutoTest_Base
{
    private FCk_Handle_Eyes _Eyes;

    private float32 _BlendSeconds = 1.0f;
    private float32 _BlendAtRetarget = -1.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto FaceEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto FaceNode = utils_transform::Add(FaceEntity, FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, -73000.0)),
            ECk_Replication::DoesNotReplicate);

        auto Spec = FMars_Eyes_Spec();
        Spec.Style.LeftCell = 3;
        Spec.Style.RightCell = 3;
        Spec.BlinkEnabled = false;
        _Eyes = utils_eyes::Add(FaceNode, Spec);

        Add_Step("the eyes have a presentation and show the style", n"Step_AssertComposed");
        Add_Step("play A (13) until cleared with a 1 s crossfade", n"Step_PlayA");
        Add_Step_WaitUntil("the fade toward A is between 0.1 and 0.4, then play B (16)", n"Check_MidFadeThenPlayB");
        Add_Step_WaitUntil("the eyes resolve to B", n"Check_BResolved");
        Add_Step("the fade toward B starts from the style's cells, not from A", n"Step_AssertFadesFromStyle");
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
    }

    UFUNCTION()
    private void Step_PlayA(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Eyes.Request_PlayExpression(FMars_Request_Eyes_PlayExpression(MakeExpression(13)));
    }

    // B is requested from inside the poll that sees the fade in range, so the moment cannot be skipped by a step
    // change.
    UFUNCTION()
    private void Check_MidFadeThenPlayB(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Blend = _Eyes.Get_Blend();
        const auto InRange = _Eyes.Get_ResolvedLeftCell() == 13
            && _Eyes.Get_ResolvedRightCell() == 13
            && Blend >= 0.1f
            && Blend <= 0.4f;

        if (InRange)
        {
            _BlendAtRetarget = Blend;
            _Eyes.Request_PlayExpression(FMars_Request_Eyes_PlayExpression(MakeExpression(16)));
        }

        auto Res = OutResult;
        Res.Set(InRange);
    }

    UFUNCTION()
    private void Check_BResolved(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Eyes.Get_ResolvedLeftCell() == 16 && _Eyes.Get_ResolvedRightCell() == 16);
    }

    UFUNCTION()
    private void Step_AssertFadesFromStyle(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Eyes.Get_PreviousLeftCell(), 3,
            f"the previous left cell after B was played at Blend [{_BlendAtRetarget}]");
        Assert_Equals_Int(_Eyes.Get_PreviousRightCell(), 3,
            f"the previous right cell after B was played at Blend [{_BlendAtRetarget}]");
        Assert_True(_Eyes.Get_Blend() < 0.5f, f"the fade toward B restarted (Blend [{_Eyes.Get_Blend()}])");
    }

    private FMars_Eyes_ExpressionDef MakeExpression(int32 InCell) const
    {
        auto Expression = FMars_Eyes_ExpressionDef();
        Expression.LeftCell = InCell;
        Expression.RightCell = InCell;
        Expression.AllowBlink = false;
        Expression.BlendSeconds = _BlendSeconds;
        return Expression;
    }
}
