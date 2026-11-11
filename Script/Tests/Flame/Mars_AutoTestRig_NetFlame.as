// A lantern of eight one-second measures, so a net test sees several measures burn. Otherwise Mars_ItemDef_Lantern.
asset Mars_TestItemDef_NetQuickLantern of UCk_InventoryItem_Definition
{
    _CoreInfo = FCk_InventoryItem_CoreInfo(FText::FromString("Quick Lantern"));

    auto Presentation = Cast<UMars_ItemTrait_Presentation>(NewObject(this, UMars_ItemTrait_Presentation));
    Presentation.Visual.Mesh = assets::CampLantern_Mars_SM();
    Presentation.Visual.MeshScale = FVector(constants_lantern_item::k_MeshScale, constants_lantern_item::k_MeshScale, constants_lantern_item::k_MeshScale);
    Presentation.Grip.Handedness = EMars_ItemPresentation_Handedness::OneHanded;
    Presentation.Mounting.Persistence = EMars_WorldItem_Persistence::Persistent;
    Presentation.Mounting.CarryPoint = GameplayTags::AttachPoint_Mars_Belt;
    Presentation.WorldItem.ScriptClass = UMars_Lantern_EntityScript;
    _ItemTraits.Add(Presentation);

    auto Fuel = FMars_Flame_Fuel();
    Fuel.Measures = 8;
    Fuel.SecondsPerMeasure = 1.0f;
    Fuel.GutterSeconds = 0.1f;

    auto Flame = Cast<UMars_ItemTrait_Flame>(NewObject(this, UMars_ItemTrait_Flame));
    Flame.Spec = mars_test_items::Make_LanternFlameSpec(Fuel);
    _ItemTraits.Add(Flame);

    auto Lantern = Cast<UMars_ItemTrait_Lantern>(NewObject(this, UMars_ItemTrait_Lantern));
    _ItemTraits.Add(Lantern);
}

// The flame net tests' shared steps, on top of the net hotbar rig: the server lays a floor and spawns candles and flame
// items under the replicated spawn owner; each machine finds its copy of a candle by tag and place, and of a carried flame
// through the item its hand holds. Each machine counts the signals its own copy of a watched flame raises.
UCLASS(Abstract)
class UMars_AutoTestRig_NetFlame : UMars_AutoTestRig_NetHotbar
{
    default _TimeoutSeconds = 24.0f;

    // The server's pause after a step, so the client has seen what came before it.
    protected const float32 k_ClientCatchUpSeconds = 2.0f;
    // A settle that lets a dropped request show it changed nothing.
    protected const float32 k_SettleSeconds = 1.5f;

    protected FVector _FloorTop = FVector::ZeroVector;
    protected int32 _EnsuresAtStart = 0;

    // The item the next Is_ItemHeld waits for in the hand, and what it found: the item and its body's flame.
    protected UCk_InventoryItem_Definition _HoldDefinition;
    protected FCk_Handle_Item _HeldItem;
    protected FCk_Handle_Flame _HeldFlame;

    // The flame Watch_Signals bound on this machine, and what it raised since.
    protected FCk_Handle_Flame _Watched;
    protected int32 _LitChanges = 0;
    protected int32 _MeasuresChanges = 0;

    // Both machines: the carrier beside InFloorTop and the ensure count; the server also lays the floor.
    protected void Begin_NetFlame(FCk_Handle InTestEntity, FVector InFloorTop, int32 InBagSlots)
    {
        _FloorTop = InFloorTop;
        _EnsuresAtStart = utils_ensure::Get_EnsureCount();
        Compose_HotbarCarrier(InFloorTop + FVector(-200.0, 0.0, 100.0), InBagSlots);

        if (utils_net::Get_HasAuthority(Get_SubjectEntity()))
        { Spawn_ServerFloor(InTestEntity, InFloorTop); }
    }

    protected UCk_InventoryItem_Definition Get_QuickLantern() const
    {
        return Mars_TestItemDef_NetQuickLantern;
    }

    // Server: a candle InOffset from the floor top, lit or not.
    protected void Spawn_ServerCandle(FVector InOffset, EMars_Flame_Ignition InStartLit)
    {
        auto Owner = utils_mars_net::Get_ReplicatedSpawnOwner(Get_SubjectEntity());
        auto Params = UMars_Candle_EntityScript::Params();
        Params.SpawnTransform = FTransform(FRotator::ZeroRotator, _FloorTop + InOffset);
        Params.StartLit = InStartLit;
        utils_entity_script::Request_SpawnEntity(Owner, UMars_Candle_EntityScript, Params);
    }

