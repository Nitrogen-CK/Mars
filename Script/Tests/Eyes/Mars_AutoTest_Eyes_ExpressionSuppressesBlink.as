// With a fixed 0.6 s blink interval and every blink followed by a double blink, the eyes are blinking; an expression
// with AllowBlink = false played right after a first blink (its double blink pending) keeps them fully open and the
// blink count still over a window that would otherwise hold two blinks. Once it is cleared the pending double blink is
// gone: the next blink completes no sooner than a full interval later. Isolated Z band: -66000.
class UMars_AutoTest_Eyes_ExpressionSuppressesBlink : UCk_AutoTest_Base
{
    default _TimeoutSeconds = 8.0f;

    private FCk_Handle_Eyes _Eyes;

    private float32 _IntervalSeconds = 0.6f;

    // Unsuppressed, the pending double blink (0.18 s gap + 0.23 s blink) and the next single one (0.6 s + 0.23 s) both
    // complete inside it.
    private float _WindowSeconds = 1.5;

    // Frame quantisation of the clear request and of the poll that sees the blink complete.
    private float _ResumeToleranceSeconds = 0.05;

    private int32 _CountAtSuppress = 0;
    private float _WindowStartSeconds = 0.0;
    private bool _BlinkSeenWhileSuppressed = false;

    private int32 _CountAtClear = 0;
    private float _ClearedAtSeconds = 0.0;
    private float _ResumedAtSeconds = 0.0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto FaceEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto FaceNode = utils_transform::Add(FaceEntity, FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, -66000.0)),
            ECk_Replication::DoesNotReplicate);

        auto Spec = FMars_Eyes_Spec();
        Spec.Style.LeftCell = 3;
        Spec.Style.RightCell = 3;
        Spec.BlinkIntervalMinSeconds = _IntervalSeconds;
        Spec.BlinkIntervalMaxSeconds = _IntervalSeconds;
        Spec.DoubleBlinkChance = 1.0f;
        _Eyes = utils_eyes::Add(FaceNode, Spec);

        Add_Step("the eyes have a presentation", n"Step_AssertPresentation");
        Add_Step_WaitUntil("the eyes completed a blink (a double blink is now pending)", n"Check_Blinked");
        Add_Step("play an expression that forbids blinking, until cleared", n"Step_PlayNoBlink");
        Add_Step_WaitUntil("the expression shows (15) and the eyes are open", n"Check_SuppressedAndOpen");
        Add_Step_WaitUntil("a window that would hold two blinks passed, sampling every poll", n"Check_WindowPassed", 0, 3.0f);
        Add_Step("the eyes stayed open and the blink count did not move", n"Step_AssertSuppressed");
        Add_Step("clear the expression", n"Step_ClearNoBlink");
        Add_Step_WaitUntil("the eyes completed a blink again", n"Check_Resumed", 0, 3.0f);
        Add_Step("the first blink after the expression came no sooner than a full interval", n"Step_AssertNoOrphanBlink");
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
    private void Check_Blinked(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Eyes.Get_BlinkCount() >= 1);
    }

    UFUNCTION()
    private void Step_PlayNoBlink(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Squeeze = FMars_Eyes_ExpressionDef();
        Squeeze.LeftCell = 15;
        Squeeze.RightCell = 15;
        Squeeze.AllowBlink = false;
        _Eyes.Request_PlayExpression(FMars_Request_Eyes_PlayExpression(Squeeze));
    }

    // A blink cut short by the expression leaves the count where it was, so the count is taken once the eyes are open.
    UFUNCTION()
    private void Check_SuppressedAndOpen(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Ready = _Eyes.Get_HasEmote()
            && _Eyes.Get_ResolvedLeftCell() == 15
            && _Eyes.Get_ResolvedRightCell() == 15
            && _Eyes.Get_Blink() <= 0.0f;

        if (Ready)
        {
            _CountAtSuppress = _Eyes.Get_BlinkCount();
            _WindowStartSeconds = System::GetGameTimeInSeconds();
        }

        auto Res = OutResult;
        Res.Set(Ready);
    }

    UFUNCTION()
    private void Check_WindowPassed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        if (_Eyes.Get_Blink() > 0.0f || _Eyes.Get_BlinkCount() != _CountAtSuppress)
        { _BlinkSeenWhileSuppressed = true; }

        auto Res = OutResult;
        Res.Set(System::GetGameTimeInSeconds() - _WindowStartSeconds >= _WindowSeconds);
    }

    UFUNCTION()
    private void Step_AssertSuppressed(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(_BlinkSeenWhileSuppressed, "a blink was seen while the expression forbade blinking");
        Assert_Equals_Int(_Eyes.Get_BlinkCount(), _CountAtSuppress, "the blink count after the suppressed window");
        Assert_True(_Eyes.Get_HasEmote(), "the until-cleared expression is still active");
    }

    UFUNCTION()
    private void Step_ClearNoBlink(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _CountAtClear = _Eyes.Get_BlinkCount();
        _ClearedAtSeconds = System::GetGameTimeInSeconds();
        _Eyes.Request_ClearExpression(FMars_Request_Eyes_ClearExpression(EMars_Eyes_Layer::Emote));
    }

    UFUNCTION()
    private void Check_Resumed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Resumed = _Eyes.Get_BlinkCount() > _CountAtClear;
        if (Resumed)
        { _ResumedAtSeconds = System::GetGameTimeInSeconds(); }

        auto Res = OutResult;
        Res.Set(Resumed);
    }

    UFUNCTION()
    private void Step_AssertNoOrphanBlink(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Elapsed = _ResumedAtSeconds - _ClearedAtSeconds;
        Assert_True(Elapsed >= _IntervalSeconds - _ResumeToleranceSeconds,
            f"the first blink after the expression completed [{Elapsed :.3}] s after it was cleared - at least the [{_IntervalSeconds}] s interval");
    }
}
