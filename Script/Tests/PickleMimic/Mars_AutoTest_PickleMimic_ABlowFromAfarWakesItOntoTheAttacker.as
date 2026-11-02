// Two hostile targets stand beyond the mimic's WakeRadius: a decoy 700 uu ahead (the nearer, so sensing takes it) and an
// attacker 1100 uu behind. The mimic holds the decoy and stays Disguised. A blow from the attacker lands on its body zone:
// it is startled awake (the lid pops open), takes the attacker as its target although the attacker stays far beyond
// WakeRadius, goes Waking, stands up and hunts it.
class UMars_AutoTest_PickleMimic_ABlowFromAfarWakesItOntoTheAttacker : UMars_AutoTestRig_PickleMimic
{
    default _TimeoutSeconds = 30.0f;
    default _Origin = FVector(-170000.0, 150000.0, 600.0);

    private FCk_Handle _Decoy;
    private FCk_Handle _Attacker;
    private bool _SawWaking = false;
    private float32 _LidAfterBlow = 0.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        SpawnFloorAndMimic(InHandle, FMars_PickleMimic_Spec());
        _Decoy = SpawnTarget(InHandle, FVector(700.0, 0.0, 0.0));
        _Attacker = SpawnTarget(InHandle, FVector(-1100.0, 0.0, 0.0));

        Add_Step_WaitUntil("the mimic is composed and its gait is Ready", n"Check_WalkerReady", k_SlowPolls, 0);
        Add_Step_WaitUntil("it holds the decoy and sits disguised", n"Check_DisguisedOnDecoy", 0, 5.0f);
        Add_Step("the attacker strikes it from afar", n"Step_Strike");
        Add_Step_WaitUntil("the blow is taken", n"Check_BlowTaken", 0, 2.0f);
        Add_Step_WaitUntil("it wakes and hunts", n"Check_Hunting", 0, 4.0f);
        Add_Step("it woke onto the attacker", n"Step_AssertWokeOntoAttacker");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_DisguisedOnDecoy(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Mimic.Get_Target() == _Decoy && _Mimic.Get_IsTucked() && _Mimic.Get_BehaviorStateClass() == UMars_SmState_PickleMimic_Disguised);
    }

    UFUNCTION()
    private void Step_Strike(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Event = FMars_DamageEvent(5.0f, GameplayTags::DamageType_Mars_Blunt);
        Event.Source.Instigator = _Attacker;
        Event.Source.Causer = _Attacker;
        auto Zone = _Mimic.Get_Monster().Get_BodyZone();
        Zone.Request_Hit(FMars_Request_HitZone_Hit(Event));
    }

    UFUNCTION()
    private void Check_BlowTaken(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        const auto Taken = _Mimic.Get_Hurt().FlinchCount >= 1;
        if (Taken)
        { _LidAfterBlow = _Mimic.Get_LidOpen(); }

        Res.Set(Taken);
    }

    UFUNCTION()
    private void Check_Hunting(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        const auto State = _Mimic.Get_BehaviorStateClass();
        _SawWaking = _SawWaking || State == UMars_SmState_PickleMimic_Waking;
        Res.Set(State == UMars_SmState_PickleMimic_Hunt);
    }

    UFUNCTION()
    private void Step_AssertWokeOntoAttacker(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_LidAfterBlow > 0.9f, f"the startled lid popped open ({_LidAfterBlow})");
        Assert_True(_SawWaking, "the behaviour went through Waking");
        Assert_True(_Mimic.Get_Target() == _Attacker, f"it targets the attacker (holds {_Mimic.Get_Target().ToString()})");
        Assert_True(_Mimic.Get_IsStanding(), "it stood up");
        Assert_True(_Mimic.Get_IsStartled() == false, "standing up ended the startle");
        const auto Distance = (_Mimic.Get_TargetLocation() - _Mimic.Get_Location()).Size();
        Assert_True(Distance > _Mimic.Get_Spec().Senses.WakeRadius, f"the attacker is still beyond WakeRadius ({Distance})");
    }
}
