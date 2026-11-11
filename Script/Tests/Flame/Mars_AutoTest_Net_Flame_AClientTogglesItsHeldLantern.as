// The subject holds a lantern (a server pickup); the client fires Act(Toggle) at it, and on both machines the lantern is
// lit; on the client its Held light probe is the one shown while it is lit.
// Surface: Ck.Flame.Net.AS_Flame_AClientTogglesItsHeldLantern
class UCk_AutoTest_Net_Flame_AClientTogglesItsHeldLantern : UMars_AutoTestRig_NetFlame
{
    private const FVector k_FloorTop = FVector(60000.0, 0.0, 5000.0);

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Subject = Get_SubjectEntity();
        if (ck::Is_NOT_Valid(Subject))
        { FinishFailure("subject entity not found"); return; }

        Begin_NetFlame(InHandle, k_FloorTop, 1);
        _HoldDefinition = mars_items::Lantern();

        if (utils_net::Get_HasAuthority(Subject) == false)
        {
            WaitUntil(n"Is_ItemHeld", n"OnClientHeld", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_HeldLit(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(ck::IsValid(_HeldFlame) && _HeldFlame.Get_IsLit());
    }

    // Lit, and the Pool pass has shown the Held probe.
    UFUNCTION()
    private void Is_HeldLitAndShown(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        if (ck::Is_NOT_Valid(_HeldFlame))
        { Result.Set(false); return; }

        const auto Shown = _HeldFlame.Get_ShownLightPool();
        Result.Set(_HeldFlame.Get_IsLit() && Shown.IsSet() && Shown.GetValue() == EMars_Flame_Pool::Held);
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerFlameItem(mars_items::Lantern());
        WaitUntil(n"Is_ServerItemLinked", n"OnServerLinked", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerLinked(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        PickUp_ServerItem();
        WaitUntil(n"Is_ItemHeld", n"OnServerHeldItem", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerHeldItem(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_HeldLit", n"OnServerLit", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerLit(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ServerHoldSeconds + 1.0f, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnClientHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_False(_HeldFlame.Get_IsLit(), "the client's lantern starts unlit");
        utils_flame::Request_ActFor(_HeldFlame, Get_SubjectEntity(), EMars_Flame_Verb::Toggle);
        WaitUntil(n"Is_HeldLitAndShown", n"OnClientLit", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientLit(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Shown = _HeldFlame.Get_ShownLightPool();
        const auto ShownHeld = Shown.IsSet() && Shown.GetValue() == EMars_Flame_Pool::Held;
        const auto NewEnsures = Get_NewEnsures();
        Log(f"[FlameNetTest] client toggled its held lantern lit={_HeldFlame.Get_IsLit()} shownHeld={ShownHeld} newEnsures={NewEnsures}");
        Assert_True(NewEnsures == 0, f"no ensure fired (got {NewEnsures})");
        FinishSuccess();
    }
}
