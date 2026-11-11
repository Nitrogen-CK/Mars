// A client holding a lantern hangs it on the pack's hook: the hang crosses as Cue.Mars.LanternHook.Act to the authority,
// whose drain moves the lantern into the hook; on both machines the pack's hook holds the lantern and the subject's bag
// slot is empty, and the client's lantern body ends Carried on the hook at its hook point.
// Surface: Ck.Backpack.Net.AS_Backpack_AClientHangsItsLanternOnThePacksHook
class UCk_AutoTest_Net_Backpack_AClientHangsItsLanternOnThePacksHook : UMars_AutoTestRig_NetBackpack
{
    private const FVector k_FloorTop = FVector(54000.0, 0.0, 5000.0);

    private FCk_Handle_LanternHook _Hook;
    private FCk_Handle_WorldItem _Body;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Subject = Get_SubjectEntity();
        if (ck::Is_NOT_Valid(Subject))
        { FinishFailure("subject entity not found"); return; }

        Begin_NetBackpack(InHandle, k_FloorTop);

        if (utils_net::Get_HasAuthority(Subject) == false)
        {
            WaitUntil(n"Is_LanternHeld", n"OnClientLanternHeld", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerPack();
        _Rock = Spawn_ServerBeside(mars_items::Lantern());
        WaitUntil(n"Is_ServerReadyToPickUp", n"OnServerReadyToPickUp", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerReadyToPickUp(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto WorldItem = _Rock.As_WorldItem();
        WorldItem.Request_PickUp(FMars_Request_WorldItem_PickUp(Get_SubjectEntity()));
        WaitUntil(n"Is_LanternHeld", n"OnServerLanternHeld", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerLanternHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_HungOnHook", n"OnServerHung", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerHung(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ServerHoldSeconds + 1.0f, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnClientLanternHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_False(utils_net::Get_HasAuthority(_Hook), "the client's hook has no authority");
        const auto Action = _Hook.Get_ActionFor(Get_SubjectEntity());
        Assert_True(Action == EMars_LanternHook_Action::Hang, f"the client reads Hang while holding the lantern (got [{Action :n}])");
        utils_lantern_hook::Request_ActFor(_Hook, Get_SubjectEntity(), EMars_LanternHook_Action::Hang);
        WaitUntil(n"Is_HungOnHook", n"OnClientContentsArrived", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientContentsArrived(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitFrames(5, n"OnClientHung");
    }

    UFUNCTION()
    private void OnClientHung(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const FCk_Handle HookEntity = _Hook;
        const auto OnHook = _Body.Get_Mount() == EMars_WorldItem_Mount::Carried && _Body.Get_Carrier() == HookEntity
            && _Body.Get_MountPoint() == GameplayTags::AttachPoint_Mars_Hook;
        const auto NewEnsures = Get_NewEnsures();
        Log(f"[BackpackNetTest] client hung its lantern on the pack's hook bodyOnHook={OnHook} mount={_Body.Get_Mount() :n} newEnsures={NewEnsures}");
        Assert_True(OnHook, "the client's lantern body is Carried on the pack's hook at its hook point");
        Assert_True(NewEnsures == 0, f"the client saw no ensure (got {NewEnsures})");
        FinishSuccess();
    }

    // Server: the pack and its hook are ready, the lantern's body has linked its item and the carrier is ready.
    UFUNCTION()
    private void Is_ServerReadyToPickUp(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto WorldItem = _Rock.As_WorldItem(ECk_SanityCheck::UnChecked);
        auto Result = OutResult;
        Result.Set(Get_IsCarrierReady(_Carrier) && Get_IsHookFound() && ck::IsValid(WorldItem) && WorldItem.Get_IsLinked()
            && ck::IsValid(WorldItem.Get_HeldItem()));
    }

    // The hook is found and the subject holds the lantern on this machine, its body Held on the subject and settled.
    UFUNCTION()
    private void Is_LanternHeld(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        if (Get_IsCarrierReady(_Carrier) == false || Get_IsHookFound() == false)
        { Result.Set(false); return; }

        const auto Held = _Carrier.HeldItem.Get_CurrentItem();
        if (ck::Is_NOT_Valid(Held) || Held.Has_LanternTrait() == false)
        { Result.Set(false); return; }

        const auto Body = Held.Get_PersistentWorldItem();
        const auto Ready = ck::IsValid(Body) && Body.Get_Mount() == EMars_WorldItem_Mount::Held
            && Body.Get_Carrier() == Get_SubjectEntity() && Body.Get_IsSettled();
        if (Ready)
        {
            _Item = Held;
            _Body = Body;
        }

        Result.Set(Ready);
    }

    // The pack's hook holds the lantern and the bag slot is empty on this machine; on the client its body has settled on
    // the hook too.
    UFUNCTION()
    private void Is_HungOnHook(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        if (ck::Is_NOT_Valid(_Hook) || ck::Is_NOT_Valid(_Item) || _Hook.Get_Item() != _Item || Get_SlotItemCount(0) != 0)
        { Result.Set(false); return; }

        const FCk_Handle HookEntity = _Hook;
        Result.Set(ck::IsValid(_Body) && _Body.Get_Mount() == EMars_WorldItem_Mount::Carried && _Body.Get_Carrier() == HookEntity
            && _Body.Get_IsSettled());
    }

    // This machine's pack is ready and its hook has composed.
    private bool Get_IsHookFound()
    {
        if (ck::IsValid(_Hook))
        { return true; }

        if (Get_IsPackReady() == false)
        { return false; }

        _Hook = _Pack.TryGet_LanternHook();
        return ck::IsValid(_Hook);
    }
}
