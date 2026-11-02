// A hostile target stands 110 uu ahead, inside the bite's reach: the Maw bursts up, goes Hunt -> Bite, and the bite runs
// Windup -> Active -> Recover -> None, its maw gaping wide (JawOpen over 0.9) through the windup and slammed shut (under
// 0.1) by the end of the active phase; the maw lands one blow (Bite.Blow.Damage) on the target; the behaviour returns
// to Hunt once the bite is over.
class UMars_AutoTest_RootMaw_BitesATargetInReach : UMars_AutoTestRig_RootMaw
{
    default _TimeoutSeconds = 30.0f;
    default _Origin = FVector(-250000.0, 60000.0, 600.0);

    private FCk_Handle_Health _TargetHealth;
    private TArray<EMars_RootMaw_ActionPhase> _Phases;
    private int32 _Blows = 0;
    private bool _SawBiteState = false;
    private float32 _WidestInWindup = 0.0f;
    private float32 _JawAtRecover = 1.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        SpawnFloorAndMaw(InHandle, FMars_RootMaw_Spec());
        _TargetHealth = SpawnTarget(InHandle, FVector(110.0, 0.0, 0.0));

        Add_Step_WaitUntil("the Maw is composed and grounded", n"Check_Ready", k_SlowPolls, 0);
        Add_Step("listen to the bite", n"Step_Bind");
        Add_Step_WaitUntil("a bite ran to its end", n"Check_BiteOver", 0, 10.0f);
        Add_Step("the bite gaped, slammed and landed one blow", n"Step_AssertBitten");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Bind(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Maw.BindTo_OnActionPhase(FMars_Delegate_RootMaw_OnActionPhase(this, n"OnActionPhase"));
        _Maw.BindTo_OnBlowLanded(FMars_Delegate_RootMaw_OnBlowLanded(this, n"OnBlowLanded"));
    }

    UFUNCTION()
    private void OnActionPhase(FCk_Handle_RootMaw InMaw, EMars_RootMaw_Action InAction, EMars_RootMaw_ActionPhase InPhase)
    {
        if (InAction != EMars_RootMaw_Action::Bite || _Phases.Num() >= 4)
        { return; }

        _Phases.Add(InPhase);
        if (InPhase == EMars_RootMaw_ActionPhase::Recover)
        { _JawAtRecover = InMaw.Get_JawOpen(); }
    }

    UFUNCTION()
    private void OnBlowLanded(FCk_Handle_RootMaw InMaw, EMars_RootMaw_Action InAction, FCk_Handle_HitZone InZone)
    {
        if (InAction == EMars_RootMaw_Action::Bite && _Phases.Num() < 4)
        { ++_Blows; }
    }

    UFUNCTION()
    private void Check_BiteOver(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        _SawBiteState = _SawBiteState || _Maw.Get_BehaviorStateClass() == UMars_SmState_RootMaw_Bite;
        const auto Frame = _Maw.Get_ActionFrame();
        if (Frame.Phase == EMars_RootMaw_ActionPhase::Windup)
        { _WidestInWindup = Math::Max(_WidestInWindup, _Maw.Get_JawOpen()); }

        Res.Set(_Phases.Num() >= 4);
    }

    UFUNCTION()
    private void Step_AssertBitten(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_SawBiteState, "the behaviour went through Bite");
        Assert_True(_Phases[0] == EMars_RootMaw_ActionPhase::Windup && _Phases[1] == EMars_RootMaw_ActionPhase::Active &&
            _Phases[2] == EMars_RootMaw_ActionPhase::Recover && _Phases[3] == EMars_RootMaw_ActionPhase::None,
            f"the bite ran Windup, Active, Recover, None (got {_Phases[0] :n}, {_Phases[1] :n}, {_Phases[2] :n}, {_Phases[3] :n})");
        Assert_True(_WidestInWindup > 0.9f, f"the maw gaped wide through the windup ({_WidestInWindup})");
        Assert_True(_JawAtRecover < 0.1f, f"the jaw had slammed shut by the recovery ({_JawAtRecover})");
        Assert_Equals_Int(_Blows, 1, "the bite landed exactly one blow on the target");
        const auto Damage = _Maw.Get_Spec().Bite.Blow.Damage;
        Assert_Equals_Float(_TargetHealth.Get_Current(), 100.0f - Damage, 0.01f, f"the target lost the blow's {Damage} health");
    }
}
