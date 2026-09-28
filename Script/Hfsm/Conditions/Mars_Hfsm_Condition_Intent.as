// CkIntent consumers. Polled on purpose - the matcher's poll surface is the authority (its signals
// are presentation), and polling tolerates the matcher arriving after the condition entered.

// True while the intent's level row is Active (the button is held and reaching the gameplay layer).
class UMars_SmCondition_IntentActive : UCk_SmCondition_Polled
{
    protected FGameplayTag IntentTag;

    UFUNCTION(BlueprintOverride)
    bool DoEvaluate(FCk_Handle_SmCondition InHandle, FCk_Time InDeltaT) const
    {
        auto Intents = ck::Ctx(InHandle).As_InputIntents(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Intents))
        { return false; }

        return Intents.Get_IsIntentActive(IntentTag);
    }
}

// True once the intent is pressed AFTER the condition entered - a hold that began earlier does not
// count. Makes toggles (crouch) and one-press-one-jump fall out of the HFSM with no extra state.
class UMars_SmCondition_IntentPressed : UCk_SmCondition_Polled
{
    protected FGameplayTag IntentTag;

    private int32 ActivationFrameAtEnter = -1;

    UFUNCTION(BlueprintOverride)
    void DoEnterCondition(FCk_Handle_SmCondition InHandle, ECk_Sm_NetContext InNetContext)
    {
        ActivationFrameAtEnter = -1;

        auto Intents = ck::Ctx(InHandle).As_InputIntents(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(Intents))
        { ActivationFrameAtEnter = Intents.TryGet_IntentActivationFrame(IntentTag); }
    }

    UFUNCTION(BlueprintOverride)
    bool DoEvaluate(FCk_Handle_SmCondition InHandle, FCk_Time InDeltaT) const
    {
        auto Intents = ck::Ctx(InHandle).As_InputIntents(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Intents))
        { return false; }

        const auto ActivationFrame = Intents.TryGet_IntentActivationFrame(IntentTag);
        return ActivationFrame >= 0 && ActivationFrame != ActivationFrameAtEnter;
    }
}

class UMars_SmCondition_HasMoveIntent : UCk_SmCondition_Polled
{
    UFUNCTION(BlueprintOverride)
    bool DoEvaluate(FCk_Handle_SmCondition InHandle, FCk_Time InDeltaT) const
    {
        auto Intents = ck::Ctx(InHandle).As_InputIntents(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Intents))
        { return false; }

        return Intents.Get_MoveDirection().SizeSquared() > 0.0001;
    }
}

class UMars_SmCondition_NoMoveIntent : UMars_SmCondition_HasMoveIntent
{
    default _NegateResult = true;
}
