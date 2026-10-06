// The real fig vine (RegrowSeconds 0.3): one Blunt hit empties its 1 HP, which releases the fruit (Depleted) and
// disables the zone; the vine regrows (zone enabled, Health at Max) and a second hit releases again.
class UMars_AutoTest_Forage_VineStrikeDepletesThenRegrows : UMars_AutoTestRig_Forage
{
    default _TimeoutSeconds = 10.0f;

    private const FVector k_Origin = FVector(-60000.0, 10000.0, -60000.0);
    private const float32 k_RegrowSeconds = 0.3f;
    private const float32 k_HitDamage = 25.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto SpawnParams = UMars_Forage_FigVine_EntityScript::Params();
        SpawnParams.SpawnTransform = FTransform(FRotator::ZeroRotator, k_Origin);
        SpawnParams.WithVisuals = false;
        SpawnParams.RegrowSeconds = k_RegrowSeconds;

        auto Pending = utils_entity_script::Request_SpawnEntity(InHandle, UMars_Forage_FigVine_EntityScript, SpawnParams);
        utils_pending_entity_script::Promise_OnConstructed(Pending, FCk_Delegate_EntityScript_Constructed(this, n"OnSourceConstructed"));

        Add_Step_WaitUntil("the vine composed its forage and zone", n"Check_Composed");
        Add_Step("bind the forage; hit the zone Blunt 25", n"Step_Hit");
        Add_Step_WaitUntil("released on the depletion, exhausted, zone disabled", n"Check_ReleasedAndDisabled");
        Add_Step_WaitUntil("regrown", n"Check_Replenished", 0, 3.0f);
        Add_Step_WaitUntil("zone enabled and Health back at Max", n"Check_Rearmed");
        Add_Step("hit the zone again", n"Step_Hit");
        Add_Step_WaitUntil("released a second time", n"Check_SecondRelease");
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
    private void Check_ReleasedAndDisabled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        const auto Zone = _Source.As_HitZone();
        Res.Set(_Released.Num() == 1 && _ReleaseReasons[0] == EMars_Forage_ReleaseReason::Depleted
            && _Forage.Get_IsExhausted() && Zone.Get_IsEnabled() == false);
    }

    UFUNCTION()
    private void Check_Replenished(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_ReplenishedCount == 1);
    }

    UFUNCTION()
    private void Check_Rearmed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        const auto Zone = _Source.As_HitZone();
        const auto Health = Zone.Get_Health();
        Res.Set(Zone.Get_IsEnabled() && Health.Get_IsDepleted() == false && Math::IsNearlyEqual(Health.Get_Current(), Health.Get_Max()));
    }

    UFUNCTION()
    private void Check_SecondRelease(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Released.Num() == 2 && _ReleaseReasons[1] == EMars_Forage_ReleaseReason::Depleted);
    }
}
