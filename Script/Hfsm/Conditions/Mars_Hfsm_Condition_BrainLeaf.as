// Event-driven: binds the context entity's Brain.OnLeafChanged on enter and evaluates the current leaf at once (so a
// leaf that already matches passes on the state's first frame). Derive and set LeafClass, plus RequirePresent = false for
// the "leaf left" exit conditions; never _NegateResult (it does not invert an event-driven condition's resting Fail).
//
// The context entity is the brain's owner: ck::Ctx resolves to it only if the owner called Request_OverrideToSelf()
// before any SM child was created.
class UMars_SmCondition_BrainLeaf : UCk_SmCondition_EventDriven
{
    protected TSubclassOf<UCk_GoapAction_EntityScript> LeafClass;
    protected bool RequirePresent = true;

    private FCk_Handle_Brain CachedBrain;

    UFUNCTION(BlueprintOverride)
    void DoEnterCondition(FCk_Handle_SmCondition InHandle, ECk_Sm_NetContext InNetContext)
    {
        auto ContextEntity = ck::Ctx(InHandle);
        if (ck::EnsureIfNot(ck::IsValid(ContextEntity), "BrainLeaf condition: context entity is invalid"))
        { return; }

        CachedBrain = ContextEntity.As_Brain(ECk_SanityCheck::UnChecked);
        if (ck::EnsureIfNot(ck::IsValid(CachedBrain),
            f"BrainLeaf condition: context entity [{ContextEntity.ToString()}] has no Brain (composed after the state machine, or no Request_OverrideToSelf?)"))
        { return; }

        CachedBrain.BindTo_OnLeafChanged(FMars_Delegate_Brain_OnLeafChanged(this, n"OnLeafChanged"));
        Evaluate();
    }

    UFUNCTION(BlueprintOverride)
    void DoExitCondition(FCk_Handle_SmCondition InHandle, ECk_Sm_NetContext InNetContext)
    {
        if (ck::IsValid(CachedBrain))
        { CachedBrain.UnbindFrom_OnLeafChanged(FMars_Delegate_Brain_OnLeafChanged(this, n"OnLeafChanged")); }

        CachedBrain = FCk_Handle_Brain();
    }

    UFUNCTION()
    private void OnLeafChanged(FCk_Handle_Brain InBrain, TSubclassOf<UCk_GoapAction_EntityScript> InOld, TSubclassOf<UCk_GoapAction_EntityScript> InNew)
    {
        Evaluate();
    }

    private void Evaluate()
    {
        if (ck::Is_NOT_Valid(CachedBrain))
        { return; }

        const auto Matches = CachedBrain.Get_LeafClass() == LeafClass;
        if (RequirePresent ? Matches : Matches == false)
        { MarkSatisfied(); }
        else
        { MarkUnsatisfied(); }
    }
}
