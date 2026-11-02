// A disguised mimic with no target in sight. A blow on its body zone with no instigator: it flinches for about
// FlinchSeconds, is startled (the blow found it disguised) and its glass stays intact (a small blow).
// Damage then takes its body health down: at or below CrackedBelow of its maximum the crack stage is 1, at or below
// HeavilyCrackedBelow it is 2; a heal does not mend it; it is still alive throughout.
class UMars_AutoTest_PickleMimic_FlinchesAndCracksAsItIsHurt : UMars_AutoTestRig_PickleMimic
{
    default _TimeoutSeconds = 30.0f;
    default _Origin = FVector(-170000.0, 170000.0, 600.0);

    private float64 _FlinchStart = 0.0;
    private float64 _FlinchSeconds = 0.0;
    private bool _Startled = false;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        SpawnFloorAndMimic(InHandle, FMars_PickleMimic_Spec());

        Add_Step_WaitUntil("the mimic is composed and its gait is Ready", n"Check_WalkerReady", k_SlowPolls, 0);
        Add_Step("a small blow lands", n"Step_SmallBlow");
        Add_Step_WaitUntil("it flinches", n"Check_Flinching", 0, 2.0f);
        Add_Step_WaitUntil("the flinch passes", n"Check_FlinchOver", 0, 2.0f);
        Add_Step("the flinch was timed and the glass held", n"Step_AssertFlinch");
        Add_Step("damage to just under CrackedBelow", n"Step_DamageToCracked");
        Add_Step_WaitUntil("it cracks", n"Check_Stage1", 0, 2.0f);
        Add_Step("damage to just under HeavilyCrackedBelow", n"Step_DamageToHeavilyCracked");
        Add_Step_WaitUntil("it cracks heavily", n"Check_Stage2", 0, 2.0f);
        Add_Step("a heal", n"Step_Heal");
        Add_Step_WaitUntil("the heal lands", n"Check_Healed", 0, 2.0f);
        Add_Step("the cracks stay and it lives", n"Step_AssertCracks");
        Run_Steps(InHandle);
    }

    private FCk_Handle_Health Get_Health()
    {
        return _Mimic.Get_Monster().Get_BodyHealth();
    }

    // Damage straight to the body health (no zone, so no flinch) leaving InShare of its maximum.
    private void DamageTo(float32 InShare)
    {
        auto Health = Get_Health();
        const auto Amount = Health.Get_Current() - Health.Get_Max() * InShare;
        Health.Request_ApplyDamage(FMars_Request_Health_ApplyDamage(FMars_DamageEvent(Amount, GameplayTags::DamageType_Mars_Blunt)));
    }

    UFUNCTION()
    private void Step_SmallBlow(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Zone = _Mimic.Get_Monster().Get_BodyZone();
        Zone.Request_Hit(FMars_Request_HitZone_Hit(FMars_DamageEvent(2.0f, GameplayTags::DamageType_Mars_Blunt)));
    }

    UFUNCTION()
    private void Check_Flinching(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        const auto Flinching = _Mimic.Get_IsFlinching();
        if (Flinching)
        {
            _FlinchStart = System::GetGameTimeInSeconds();
            _Startled = _Mimic.Get_IsStartled();
        }

        Res.Set(Flinching);
    }

    UFUNCTION()
    private void Check_FlinchOver(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        const auto Over = _Mimic.Get_IsFlinching() == false;
        if (Over)
        { _FlinchSeconds = System::GetGameTimeInSeconds() - _FlinchStart; }

        Res.Set(Over);
    }

    UFUNCTION()
    private void Step_AssertFlinch(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Seconds = _Mimic.Get_Spec().Vitals.FlinchSeconds;
        Assert_True(_Startled, "a blow that found it disguised startled it");
        Assert_Equals_Int(_Mimic.Get_Hurt().FlinchCount, 1, "one blow, one flinch");
        Assert_True(_FlinchSeconds > Seconds * 0.5 && _FlinchSeconds < Seconds + 0.25, f"the flinch lasted about FlinchSeconds ({_FlinchSeconds} for {Seconds})");
        Assert_Equals_Int(_Mimic.Get_CrackStage(), 0, "a small blow leaves the glass intact");
    }

    UFUNCTION()
    private void Step_DamageToCracked(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        DamageTo(_Mimic.Get_Spec().Vitals.CrackedBelow - 0.02f);
    }

    UFUNCTION()
    private void Check_Stage1(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Mimic.Get_CrackStage() == 1);
    }

    UFUNCTION()
    private void Step_DamageToHeavilyCracked(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Mimic.Get_IsFlinching() == false, "damage straight to its health does not flinch it");
        DamageTo(_Mimic.Get_Spec().Vitals.HeavilyCrackedBelow - 0.02f);
    }

    UFUNCTION()
    private void Check_Stage2(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Mimic.Get_CrackStage() == 2);
    }

    UFUNCTION()
    private void Step_Heal(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Health = Get_Health();
        Health.Request_Heal(FMars_Request_Health_Heal(Health.Get_Max()));
    }

    UFUNCTION()
    private void Check_Healed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_Health().Get_Current() > Get_Health().Get_Max() * 0.9f);
    }

    UFUNCTION()
    private void Step_AssertCracks(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Mimic.Get_CrackStage(), 2, "a heal does not mend the cracks");
        Assert_True(_Mimic.Get_IsDead() == false, "it is still alive");
    }
}
