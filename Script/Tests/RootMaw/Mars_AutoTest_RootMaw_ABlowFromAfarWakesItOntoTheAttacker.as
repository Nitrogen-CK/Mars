// Two hostile targets stand beyond the Maw's WakeRadius: a decoy 700 uu ahead (the nearer, so sensing takes it) and an
// attacker 1100 uu behind. The Maw holds the decoy and stays Buried. A blow from the attacker lands on its body zone (the
// crown it leaves above ground): it flinches, is startled (the maw pops wide), takes the attacker as its target although
// the attacker stays far beyond WakeRadius, goes Emerging, bursts up and hunts it.
class UMars_AutoTest_RootMaw_ABlowFromAfarWakesItOntoTheAttacker : UMars_AutoTestRig_RootMaw
{
    default _TimeoutSeconds = 30.0f;
    default _Origin = FVector(-250000.0, 100000.0, 600.0);

    private FCk_Handle _Decoy;
    private FCk_Handle _Attacker;
    private bool _SawEmerging = false;
    private float32 _JawAfterBlow = 0.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        SpawnFloorAndMaw(InHandle, FMars_RootMaw_Spec());
        _Decoy = SpawnTarget(InHandle, FVector(700.0, 0.0, 0.0));
        _Attacker = SpawnTarget(InHandle, FVector(-1100.0, 0.0, 0.0));

        Add_Step_WaitUntil("the Maw is composed and grounded", n"Check_Ready", k_SlowPolls, 0);
        Add_Step_WaitUntil("it holds the decoy and lies buried", n"Check_BuriedOnDecoy", 0, 5.0f);
        Add_Step("the attacker strikes it from afar", n"Step_Strike");
        Add_Step_WaitUntil("the blow is taken", n"Check_BlowTaken", 0, 2.0f);
        Add_Step_WaitUntil("it wakes and hunts", n"Check_Hunting", 0, 4.0f);
        Add_Step("it woke onto the attacker", n"Step_AssertWokeOntoAttacker");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_BuriedOnDecoy(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Maw.Get_Target() == _Decoy && _Maw.Get_IsBuried() && _Maw.Get_BehaviorStateClass() == UMars_SmState_RootMaw_Buried);
    }

    UFUNCTION()
    private void Step_Strike(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Event = FMars_DamageEvent(5.0f, GameplayTags::DamageType_Mars_Blunt);
        Event.Source.Instigator = _Attacker;
        Event.Source.Causer = _Attacker;
        auto Zone = _Maw.Get_Monster().Get_BodyZone();
        Zone.Request_Hit(FMars_Request_HitZone_Hit(Event));
    }

    UFUNCTION()
    private void Check_BlowTaken(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        const auto Taken = _Maw.Get_Hurt().FlinchCount >= 1;
        if (Taken)
        { _JawAfterBlow = _Maw.Get_JawOpen(); }

        Res.Set(Taken);
    }

    UFUNCTION()
    private void Check_Hunting(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        const auto State = _Maw.Get_BehaviorStateClass();
        _SawEmerging = _SawEmerging || State == UMars_SmState_RootMaw_Emerging;
        Res.Set(State == UMars_SmState_RootMaw_Hunt);
    }

    UFUNCTION()
    private void Step_AssertWokeOntoAttacker(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_JawAfterBlow > 0.9f, f"the startled maw popped wide ({_JawAfterBlow})");
        Assert_True(_SawEmerging, "the behaviour went through Emerging");
        Assert_True(_Maw.Get_Target() == _Attacker, f"it targets the attacker (holds {_Maw.Get_Target().ToString()})");
        Assert_True(_Maw.Get_IsEmerged(), "it came up");
        Assert_True(_Maw.Get_IsStartled() == false, "coming up ended the startle");
        const auto Distance = (_Maw.Get_TargetLocation() - _Maw.Get_Location()).Size();
        Assert_True(Distance > _Maw.Get_Spec().Senses.WakeRadius, f"the attacker is still beyond WakeRadius ({Distance})");
    }
}
