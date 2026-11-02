// A hostile target stands 110 uu ahead, in the bite's reach. Partway through the bite's windup the target strikes the
// mimic: the windup starts over (its clock back at 0, the lid slammed shut) and holds there through the flinch; the bite
// is not cancelled. Once the bite is in its active phase a second strike lands: the bite runs on (the same bite, still
// Active or already Recovering) and still lands its blow on the target.
class UMars_AutoTest_PickleMimic_AFlinchRestartsTheWindupButNotTheBite : UMars_AutoTestRig_PickleMimic
{
    default _TimeoutSeconds = 30.0f;
    default _Origin = FVector(-170000.0, 190000.0, 600.0);

    private FCk_Handle _Target;
    private int32 _Generation = 0;
    private float32 _WindupBeforeStrike = 0.0f;
    private float32 _WindupAfterStrike = 1.0f;
    private float32 _LidAfterStrike = 1.0f;
    private bool _HeldThroughFlinch = true;
    private int32 _Blows = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        SpawnFloorAndMimic(InHandle, FMars_PickleMimic_Spec());
        _Target = SpawnTarget(InHandle, FVector(110.0, 0.0, 0.0));

        Add_Step_WaitUntil("the mimic is composed and its gait is Ready", n"Check_WalkerReady", k_SlowPolls, 0);
        Add_Step("listen for the blow", n"Step_Bind");
        Add_Step_WaitUntil("a bite is well into its windup", n"Check_DeepInWindup", 0, 10.0f);
        Add_Step("the target strikes in the windup", n"Step_Strike");
        Add_Step_WaitUntil("the strike is taken", n"Check_FirstFlinch", 0, 2.0f);
        Add_Step_WaitUntil("the flinch passes", n"Check_FlinchOverHeld", 0, 2.0f);
        Add_Step("the windup started over", n"Step_AssertWindupRestarted");
        Add_Step_WaitUntil("the bite goes active", n"Check_Active", 0, 3.0f);
        Add_Step("the target strikes in the active phase", n"Step_Strike");
        Add_Step_WaitUntil("the second strike is taken", n"Check_SecondFlinch", 0, 2.0f);
        Add_Step("the bite ran on", n"Step_AssertBiteRanOn");
        Add_Step_WaitUntil("the bite ends", n"Check_BiteOver", 0, 3.0f);
        Add_Step("the bite still landed", n"Step_AssertLanded");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Bind(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Mimic.BindTo_OnBlowLanded(FMars_Delegate_PickleMimic_OnBlowLanded(this, n"OnBlowLanded"));
    }

    UFUNCTION()
    private void OnBlowLanded(FCk_Handle_PickleMimic InMimic, EMars_PickleMimic_Action InAction, FCk_Handle_HitZone InZone)
    {
        ++_Blows;
    }

    UFUNCTION()
    private void Check_DeepInWindup(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        const auto Action = _Mimic.Get_Action();
        const auto Deep = Action.Phase == EMars_PickleMimic_ActionPhase::Windup && Action.PhaseElapsed >= _Mimic.Get_Spec().Bite.Timing.WindupSeconds * 0.5f;
        if (Deep)
        {
            _Generation = Action.Generation;
            _WindupBeforeStrike = Action.PhaseElapsed;
        }

        Res.Set(Deep);
    }

    UFUNCTION()
    private void Step_Strike(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Event = FMars_DamageEvent(2.0f, GameplayTags::DamageType_Mars_Blunt);
        Event.Source.Instigator = _Target;
        auto Zone = _Mimic.Get_Monster().Get_BodyZone();
        Zone.Request_Hit(FMars_Request_HitZone_Hit(Event));
    }

    UFUNCTION()
    private void Check_FirstFlinch(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        const auto Taken = _Mimic.Get_Hurt().FlinchCount >= 1;
        if (Taken)
        {
            _WindupAfterStrike = _Mimic.Get_Action().PhaseElapsed;
            _LidAfterStrike = _Mimic.Get_LidOpen();
        }

        Res.Set(Taken);
    }

    UFUNCTION()
    private void Check_FlinchOverHeld(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        const auto Action = _Mimic.Get_Action();
        if (_Mimic.Get_IsFlinching())
        {
            _HeldThroughFlinch = _HeldThroughFlinch && Action.Phase == EMars_PickleMimic_ActionPhase::Windup && Action.PhaseElapsed <= 0.0f &&
                _Mimic.Get_LidOpen() <= 0.0f;
        }

        Res.Set(_Mimic.Get_IsFlinching() == false);
    }

    UFUNCTION()
    private void Step_AssertWindupRestarted(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Action = _Mimic.Get_Action();
        Assert_True(_WindupBeforeStrike > 0.1f, f"the strike came well into the windup ({_WindupBeforeStrike} s)");
        Assert_True(_WindupAfterStrike <= 0.0f, f"the strike put the windup back to its start ({_WindupAfterStrike} s)");
        Assert_True(_LidAfterStrike <= 0.0f, f"the strike slammed the lid ({_LidAfterStrike})");
        Assert_True(_HeldThroughFlinch, "the windup and the shut lid held through the flinch");
        Assert_True(Action.Kind == EMars_PickleMimic_Action::Bite && Action.Generation == _Generation, "the same bite runs on (not cancelled)");
    }

    UFUNCTION()
    private void Check_Active(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Mimic.Get_Action().Phase == EMars_PickleMimic_ActionPhase::Active);
    }

    UFUNCTION()
    private void Check_SecondFlinch(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Mimic.Get_Hurt().FlinchCount >= 2);
    }

    UFUNCTION()
    private void Step_AssertBiteRanOn(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Action = _Mimic.Get_Action();
        const auto RanOn = Action.Phase == EMars_PickleMimic_ActionPhase::Active || Action.Phase == EMars_PickleMimic_ActionPhase::Recover;
        Assert_True(Action.Kind == EMars_PickleMimic_Action::Bite && Action.Generation == _Generation && RanOn,
            f"the active bite ran on through the strike (phase {Action.Phase :n}, generation {Action.Generation} for {_Generation})");
    }

    UFUNCTION()
    private void Check_BiteOver(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Mimic.Get_Action().Kind == EMars_PickleMimic_Action::None);
    }

    UFUNCTION()
    private void Step_AssertLanded(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Blows, 1, "the bite landed its one blow on the target");
    }
}
