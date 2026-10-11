// The crawler's GOAP catalog: one tier, goal Mars.WS.Crawler.Settled = true, which nothing ever writes true, so the plan's
// first action stays the standing behaviour (the brain's leaf) until a fact changes.
//
//   Action   Preconditions                                             Effects          Cost
//   Flinch   IsHurt = true                                             IsHurt = false   1
//   Roam     IsHurt = false, CanWalk = true, HasCombatTarget = false   Settled = true   1
//   Engage   IsHurt = false, CanWalk = true, HasCombatTarget = true    Settled = true   1
//   Cower    CanWalk = false                                           Settled = true   2
//   Idle     -                                                         Settled = true   999   (the mandatory unconditional fallback)
//
// So: hurt and able to walk -> [Flinch, Roam] or [Flinch, Engage]; unhurt and able -> [Roam], or [Engage] while an
// aggressive armed crawler holds a combat target; unable to walk -> [Cower] (hurt or not). Roam and Engage exclude each
// other on HasCombatTarget, so the equal costs never compete. Facts are written only through the brain (the crawler's
// setup processor, the combat request drain and the Flinch task).

namespace utils_crawler
{
    FGameplayTag Get_IsHurtFact()
    {
        return GameplayTags::Mars_WS_Crawler_IsHurt;
    }

    FGameplayTag Get_CanWalkFact()
    {
        return GameplayTags::Mars_WS_Crawler_CanWalk;
    }

    FGameplayTag Get_SettledFact()
    {
        return GameplayTags::Mars_WS_Crawler_Settled;
    }
}

class UMars_GoapAction_Crawler_Flinch : UCk_GoapAction_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineAction()
    {
        AddPrecondition(utils_crawler::Get_IsHurtFact(), true);
        AddEffect(utils_crawler::Get_IsHurtFact(), false);
        SetCost(1.0);
    }
}

class UMars_GoapAction_Crawler_Roam : UCk_GoapAction_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineAction()
    {
        AddPrecondition(utils_crawler::Get_IsHurtFact(), false);
        AddPrecondition(utils_crawler::Get_CanWalkFact(), true);
        AddPrecondition(utils_crawler::Get_HasCombatTargetFact(), false);
        AddEffect(utils_crawler::Get_SettledFact(), true);
        SetCost(1.0);
    }
}

class UMars_GoapAction_Crawler_Engage : UCk_GoapAction_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineAction()
    {
        AddPrecondition(utils_crawler::Get_IsHurtFact(), false);
        AddPrecondition(utils_crawler::Get_CanWalkFact(), true);
        AddPrecondition(utils_crawler::Get_HasCombatTargetFact(), true);
        AddEffect(utils_crawler::Get_SettledFact(), true);
        SetCost(1.0);
    }
}

class UMars_GoapAction_Crawler_Cower : UCk_GoapAction_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineAction()
    {
        AddPrecondition(utils_crawler::Get_CanWalkFact(), false);
        AddEffect(utils_crawler::Get_SettledFact(), true);
        SetCost(2.0);
    }
}

// The always-valid-plan fallback: no preconditions, effect = the goal, cost 999 (wins only when nothing else is viable).
class UMars_GoapAction_Crawler_Idle : UCk_GoapAction_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineAction()
    {
        AddEffect(utils_crawler::Get_SettledFact(), true);
        SetCost(999.0);
    }
}
