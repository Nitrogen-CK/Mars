// The brain rig: a brain with the crawler's catalog (Roam, Flinch, Cower, the Idle fallback) and facts IsHurt false,
// CanWalk true, Settled false, goal Settled, on a fresh entity that overrides its context to itself.
// MinReplanIntervalSeconds is 0 so every fact flip replans at once.
UCLASS(Abstract)
class UMars_AutoTestRig_Brain : UCk_AutoTest_Base
{
    protected FCk_Handle_Brain _Brain;

    // Returns the brain's entity. The context override comes first: conditions resolve ck::Ctx to this entity only if
    // the override precedes every child.
    protected FCk_Handle AddBrainEntity(FCk_Handle InHandle)
    {
        auto Entity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        Entity.Request_OverrideToSelf();
        _Brain = utils_brain::Add(Entity, Make_Spec());
        return Entity;
    }

    protected FMars_Brain_Spec Make_Spec() const
    {
        auto Facts = TArray<FMars_Brain_Fact>();
        Facts.Add(FMars_Brain_Fact(IsHurt(), false));
        Facts.Add(FMars_Brain_Fact(CanWalk(), true));
        Facts.Add(FMars_Brain_Fact(Settled(), false));

        auto Goal = TArray<FCk_GoapWS_Condition_Authored>();
        Goal.Add(FCk_GoapWS_Condition_Authored(Settled(), true));

        auto Spec = FMars_Brain_Spec(GameplayTags::Mars_Goap_Crawler, GameplayTags::Mars_WS_Crawler,
            Facts, Goal, 0.0f);
        Spec.AddAction(UMars_GoapAction_Crawler_Roam);
        Spec.AddAction(UMars_GoapAction_Crawler_Flinch);
        Spec.AddAction(UMars_GoapAction_Crawler_Cower);
        Spec.AddAction(UMars_GoapAction_Crawler_Idle);
        return Spec;
    }

    protected FGameplayTag IsHurt() const
    {
        return GameplayTags::Mars_WS_Crawler_IsHurt;
    }

    protected FGameplayTag CanWalk() const
    {
        return GameplayTags::Mars_WS_Crawler_CanWalk;
    }

    protected FGameplayTag Settled() const
    {
        return GameplayTags::Mars_WS_Crawler_Settled;
    }

    protected void SetFact(FGameplayTag InKey, bool InValue)
    {
        _Brain.Request_SetFact(FMars_Request_Brain_SetFact(InKey, InValue));
    }
}
