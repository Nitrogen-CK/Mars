class UMars_AutoTest_AttackCatalog_StableSelection : UMars_AutoTestRig_AttackCatalogPure
{
    default _TimeoutSeconds = 20.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("A05 priority, least-recent admission and canonical IDs are independent of array order", n"Step_Order");
        Add_Step("A06 stable preference, control wait and readiness grace policies", n"Step_Policies");
        Add_Step("A08 a fourth attack is data-only", n"Step_FourthAttack");
        Run_Steps(InHandle);
    }

    private bool Get_Selected(const FMars_Attack_Selection& InSelection, FGameplayTag InId) const
    { return InSelection.Selected.IsSet() && InSelection.Selected.GetValue() == InId; }

    UFUNCTION()
    private void Step_Order(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Query = FMars_Attack_SelectionQuery();
        Query.Candidates.Add(Make_Candidate(GameplayTags::Attack_Mars_Test_Zeta, 1, EMars_Attack_Availability::Ready));
        Query.Candidates.Add(Make_Candidate(GameplayTags::ResolveGameplayTag(n"attack.mars.test.beta"), 1, EMars_Attack_Availability::Ready));
        Query.Candidates.Add(Make_Candidate(GameplayTags::Attack_Mars_Test_Alpha, 1, EMars_Attack_Availability::Ready));
        Assert_True(Get_Selected(utils_attack::Select(Query), GameplayTags::Attack_Mars_Test_Alpha), "canonical alphabetical ID is the final tie-break");
        auto Reordered = Query;
        Reordered.Candidates.Reset();
        Reordered.Candidates.Add(Query.Candidates[2]);
        Reordered.Candidates.Add(Query.Candidates[0]);
        Reordered.Candidates.Add(Query.Candidates[1]);
        Assert_True(Get_Selected(utils_attack::Select(Reordered), GameplayTags::Attack_Mars_Test_Alpha), "candidate array order does not affect selection");
        Query.Candidates[2].LastStartSequence = 1;
        Assert_True(Get_Selected(utils_attack::Select(Query), GameplayTags::ResolveGameplayTag(n"attack.mars.test.beta")), "never-started candidates precede accepted candidates");
        Query.Candidates[0].LastStartSequence = 3;
        Query.Candidates[1].LastStartSequence = 2;
        Assert_True(Get_Selected(utils_attack::Select(Query), GameplayTags::Attack_Mars_Test_Alpha), "least-recent accepted sequence wins before canonical ID");
        Query.Candidates[0].Priority = 2;
        Assert_True(Get_Selected(utils_attack::Select(Query), GameplayTags::Attack_Mars_Test_Zeta), "priority takes precedence over recency");
        Assert_True(Query.Candidates[0].LastStartSequence == 3 && Query.Candidates.Num() == 3, "selection does not mutate input history or candidate order");
    }

    UFUNCTION()
    private void Step_Policies(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Query = FMars_Attack_SelectionQuery();
        Query.Target.Identity = 11;
        Query.Target.Generation = 7;
        Query.Candidates.Add(Make_Candidate(GameplayTags::Attack_Mars_Pincer, 100, EMars_Attack_Availability::Waiting));
        Query.Candidates.Add(Make_Candidate(GameplayTags::Attack_Mars_Jab, 0, EMars_Attack_Availability::Ready));
        auto Selection = utils_attack::Select(Query);
        Assert_True(Selection.Preferred.GetValue() == GameplayTags::Attack_Mars_Pincer && Selection.ReadyChoice.GetValue() == GameplayTags::Attack_Mars_Jab &&
            Selection.Selected.IsSet() == false, "WaitPreferred preserves a stance-waiting preferred pincer");
        Query.Policy.TemporaryReadiness = EMars_Attack_TemporaryReadinessPolicy::UseReadyAlternative;
        Query.Policy.ReadyAlternativeDelaySeconds = 0.25f;
        Assert_True(utils_attack::Select(Query).Selected.IsSet() == false, "a direct request cannot spend an absent preparation grace clock");
        Query.Preparation.Active = true;
        Query.Preparation.Preferred = GameplayTags::Attack_Mars_Pincer;
        Query.Preparation.TargetIdentity = 11;
        Query.Preparation.TargetGeneration = 7;
        Query.Preparation.ElapsedReadinessWait = 0.24f;
        Assert_True(utils_attack::Select(Query).Selected.IsSet() == false, "ready alternative waits before the authored grace");
        Query.Preparation.ElapsedReadinessWait = 0.25f;
        Selection = utils_attack::Select(Query);
        Assert_True(Get_Selected(Selection, GameplayTags::Attack_Mars_Jab) && Selection.Preferred.GetValue() == GameplayTags::Attack_Mars_Pincer,
            "after grace Selected fallback differs from stable Preferred and diagnostic ReadyChoice");
        Query.Preparation.Active = false;
        Query.Policy.ReadyAlternativeDelaySeconds = 0.0f;
        Assert_True(Get_Selected(utils_attack::Select(Query), GameplayTags::Attack_Mars_Jab), "zero authored grace permits direct ready fallback");
        Query.Preparation.Active = true;
        Query.Preparation.Preferred = GameplayTags::Attack_Mars_Jab;
        Query.Candidates[0].Evaluation.Availability = EMars_Attack_Availability::Ready;
        Assert_True(Get_Selected(utils_attack::Select(Query), GameplayTags::Attack_Mars_Jab), "a better candidate regaining readiness cannot replace a valid preparing preference");
        Query.Candidates[1].Evaluation.Capable = false;
        Query.Candidates[1].Evaluation.Availability = EMars_Attack_Availability::Unavailable;
        Assert_True(Get_Selected(utils_attack::Select(Query), GameplayTags::Attack_Mars_Pincer), "permanent preferred capability loss reselects immediately");
        Query.Candidates[1].Evaluation.Capable = true;
        Query.Candidates[1].Evaluation.Availability = EMars_Attack_Availability::Ready;
        Query.Preparation.TargetGeneration = 6;
        Assert_True(Get_Selected(utils_attack::Select(Query), GameplayTags::Attack_Mars_Pincer), "target-generation change invalidates retained preference");
        Query.Preparation.TimedOut = true;
        Assert_True(Get_Selected(utils_attack::Select(Query), GameplayTags::Attack_Mars_Pincer), "stale timed-out preparation cannot block a new target generation");
        Query.Preparation.TargetGeneration = 7;
        Assert_True(utils_attack::Select(Query).Disposition == EMars_Attack_SelectionDisposition::Wait,
            "a timeout on the current preparation target still stops admission");
        Query.Preparation.TimedOut = false;
        Query.Preparation.Active = false;
        Query.Candidates[0].Evaluation.Availability = EMars_Attack_Availability::Waiting;
        auto Busy = FMars_Attack_Blocker();
        Busy.Code = n"ControlBusy";
        Query.Candidates[0].Evaluation.Blockers.Add(Busy);
        Query.Policy.ControlWait = EMars_Attack_ControlWaitPolicy::PreferAvailable;
        Assert_True(Get_Selected(utils_attack::Select(Query), GameplayTags::Attack_Mars_Jab), "PreferAvailable skips a temporarily controlled preferred limb");
        Query.Policy.ControlWait = EMars_Attack_ControlWaitPolicy::WaitForPreferred;
        Query.Policy.TemporaryReadiness = EMars_Attack_TemporaryReadinessPolicy::WaitPreferred;
        Assert_True(utils_attack::Select(Query).Selected.IsSet() == false, "WaitForPreferred retains controlled capability while waiting");
        Query.Policy.ControlWait = EMars_Attack_ControlWaitPolicy::PreferAvailable;
        Query.Candidates[1].Evaluation.Availability = EMars_Attack_Availability::Waiting;
        Query.Candidates[1].Evaluation.Blockers.Add(Busy);
        Selection = utils_attack::Select(Query);
        Assert_True(Selection.Disposition == EMars_Attack_SelectionDisposition::Wait && Selection.Preferred.IsSet() == false,
            "all capable control-busy entries wait without being mislabeled NoCapability");
        Query.Candidates[0].Evaluation.Capable = false;
        Query.Candidates[1].Evaluation.Capable = false;
        Assert_True(utils_attack::Select(Query).Disposition == EMars_Attack_SelectionDisposition::NoCapability,
            "NoCapability means every candidate permanently lacks capability");
    }

    UFUNCTION()
    private void Step_FourthAttack(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Query = FMars_Attack_SelectionQuery();
        Query.Candidates.Add(Make_Candidate(GameplayTags::Attack_Mars_Pincer, 3, EMars_Attack_Availability::Ready));
        Query.Candidates.Add(Make_Candidate(GameplayTags::Attack_Mars_Test_Swipe, 2, EMars_Attack_Availability::Ready));
        Query.Candidates.Add(Make_Candidate(GameplayTags::Attack_Mars_Jab, 1, EMars_Attack_Availability::Ready));
        Query.Candidates.Add(Make_Candidate(GameplayTags::Attack_Mars_Test_Fourth, 4, EMars_Attack_Availability::Ready));
        Assert_True(Get_Selected(utils_attack::Select(Query), GameplayTags::Attack_Mars_Test_Fourth),
            "a fourth ID/definition requires no selector enum or code branch");
        Query.Candidates[3].Evaluation.Capable = false;
        Assert_True(Get_Selected(utils_attack::Select(Query), GameplayTags::Attack_Mars_Pincer), "the same data-driven selector falls back after fourth-attack capability loss");
    }
}
