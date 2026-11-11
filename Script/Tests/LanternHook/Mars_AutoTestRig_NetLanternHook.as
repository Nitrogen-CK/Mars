// The lantern-hook net tests' shared steps, on top of the net hotbar rig: the server lays a floor, spawns a
// UMars_LanternSconce_EntityScript and a Persistent lantern (Mars_ItemDef_Lantern) on it under the replicated spawn owner,
// and picks the lantern up into the subject's hand with a plain PickUp. Each machine finds its copy of the sconce by tag
// and reads the lantern's body through its item's Persistent link.
UCLASS(Abstract)
class UMars_AutoTestRig_NetLanternHook : UMars_AutoTestRig_NetHotbar
{
    default _TimeoutSeconds = 24.0f;

    protected const float32 k_SettleSeconds = 1.5f;
    // The server's pause between its copy holding the lantern and its next step, so the client has seen it held.
    protected const float32 k_ClientCatchUpSeconds = 2.0f;

    protected FVector _FloorTop = FVector::ZeroVector;
    protected FCk_Handle_LanternHook _Hook;
    // The lantern as this machine knows it, and its body.
    protected FCk_Handle_Item _Lantern;
    protected FCk_Handle_WorldItem _Body;
    protected int32 _EnsuresAtStart = 0;

    // Both machines: the carrier beside InFloorTop and the ensure count; the server also lays the floor.
    protected void Begin_NetLanternHook(FCk_Handle InTestEntity, FVector InFloorTop)
    {
        _FloorTop = InFloorTop;
        _EnsuresAtStart = utils_ensure::Get_EnsureCount();
        Compose_HotbarCarrier(InFloorTop + FVector(-200.0, 0.0, 100.0), 1);

        if (utils_net::Get_HasAuthority(Get_SubjectEntity()))
        { Spawn_ServerFloor(InTestEntity, InFloorTop); }
    }

    // Server: the sconce beside the carrier and the lantern lying on the floor.
    protected void Spawn_ServerSconceAndLantern()
    {
        auto Owner = utils_mars_net::Get_ReplicatedSpawnOwner(Get_SubjectEntity());
        auto Params = UMars_LanternSconce_EntityScript::Params();
        Params.SpawnTransform = FTransform(FRotator::ZeroRotator, _FloorTop + FVector(200.0, 0.0, 150.0));
        utils_entity_script::Request_SpawnEntity(Owner, UMars_LanternSconce_EntityScript, Params);

        auto Spec = FMars_WorldItem_WorldSpec(utils_held_item::Make_DefinitionSoft(mars_items::Lantern()),
            FTransform(FRotator::ZeroRotator, _FloorTop + FVector(0.0, 0.0, 20.0)));
        _Rock = utils_world_item::Request_SpawnWorld(Owner, Spec);
        Track_ForCleanup(_Rock);
    }

    // This machine's hook has composed; the server tracks it the first time.
    protected bool Get_IsHookFound()
    {
        if (ck::IsValid(_Hook))
        { return true; }

        for (auto Candidate : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), n"TAG_MarsLanternSconce"))
        {
            auto Hook = Candidate.As_LanternHook(ECk_SanityCheck::UnChecked);
            if (ck::Is_NOT_Valid(Hook))
            { continue; }

            _Hook = Hook;
            if (utils_net::Get_HasAuthority(Get_SubjectEntity()))
            { Track_ForCleanup(Candidate); }

            return true;
        }

        return false;
    }

    // Server: the lantern's body has linked its item, the carrier is ready and the hook is found.
    UFUNCTION()
    protected void Is_ServerLanternLinked(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto WorldItem = _Rock.As_WorldItem(ECk_SanityCheck::UnChecked);
        auto Result = OutResult;
        Result.Set(ck::IsValid(WorldItem) && WorldItem.Get_IsLinked() && ck::IsValid(WorldItem.Get_HeldItem())
            && Get_IsCarrierReady(_Carrier) && Get_IsHookFound());
    }

    // Server: the subject picks the lantern up (the authority's own caller).
    protected void PickUp_ServerLantern()
    {
        auto WorldItem = _Rock.As_WorldItem();
        WorldItem.Request_PickUp(FMars_Request_WorldItem_PickUp(Get_SubjectEntity()));
    }

    // The hook is found and the subject holds the lantern on this machine, its body Held on the subject and settled.
    UFUNCTION()
    protected void Is_LanternHeld(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
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
            _Lantern = Held;
            _Body = Body;
        }

        Result.Set(Ready);
    }

    // The hook holds a lantern and the subject's slot is empty on this machine; the first time, that lantern is the one
    // this machine knows.
    protected bool Get_IsHung()
    {
        if (Get_IsCarrierReady(_Carrier) == false || Get_IsHookFound() == false)
        { return false; }

        const auto Hung = _Hook.Get_Item();
        const auto Ready = ck::IsValid(Hung) && (ck::Is_NOT_Valid(_Lantern) || Hung == _Lantern) && Get_SlotItemCount(0) == 0;
        if (Ready && ck::Is_NOT_Valid(_Lantern))
        {
            _Lantern = Hung;
            _Body = Hung.Get_PersistentWorldItem();
        }

        return Ready;
    }

    UFUNCTION()
    protected void Is_Hung(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsHung());
    }

    // The hook is empty and the subject's hotbar holds the lantern on this machine.
    protected bool Get_IsTakenBack()
    {
        return ck::IsValid(_Hook) && ck::IsValid(_Lantern) && ck::Is_NOT_Valid(_Hook.Get_Item())
            && _Carrier.Hotbar.TryGet_SlotIndexOf(_Lantern).IsSet();
    }

    UFUNCTION()
    protected void Is_TakenBack(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsTakenBack());
    }

    // The lantern's body is Carried by this machine's hook, at its hook point, and settled.
    protected bool Get_IsBodyOnHook()
    {
        if (ck::Is_NOT_Valid(_Body) || ck::Is_NOT_Valid(_Hook))
        { return false; }

        const FCk_Handle HookEntity = _Hook;
        return _Body.Get_Mount() == EMars_WorldItem_Mount::Carried && _Body.Get_Carrier() == HookEntity
            && _Body.Get_MountPoint() == GameplayTags::AttachPoint_Mars_Hook && _Body.Get_IsSettled();
    }

    // How far the body is from this machine's hang node composed with the sconce's hang offset, in cm.
    protected float64 Get_HangPoseError()
    {
        const auto Offset = FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, -constants_lantern_item::k_BailHeight));
        return Get_PoseError(_Body, _Hook.Get_HangNode(), Offset);
    }

    protected int32 Get_NewEnsures() const
    {
        return utils_ensure::Get_EnsureCount() - _EnsuresAtStart;
    }
}
