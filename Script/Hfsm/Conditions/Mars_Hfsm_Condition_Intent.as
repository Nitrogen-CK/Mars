// CkIntent consumers. Polled on purpose - the matcher's poll surface is the authority (its signals
// are presentation), and polling tolerates the matcher arriving after the condition entered.

// True while the intent's level row is Active (the button is held and reaching the gameplay layer).
class UMars_SmCondition_IntentActive : UCk_SmCondition_Polled
{
    protected FGameplayTag IntentTag;

    private FCk_Handle_InputIntents _Intents;

    UFUNCTION(BlueprintOverride)
    void DoEnterCondition(FCk_Handle_SmCondition InHandle, ECk_Sm_NetContext InNetContext)
    {
        _Intents = ck::Ctx(InHandle).As_InputIntents();
    }

    UFUNCTION(BlueprintOverride)
    bool DoEvaluate(FCk_Handle_SmCondition InHandle, FCk_Time InDeltaT) const
    {
        if (ck::Is_NOT_Valid(_Intents))
        { return false; }

        return _Intents.Get_IsIntentActive(IntentTag);
    }
}

// True once the intent is pressed AFTER the condition entered - a hold that began earlier does not
// count. Makes toggles (crouch) and one-press-one-jump fall out of the HFSM with no extra state.
class UMars_SmCondition_IntentPressed : UCk_SmCondition_Polled
{
    protected FGameplayTag IntentTag;

    private FCk_Handle_InputIntents _Intents;

    // The activation frame of the hold already going when the baseline was taken; unset when the row was not Active.
    // Retaken whenever the matcher changes: a matcher that arrives after enter (pawn not composed yet, a re-point) can
    // carry a hold that began before it.
    private TOptional<int32> _BaselineFrame;

    UFUNCTION(BlueprintOverride)
    void DoEnterCondition(FCk_Handle_SmCondition InHandle, ECk_Sm_NetContext InNetContext)
    {
        _BaselineFrame.Reset();

        _Intents = ck::Ctx(InHandle).As_InputIntents();
        if (ck::Is_NOT_Valid(_Intents))
        { return; }

        _BaselineFrame = _Intents.TryGet_IntentActivationFrame(IntentTag);
        _Intents.BindTo_OnMatcherChanged(FMars_Delegate_InputIntents_OnMatcherChanged(this, n"OnMatcherChanged"));
    }

    UFUNCTION(BlueprintOverride)
    void DoExitCondition(FCk_Handle_SmCondition InHandle, ECk_Sm_NetContext InNetContext)
    {
        if (ck::IsValid(_Intents))
        { _Intents.UnbindFrom_OnMatcherChanged(FMars_Delegate_InputIntents_OnMatcherChanged(this, n"OnMatcherChanged")); }

        _Intents = FCk_Handle_InputIntents();
        _BaselineFrame.Reset();
    }

    UFUNCTION(BlueprintOverride)
    bool DoEvaluate(FCk_Handle_SmCondition InHandle, FCk_Time InDeltaT) const
    {
        if (ck::Is_NOT_Valid(_Intents))
        { return false; }

        const auto ActivationFrame = _Intents.TryGet_IntentActivationFrame(IntentTag);
        return ActivationFrame.IsSet() && ActivationFrame != _BaselineFrame;
    }

    // The drain writes the new matcher before it broadcasts, so this reads the new matcher's row.
    UFUNCTION()
    private void OnMatcherChanged(FCk_Handle_InputIntents InIntents, FCk_Handle_IntentMatcher InPrev, FCk_Handle_IntentMatcher InNew)
    {
        _BaselineFrame = InIntents.TryGet_IntentActivationFrame(IntentTag);
    }
}

class UMars_SmCondition_HasMoveIntent : UCk_SmCondition_Polled
{
    private FCk_Handle_InputIntents _Intents;

    UFUNCTION(BlueprintOverride)
    void DoEnterCondition(FCk_Handle_SmCondition InHandle, ECk_Sm_NetContext InNetContext)
    {
        _Intents = ck::Ctx(InHandle).As_InputIntents();
    }

    UFUNCTION(BlueprintOverride)
    bool DoEvaluate(FCk_Handle_SmCondition InHandle, FCk_Time InDeltaT) const
    {
        if (ck::Is_NOT_Valid(_Intents))
        { return false; }

        return _Intents.Get_MoveDirection().SizeSquared() > 0.0001;
    }
}

class UMars_SmCondition_NoMoveIntent : UMars_SmCondition_HasMoveIntent
{
    default _NegateResult = true;
}
