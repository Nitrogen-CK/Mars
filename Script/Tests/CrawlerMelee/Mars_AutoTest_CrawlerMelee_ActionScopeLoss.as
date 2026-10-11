// Losing only the jab's child scope must close offense immediately while the crawler and player survive. The observer
// drains the action's retained identity stream through terminal acknowledgement before another jab is admitted.
class UMars_AutoTest_CrawlerMelee_ActionScopeLoss : UMars_AutoTestRig_CrawlerMelee
{
    default _TimeoutSeconds = 60.0f;
    default _Origin = FVector(-280000.0, -150000.0, 600.0);

    private int64 _LostIdentity = 0;
    private int32 _LostGeneration = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        SpawnFloorAndCrawler(InHandle, Make_ArmedCrawlerSpec(4));
        Add_SettleSteps();
        Add_Step("spawn a target beyond the jab's reach", n"Step_SpawnTarget");
        Add_Step_WaitUntil("the target's hurtbox is traceable", n"Check_TargetTraceable", k_SlowPolls, 0);
        Add_Step("start the first jab", n"Step_TargetAndStart");
        Add_Step_WaitUntil("the first jab enters Windup", n"Check_Admitted", k_SlowPolls, 0);
        Add_Step_WaitUntil("the action is ready with a sample in flight", n"Check_ActionSampling", k_SlowPolls, 0);
        Add_Step("destroy only the action's child scope", n"Step_DestroyActionScope");
        Add_Step_WaitUntil("the lost action drains and the crawler returns to Idle", n"Check_AttackFinished", k_SlowPolls, 0);
        Add_Step("verify the terminal was observed and acknowledged without a hit", n"Step_AssertScopeLossDrained");
        Add_Step("start another jab using the same live crawler and player", n"Step_TargetAndStart");
        Add_Step_WaitUntil("the second jab enters Windup", n"Check_Admitted", k_SlowPolls, 0);
        Add_Step("verify a fresh action was admitted", n"Step_AssertFreshAdmission");
        Add_Step_WaitUntil("the second jab finishes", n"Check_AttackFinished", k_SlowPolls, 0);
        Add_Step("verify the second terminal was acknowledged", n"Step_AssertSecondDrained");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_SpawnTarget(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Target = SpawnTargetAhead(InHandle, 55.0, FVector(10.0, 20.0, 20.0));
    }

    UFUNCTION()
    private void Check_ActionSampling(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto& Attack = _Crawler.Get_Fragment(FMars_Fragment_Crawler_Attack);
        auto Res = OutResult;
        Res.Set(ck::IsValid(Attack.Action) && Attack.Action.Get_State() == ECk_ProceduralAction_State::Ready &&
            Attack.PendingSampleId != 0);
    }

    UFUNCTION()
    private void Step_DestroyActionScope(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto& Attack = _Crawler.Get_Fragment(FMars_Fragment_Crawler_Attack);
        Assert_True(ck::IsValid(_Crawler) && ck::IsValid(_Crawler.Get_ActionPlayer()) &&
            ck::IsValid(Attack.ActionScope) && ck::IsValid(Attack.Action),
            "the crawler, player, action, and child scope exist before the injected loss");
        _LostIdentity = Attack.ActionIdentity.Get_Value();
        _LostGeneration = Attack.Generation;
        auto Scope = Attack.ActionScope;
        utils_entity_lifetime::Request_DestroyEntity(Scope);
    }

    UFUNCTION()
    private void Step_AssertScopeLossDrained(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto& Attack = _Crawler.Get_Fragment(FMars_Fragment_Crawler_Attack);
        Assert_True(ck::IsValid(_Crawler) && ck::IsValid(_Crawler.Get_ActionPlayer()),
            "the crawler and player survived loss of the action's child scope");
        Assert_True(Attack.WindowClosed && Attack.TerminalSeen && Attack.TerminalConsumeSucceeded,
            "offense closed and the lost action's terminal was observed and acknowledged");
        Assert_True(ck::Is_NOT_Valid(Attack.Action) && ck::Is_NOT_Valid(Attack.ActionScope),
            "the lost action and scope no longer own control");
        Assert_True(Attack.LastCancel.IsSet() && Attack.LastCancel.GetValue() == EMars_Crawler_AttackCancel::PoseFailed,
            "scope loss ended the first jab as PoseFailed");
        Assert_Equals_Int(Get_DamageRequestCount(), 0, "the lost jab emitted no damage request");
    }

    UFUNCTION()
    private void Step_AssertFreshAdmission(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto& Attack = _Crawler.Get_Fragment(FMars_Fragment_Crawler_Attack);
        Assert_True(ck::IsValid(Attack.Action) && Attack.ActionIdentity.Get_Value() != _LostIdentity &&
            Attack.Generation > _LostGeneration,
            "the next jab admitted a fresh action identity and generation");
        Assert_True(Attack.WindowClosed == false && Attack.TerminalSeen == false &&
            Attack.TerminalConsumeIssued == false && Attack.TerminalConsumeSucceeded == false,
            "terminal and offense state from the lost action did not cross admission");
    }

    UFUNCTION()
    private void Step_AssertSecondDrained(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto& Attack = _Crawler.Get_Fragment(FMars_Fragment_Crawler_Attack);
        Assert_True(Attack.TerminalSeen && Attack.TerminalConsumeSucceeded && ck::Is_NOT_Valid(Attack.Action),
            "the second jab also observed and acknowledged its own terminal");
        Assert_Equals_Int(Get_DamageRequestCount(), 0, "neither out-of-reach jab emitted a damage request");
    }
}
