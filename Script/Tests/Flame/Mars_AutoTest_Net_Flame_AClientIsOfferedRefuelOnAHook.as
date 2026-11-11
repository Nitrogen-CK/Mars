// A low lantern hung on a sconce and the subject holding tallow: on the client the hook's Get_ActionFor reads Refuel; the
// client fires the hook's Act(Refuel), and on both machines the lantern's MeasuresLeft rose.
// Surface: Ck.Flame.Net.AS_Flame_AClientIsOfferedRefuelOnAHook
class UCk_AutoTest_Net_Flame_AClientIsOfferedRefuelOnAHook : UMars_AutoTestRig_NetLanternHook
{
    private const FVector k_FloorTop = FVector(64000.0, 0.0, 5000.0);
    // The low lantern's start: one measure of four.
    private const int32 k_MeasuresBefore = 1;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Subject = Get_SubjectEntity();
        if (ck::Is_NOT_Valid(Subject))
        { FinishFailure("subject entity not found"); return; }

        Begin_NetLanternHook(InHandle, k_FloorTop);

        if (utils_net::Get_HasAuthority(Subject) == false)
        {
            WaitUntil(n"Is_HungAndTallowHeld", n"OnClientReady", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    // The flame of the lantern this machine knows; invalid before it is known or composed.
    private FCk_Handle_Flame Get_LanternFlame() const
    {
        if (ck::Is_NOT_Valid(_Body))
        { return FCk_Handle_Flame(); }

        return _Body.H().As_Flame(ECk_SanityCheck::UnChecked);
    }

    // The hook holds the lantern and the subject holds tallow on this machine; the first time, the hung lantern is the one
    // this machine knows.
    UFUNCTION()
    private void Is_HungAndTallowHeld(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        if (Get_IsCarrierReady(_Carrier) == false || Get_IsHookFound() == false)
        { Result.Set(false); return; }

        const auto Hung = _Hook.Get_Item();
        if (ck::Is_NOT_Valid(Hung) || Hung.Has_PersistentWorldItem() == false)
        { Result.Set(false); return; }

        _Lantern = Hung;
        _Body = Hung.Get_PersistentWorldItem();

        const auto Held = _Carrier.HeldItem.Get_CurrentItem();
        Result.Set(ck::IsValid(Held) && Held.Has_Tallow() && ck::IsValid(Get_LanternFlame()));
    }

    UFUNCTION()
    private void Is_Refuelled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Flame = Get_LanternFlame();
        auto Result = OutResult;
        Result.Set(ck::IsValid(Flame) && Flame.Get_MeasuresLeft() > k_MeasuresBefore);
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto Owner = utils_mars_net::Get_ReplicatedSpawnOwner(Get_SubjectEntity());
        auto Params = UMars_LanternSconce_EntityScript::Params();
        Params.SpawnTransform = FTransform(FRotator::ZeroRotator, _FloorTop + FVector(200.0, 0.0, 150.0));
        utils_entity_script::Request_SpawnEntity(Owner, UMars_LanternSconce_EntityScript, Params);

        auto Spec = FMars_WorldItem_WorldSpec(utils_held_item::Make_DefinitionSoft(mars_test_items::LowLantern()),
            FTransform(FRotator::ZeroRotator, _FloorTop + FVector(0.0, 0.0, 20.0)));
        _Rock = utils_world_item::Request_SpawnWorld(Owner, Spec);
        Track_ForCleanup(_Rock);

        WaitUntil(n"Is_ServerLanternLinked", n"OnServerLinked", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerLinked(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        PickUp_ServerLantern();
        WaitUntil(n"Is_LanternHeld", n"OnServerLanternHeld", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerLanternHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Hook.Request_Hang(FMars_Request_LanternHook_Hang(_Lantern));
        WaitUntil(n"Is_Hung", n"OnServerHung", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerHung(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Seed_ServerSlotWith(0, mars_items::Tallow());
        WaitUntil(n"Is_HungAndTallowHeld", n"OnServerReady", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_Refuelled", n"OnServerRefuelled", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerRefuelled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ServerHoldSeconds + 1.0f, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnClientReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Action = _Hook.Get_ActionFor(Get_SubjectEntity());
        Assert_True(Action == EMars_LanternHook_Action::Refuel, f"the client is offered Refuel at the hook (got [{Action :n}])");
        utils_lantern_hook::Request_ActFor(_Hook, Get_SubjectEntity(), EMars_LanternHook_Action::Refuel);
        WaitUntil(n"Is_Refuelled", n"OnClientRefuelled", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientRefuelled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto NewEnsures = Get_NewEnsures();
        Log(f"[FlameNetTest] client refuelled a hung lantern before={k_MeasuresBefore} after={Get_LanternFlame().Get_MeasuresLeft()} newEnsures={NewEnsures}");
        Assert_True(NewEnsures == 0, f"no ensure fired (got {NewEnsures})");
        FinishSuccess();
    }
}
