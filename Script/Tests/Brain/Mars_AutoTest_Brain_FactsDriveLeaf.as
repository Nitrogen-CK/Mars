// A brain on a bare entity with the crawler's catalog (Roam, Flinch, Cower, the Idle fallback) and facts IsHurt false,
// CanWalk true, Settled false, goal Settled: the leaf settles on Roam; IsHurt true -> Flinch (OnLeafChanged carries
// Roam -> Flinch); IsHurt false -> Roam; CanWalk false -> Cower; CanWalk true -> Roam, and Get_Fact reads CanWalk true.
// Disabled, the brain keeps its leaf: IsHurt true leaves the leaf on Roam for 0.5 s. The spec rejects empty facts and
// an empty goal.
class UMars_AutoTest_Brain_FactsDriveLeaf : UMars_AutoTestRig_Brain
{
    default _TimeoutSeconds = 20.0f;

    private TArray<FString> _LeafChanges;
    private bool _SawRoamToFlinch = false;
    private float64 _DisabledHurtAt = 0.0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        AddBrainEntity(InHandle);
        _Brain.BindTo_OnLeafChanged(FMars_Delegate_Brain_OnLeafChanged(this, n"OnLeafChanged"));

        Add_Step("the spec rules hold and the brain composed", n"Step_AssertValidation");
        Add_Step_WaitUntil("the leaf settles on Roam", n"Check_LeafRoam", 0, 3.0f);
        Add_Step("IsHurt true", n"Step_Hurt");
        Add_Step_WaitUntil("the leaf moves to Flinch", n"Check_LeafFlinch", 0, 3.0f);
        Add_Step("OnLeafChanged carried Roam -> Flinch", n"Step_AssertRoamToFlinch");
        Add_Step("IsHurt false", n"Step_Heal");
        Add_Step_WaitUntil("the leaf returns to Roam", n"Check_LeafRoam", 0, 3.0f);
        Add_Step("CanWalk false", n"Step_Cripple");
        Add_Step_WaitUntil("the leaf moves to Cower", n"Check_LeafCower", 0, 3.0f);
        Add_Step("CanWalk true", n"Step_Uncripple");
        Add_Step_WaitUntil("the leaf returns to Roam and CanWalk reads true", n"Check_LeafRoamAndCanWalk", 0, 3.0f);
        Add_Step("disable the brain", n"Step_Disable");
        Add_Step_WaitUntil("the planner reads disabled", n"Check_PlannerDisabled", 0, 2.0f);
        Add_Step("IsHurt true while disabled", n"Step_HurtWhileDisabled");
        Add_Step_WaitUntil("the leaf stays on Roam for 0.5 s", n"Check_LeafHoldsWhileDisabled", 0, 3.0f);
        Run_Steps(InHandle);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Handlers
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnLeafChanged(FCk_Handle_Brain InBrain, TSubclassOf<UCk_GoapAction_EntityScript> InOld, TSubclassOf<UCk_GoapAction_EntityScript> InNew)
    {
        _LeafChanges.Add(f"{utils_brain::Get_ClassName(InOld)} -> {utils_brain::Get_ClassName(InNew)}");

        if (InOld == UMars_GoapAction_Crawler_Roam && InNew == UMars_GoapAction_Crawler_Flinch)
        { _SawRoamToFlinch = true; }
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Steps
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void Step_AssertValidation(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(Make_Spec().Validate().IsValid(), "the crawler-shaped spec is valid");

        auto NoFacts = Make_Spec();
        NoFacts.Facts.Empty();
        Assert_False(NoFacts.Validate().IsValid(), "a spec with no facts is rejected");

        auto NoGoal = Make_Spec();
        NoGoal.Goal.Empty();
        Assert_False(NoGoal.Validate().IsValid(), "a spec with an empty goal is rejected");

        Assert_True(ck::IsValid(_Brain), "the brain composed");
        Assert_True(ck::IsValid(_Brain.Get_Planner()), "the brain has a planner child");
        Assert_True(ck::IsValid(_Brain.Get_WorldState()), "the brain has a world-state child");
        Assert_True(_Brain.Get_Planner() != _Brain, "the planner is a child, not stamped on the owner");
        Assert_True(_Brain.Get_IsEnabled(), "a new brain is enabled");
    }

    UFUNCTION()
    private void Step_Hurt(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        SetFact(IsHurt(), true);
    }

    UFUNCTION()
    private void Step_HurtWhileDisabled(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _DisabledHurtAt = System::GetGameTimeInSeconds();
        SetFact(IsHurt(), true);
    }

    UFUNCTION()
    private void Step_Heal(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        SetFact(IsHurt(), false);
    }

    UFUNCTION()
    private void Step_Cripple(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        SetFact(CanWalk(), false);
    }

    UFUNCTION()
    private void Step_Uncripple(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        SetFact(CanWalk(), true);
    }

    UFUNCTION()
    private void Step_Disable(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Brain.Request_SetEnabled(FMars_Request_Brain_SetEnabled(ECk_EnableDisable::Disable));
    }

    UFUNCTION()
    private void Step_AssertRoamToFlinch(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_SawRoamToFlinch, f"OnLeafChanged fired Roam -> Flinch (changes: {_LeafChanges.Num()})");
        Assert_True(_Brain.Get_Fact(IsHurt()), "IsHurt reads true");
    }

    UFUNCTION()
    private void Check_LeafRoam(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Brain.Get_LeafClass() == UMars_GoapAction_Crawler_Roam);
    }

    UFUNCTION()
    private void Check_LeafFlinch(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Brain.Get_LeafClass() == UMars_GoapAction_Crawler_Flinch);
    }

    UFUNCTION()
    private void Check_LeafCower(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Brain.Get_LeafClass() == UMars_GoapAction_Crawler_Cower);
    }

    UFUNCTION()
    private void Check_LeafRoamAndCanWalk(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Brain.Get_LeafClass() == UMars_GoapAction_Crawler_Roam && _Brain.Get_Fact(CanWalk()));
    }

    UFUNCTION()
    private void Check_PlannerDisabled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Brain.Get_IsEnabled() == false &&
            utils_goap_planner::Get_EnableToggle(_Brain.Get_Planner()) == ECk_EnableDisable::Disable);
    }

    // Counts 0.5 s from the IsHurt write; fails the moment the leaf leaves Roam.
    UFUNCTION()
    private void Check_LeafHoldsWhileDisabled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        if (_Brain.Get_LeafClass() != UMars_GoapAction_Crawler_Roam)
        {
            FinishFailure(f"a disabled brain changed its leaf to [{utils_brain::Get_ClassName(_Brain.Get_LeafClass())}]");
            return;
        }

        Res.Set(System::GetGameTimeInSeconds() - _DisabledHurtAt >= 0.5 && _Brain.Get_Fact(IsHurt()));
    }
}
