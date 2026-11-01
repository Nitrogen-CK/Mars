// A hostile target stands 110 uu ahead, inside the bite's reach: the mimic wakes, goes Hunt -> Bite, and the bite runs
// Windup -> Active -> Recover -> None, its lid gaping wide (LidOpen over 0.9) through the windup and slammed shut (under
// 0.1) by the end of the active phase; the mouth lands one blow (Bite.Blow.Damage) on the target; the behaviour returns
// to Hunt once the bite is over.
class UMars_AutoTest_PickleMimic_BitesATargetInReach : UMars_AutoTestRig_PickleMimic
{
    default _TimeoutSeconds = 30.0f;
    default _Origin = FVector(-170000.0, 90000.0, 600.0);

    private FCk_Handle_Health _TargetHealth;
    private TArray<EMars_PickleMimic_ActionPhase> _Phases;
    private int32 _Blows = 0;
    private bool _SawBiteState = false;
    private float32 _WidestInWindup = 0.0f;
    private float32 _LidAtRecover = 1.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        SpawnFloorAndMimic(InHandle, FMars_PickleMimic_Spec());
        _TargetHealth = SpawnTarget(InHandle, FVector(110.0, 0.0, 0.0));

        Add_Step_WaitUntil("the mimic is composed and its gait is Ready", n"Check_WalkerReady", k_SlowPolls, 0);
        Add_Step("listen to the bite", n"Step_Bind");
        Add_Step_WaitUntil("a bite ran to its end", n"Check_BiteOver", 0, 10.0f);
        Add_Step("the bite gaped, slammed and landed one blow", n"Step_AssertBitten");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Bind(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Mimic.BindTo_OnActionPhase(FMars_Delegate_PickleMimic_OnActionPhase(this, n"OnActionPhase"));
        _Mimic.BindTo_OnBlowLanded(FMars_Delegate_PickleMimic_OnBlowLanded(this, n"OnBlowLanded"));
    }

    UFUNCTION()
    private void OnActionPhase(FCk_Handle_PickleMimic InMimic, EMars_PickleMimic_Action InAction, EMars_PickleMimic_ActionPhase InPhase)
    {
        if (InAction != EMars_PickleMimic_Action::Bite || _Phases.Num() >= 4)
        { return; }

        _Phases.Add(InPhase);
        if (InPhase == EMars_PickleMimic_ActionPhase::Recover)
        { _LidAtRecover = InMimic.Get_LidOpen(); }
    }

    UFUNCTION()
    private void OnBlowLanded(FCk_Handle_PickleMimic InMimic, EMars_PickleMimic_Action InAction, FCk_Handle_HitZone InZone)
    {
        if (InAction == EMars_PickleMimic_Action::Bite && _Phases.Num() < 4)
        { ++_Blows; }
    }

    UFUNCTION()
    private void Check_BiteOver(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        _SawBiteState = _SawBiteState || _Mimic.Get_BehaviorStateClass() == UMars_SmState_PickleMimic_Bite;
        const auto Frame = _Mimic.Get_ActionFrame();
        if (Frame.Phase == EMars_PickleMimic_ActionPhase::Windup)
        { _WidestInWindup = Math::Max(_WidestInWindup, _Mimic.Get_LidOpen()); }

        Res.Set(_Phases.Num() >= 4);
    }

    UFUNCTION()
    private void Step_AssertBitten(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_SawBiteState, "the behaviour went through Bite");
        Assert_True(_Phases[0] == EMars_PickleMimic_ActionPhase::Windup && _Phases[1] == EMars_PickleMimic_ActionPhase::Active &&
            _Phases[2] == EMars_PickleMimic_ActionPhase::Recover && _Phases[3] == EMars_PickleMimic_ActionPhase::None,
            f"the bite ran Windup, Active, Recover, None (got {_Phases[0] :n}, {_Phases[1] :n}, {_Phases[2] :n}, {_Phases[3] :n})");
        Assert_True(_WidestInWindup > 0.9f, f"the lid gaped wide through the windup ({_WidestInWindup})");
        Assert_True(_LidAtRecover < 0.1f, f"the lid had slammed shut by the recovery ({_LidAtRecover})");
        Assert_Equals_Int(_Blows, 1, "the bite landed exactly one blow on the target");
        const auto Damage = _Mimic.Get_Spec().Bite.Blow.Damage;
        Assert_Equals_Float(_TargetHealth.Get_Current(), 100.0f - Damage, 0.01f, f"the target lost the blow's {Damage} health");
    }
}
