// Blinking needs every active layer to allow it: with a no-blink State expression set and a blink-allowing emote played
// on top, the eyes stay open and the blink count stays still over a window that would otherwise hold two blinks; once
// the State layer is cleared (the emote still playing) the eyes blink again. Isolated Z band: -74000.
class UMars_AutoTest_Eyes_StateSuppressesBlinkUnderEmote : UMars_AutoTestRig_Eyes
{
    default _TimeoutSeconds = 6.0f;

    // Two 0.43 s blink cycles (0.2 s wait + 0.07 close + 0.04 hold + 0.12 open) fit inside it.
    private float _WindowSeconds = 1.0;

    private int32 _CountAtSuppress = 0;
    private float _WindowStartSeconds = 0.0;
    private bool _BlinkSeenWhileSuppressed = false;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto FaceNode = Make_FaceNode(InHandle, FVector(0.0, 0.0, -74000.0));

        auto Spec = FMars_Eyes_Spec();
        Spec.Style.LeftCell = 3;
        Spec.Style.RightCell = 3;
        auto Blink = FMars_Eyes_BlinkSpec();
        Blink.IntervalMinSeconds = 0.2f;
        Blink.IntervalMaxSeconds = 0.2f;
        Blink.DoubleBlinkChance = 0.0f;
        Spec.Blink = Blink;
        _Eyes = utils_eyes::Add(FaceNode, Spec);

        Add_Step("the eyes have a presentation", n"Step_AssertPresentation");
        Add_Step("set a no-blink State (20) and play a blink-allowing emote (13) over it, until cleared", n"Step_SetLayers");
        Add_Step_WaitUntil("the emote shows and the eyes are open", n"Check_EmoteShownAndOpen");
        Add_Step_WaitUntil("a window that would hold two blinks passed, sampling every poll", n"Check_WindowPassed");
        Add_Step("the eyes stayed open and the blink count did not move", n"Step_AssertSuppressed");
        Add_Step("clear the State layer", n"Step_ClearState");
        Add_Step_WaitUntil("the eyes blink again under the emote", n"Check_BlinkResumed");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_SetLayers(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto NoBlinkState = FMars_Eyes_ExpressionDef();
        NoBlinkState.LeftCell = 20;
        NoBlinkState.RightCell = 20;
        NoBlinkState.AllowBlink = false;
        _Eyes.Request_SetStateExpression(FMars_Request_Eyes_SetStateExpression(NoBlinkState));

        auto BlinkingEmote = FMars_Eyes_ExpressionDef();
        BlinkingEmote.LeftCell = 13;
        BlinkingEmote.RightCell = 13;
        BlinkingEmote.AllowBlink = true;
        _Eyes.Request_PlayExpression(FMars_Request_Eyes_PlayExpression(BlinkingEmote));
    }

    // A blink cut short by the state leaves the count where it was, so the count is taken once the eyes are open.
    UFUNCTION()
    private void Check_EmoteShownAndOpen(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Ready = _Eyes.Get_HasEmote()
            && _Eyes.Get_ResolvedLeftCell() == 13
            && _Eyes.Get_ResolvedRightCell() == 13
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
        Assert_False(_BlinkSeenWhileSuppressed, "a blink was seen while the State expression forbade blinking");
        Assert_Equals_Int(_Eyes.Get_BlinkCount(), _CountAtSuppress, "the blink count after the suppressed window");
        Assert_True(_Eyes.Get_HasEmote(), "the until-cleared emote is still active");
    }

    UFUNCTION()
    private void Check_BlinkResumed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Eyes.Get_HasEmote() && _Eyes.Get_BlinkCount() > _CountAtSuppress);
    }
}