    // Server: a flame item of InDefinition lying on the floor, tracked for cleanup (as _Rock).
    protected void Spawn_ServerFlameItem(UCk_InventoryItem_Definition InDefinition)
    {
        auto Owner = utils_mars_net::Get_ReplicatedSpawnOwner(Get_SubjectEntity());
        auto Spec = FMars_WorldItem_WorldSpec(utils_held_item::Make_DefinitionSoft(InDefinition),
            FTransform(FRotator::ZeroRotator, _FloorTop + FVector(0.0, 0.0, 20.0)));
        _Rock = utils_world_item::Request_SpawnWorld(Owner, Spec);
        Track_ForCleanup(_Rock);
    }

    // This machine's copy of the candle InOffset from the floor top, once composed; the server tracks it the first time.
    protected bool Find_Candle(FVector InOffset, FCk_Handle_Flame& OutFlame)
    {
        if (ck::IsValid(OutFlame))
        { return true; }

        const auto Want = _FloorTop + InOffset;
        for (auto Candidate : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), n"TAG_MarsFlameFixture"))
        {
            auto Flame = Candidate.As_Flame(ECk_SanityCheck::UnChecked);
            if (ck::Is_NOT_Valid(Flame))
            { continue; }

            const auto Location = Get_RootLocation(Candidate);
            if (FVector(Location.X - Want.X, Location.Y - Want.Y, 0.0).Size() > 5.0)
            { continue; }

            OutFlame = Flame;
            if (utils_net::Get_HasAuthority(Get_SubjectEntity()))
            { Track_ForCleanup(Candidate); }

            return true;
        }

        return false;
    }

    // Server: the flame item's body has linked its item and the carrier is ready.
    UFUNCTION()
    protected void Is_ServerItemLinked(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto WorldItem = _Rock.As_WorldItem(ECk_SanityCheck::UnChecked);
        auto Result = OutResult;
        Result.Set(ck::IsValid(WorldItem) && WorldItem.Get_IsLinked() && ck::IsValid(WorldItem.Get_HeldItem())
            && Get_IsCarrierReady(_Carrier));
    }

    // Server: the subject picks the flame item up (the authority's own caller).
    protected void PickUp_ServerItem()
    {
        auto WorldItem = _Rock.As_WorldItem();
        WorldItem.Request_PickUp(FMars_Request_WorldItem_PickUp(Get_SubjectEntity()));
    }

    // The subject holds an item of _HoldDefinition on this machine, its body Held on the subject, settled and composed
    // with a flame; the first time, that item and flame are the ones this machine knows.
    UFUNCTION()
    protected void Is_ItemHeld(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsItemHeld());
    }

    protected bool Get_IsItemHeld()
    {
        if (Get_IsCarrierReady(_Carrier) == false)
        { return false; }

        const auto Held = _Carrier.HeldItem.Get_CurrentItem();
        if (ck::Is_NOT_Valid(Held) || Held.Get_Definition() != _HoldDefinition || Held.Has_PersistentWorldItem() == false)
        { return false; }

        const auto Body = Held.Get_PersistentWorldItem();
        const auto Flame = Body.H().As_Flame(ECk_SanityCheck::UnChecked);
        const auto Ready = ck::IsValid(Flame) && Body.Get_Mount() == EMars_WorldItem_Mount::Held
            && Body.Get_Carrier() == Get_SubjectEntity() && Body.Get_IsSettled();
        if (Ready)
        {
            _HeldItem = Held;
            _HeldFlame = Flame;
        }

        return Ready;
    }

    // From now on, count what InFlame raises on this machine.
    protected void Watch_Signals(FCk_Handle_Flame InFlame)
    {
        _Watched = InFlame;
        _Watched.BindTo_OnLitChanged(FMars_Delegate_Flame_OnLitChanged(this, n"OnWatchedLitChanged"));
        _Watched.BindTo_OnMeasuresChanged(FMars_Delegate_Flame_OnMeasuresChanged(this, n"OnWatchedMeasuresChanged"));
    }

    UFUNCTION()
    protected void OnWatchedLitChanged(FCk_Handle_Flame InFlame, bool InIsLit)
    {
        _LitChanges += 1;
    }

    UFUNCTION()
    protected void OnWatchedMeasuresChanged(FCk_Handle_Flame InFlame, int32 InMeasuresLeft)
    {
        _MeasuresChanges += 1;
    }

    protected bool Get_IsBurningTagged(const FCk_Handle_Flame& InFlame) const
    {
        return InFlame.Has_Fragment(FMars_Tag_Flame_Burning);
    }

    protected int32 Get_NewEnsures() const
    {
        return utils_ensure::Get_EnsureCount() - _EnsuresAtStart;
    }
}
