// The real censer (Charges 3, RefillSeconds 0.3): three hits across frames spill three handfuls (Hit) and exhaust it,
// which disables the zone; a fourth hit while empty spills nothing; once refilled, one more hit spills again.
class UMars_AutoTest_Forage_CenserSpillsPerHitThenRefills : UMars_AutoTestRig_Forage
{
    default _TimeoutSeconds = 10.0f;

    private const FVector k_Origin = FVector(-60000.0, 12000.0, -60000.0);
    private const int32 k_Charges = 3;
    private const float32 k_RefillSeconds = 0.3f;
    private const float32 k_HitDamage = 25.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto SpawnParams = UMars_ForageCenser_EntityScript::Params();
        SpawnParams.SpawnTransform = FTransform(FRotator::ZeroRotator, k_Origin);
        SpawnParams.WithVisuals = false;
        SpawnParams.Charges = k_Charges;
        SpawnParams.RefillSeconds = k_RefillSeconds;

        auto Pending = utils_entity_script::Request_SpawnEntity(InHandle, UMars_ForageCenser_EntityScript, SpawnParams);
        utils_pending_entity_script::Promise_OnConstructed(Pending, FCk_Delegate_EntityScript_Constructed(this, n"OnSourceConstructed"));

        Add_Step_WaitUntil("the censer composed its forage and zone", n"Check_Composed");
        Add_Step("bind the forage; hit 1", n"Step_Hit");
        Add_Step_WaitUntil("one handful", n"Check_OneReleased");
        Add_Step("hit 2", n"Step_Hit");
        Add_Step_WaitUntil("two handfuls", n"Check_TwoReleased");
        Add_Step("hit 3", n"Step_Hit");
        Add_Step_WaitUntil("three handfuls, exhausted, zone disabled", n"Check_ExhaustedAndDisabled");
        Add_Step("hit 4 while empty", n"Step_Hit");
        Add_Step_WaitUntil("refilled", n"Check_Replenished", 0, 3.0f);
        Add_Step("the empty hit spilled nothing", n"Step_AssertNoFourthSpill");
        Add_Step_WaitUntil("zone enabled again", n"Check_ZoneEnabled");
        Add_Step("hit 5", n"Step_Hit");
        Add_Step_WaitUntil("a fourth handful after the refill", n"Check_SpillAfterRefill");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_Composed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsSourceComposed());
    }

    UFUNCTION()
    private void Step_Hit(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        if (ck::Is_NOT_Valid(_Forage))
        { BindSignals(_Source.As_Forage()); }

        HitSource(k_HitDamage, GameplayTags::DamageType_Mars_Blunt);
    }

    UFUNCTION()
    private void Check_OneReleased(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Released.Num() == 1);
    }

    UFUNCTION()
    private void Check_TwoReleased(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Released.Num() == 2);
    }

    UFUNCTION()
    private void Check_ExhaustedAndDisabled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        const auto Zone = _Source.As_HitZone();
        Res.Set(_Released.Num() == k_Charges && _Forage.Get_IsExhausted() && Zone.Get_IsEnabled() == false);
    }

    UFUNCTION()
    private void Check_Replenished(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_ReplenishedCount == 1);
    }

    UFUNCTION()
    private void Step_AssertNoFourthSpill(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Released.Num(), k_Charges, "a hit on the empty censer spills nothing");
        Assert_Equals_Int(_ExhaustedCount, 1, "exhausted once");
        for (const auto Reason : _ReleaseReasons)
        { Assert_True(Reason == EMars_Forage_ReleaseReason::Hit, "every spill is a Hit"); }
    }

    UFUNCTION()
    private void Check_ZoneEnabled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        const auto Zone = _Source.As_HitZone();
        Res.Set(Zone.Get_IsEnabled());
    }

    UFUNCTION()
    private void Check_SpillAfterRefill(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Released.Num() == k_Charges + 1 && _ReleaseReasons[k_Charges] == EMars_Forage_ReleaseReason::Hit);
    }
}
