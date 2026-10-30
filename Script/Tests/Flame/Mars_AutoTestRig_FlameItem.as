// A lantern whose tallow is down to one measure of four, so a test has room to refuel it. Otherwise Mars_ItemDef_Lantern.
asset Mars_TestItemDef_LowLantern of UCk_InventoryItem_Definition
{
    _CoreInfo = FCk_InventoryItem_CoreInfo(FText::FromString("Low Lantern"));

    auto Presentation = Cast<UMars_ItemTrait_Presentation>(NewObject(this, UMars_ItemTrait_Presentation));
    Presentation.Visual.Mesh = assets::CampLantern_Mars_SM();
    Presentation.Visual.MeshScale = FVector(constants_lantern_item::k_MeshScale, constants_lantern_item::k_MeshScale, constants_lantern_item::k_MeshScale);
    Presentation.Grip.Handedness = EMars_ItemPresentation_Handedness::OneHanded;
    Presentation.Mounting.Persistence = EMars_WorldItem_Persistence::Persistent;
    Presentation.Mounting.CarryPoint = GameplayTags::AttachPoint_Mars_Belt;
    Presentation.WorldItem.ScriptClass = UMars_Lantern_EntityScript;
    _ItemTraits.Add(Presentation);

    auto Fuel = FMars_Flame_Fuel();
    Fuel.StartMeasures = TOptional<int32>(1);

    auto Flame = Cast<UMars_ItemTrait_Flame>(NewObject(this, UMars_ItemTrait_Flame));
    Flame.Spec = mars_test_items::Make_LanternFlameSpec(Fuel);
    _ItemTraits.Add(Flame);

    auto Lantern = Cast<UMars_ItemTrait_Lantern>(NewObject(this, UMars_ItemTrait_Lantern));
    _ItemTraits.Add(Lantern);
}

namespace mars_test_items
{
    // Assets are file-local: other test files reach this one through here.
    UCk_InventoryItem_Definition LowLantern() { return Mars_TestItemDef_LowLantern; }

    // Mars_ItemDef_Lantern's flame (glass, self-lighting, lit on the belt, radii 800 / 800 / 800) burning InFuel.
    FMars_Flame_Spec Make_LanternFlameSpec(FMars_Flame_Fuel InFuel)
    {
        auto Spec = FMars_Flame_Spec();
        Spec.Fuel = TOptional<FMars_Flame_Fuel>(InFuel);
        Spec.Enclosure = EMars_Flame_Enclosure::Enclosed;
        Spec.Lighting = EMars_Flame_Lighting::SelfLighting;
        Spec.OnStow = EMars_Flame_OnStow::StaysLit;
        return Spec;
    }
}

// What a flame-item test spawns: a World-mode world item of Definition, as ScriptClass, at Location.
struct FMars_AutoTestHelper_FlameItemSpawn
{
    UCk_InventoryItem_Definition Definition;
    TSubclassOf<UMars_FlameItem_EntityScript> ScriptClass;
    FVector Location;

    FMars_AutoTestHelper_FlameItemSpawn() {}

    FMars_AutoTestHelper_FlameItemSpawn(UCk_InventoryItem_Definition InDefinition,
                                        TSubclassOf<UMars_FlameItem_EntityScript> InScriptClass,
                                        FVector InLocation)
    {
        Definition = InDefinition;
        ScriptClass = InScriptClass;
        Location = InLocation;
    }
}

// The flame-item tests' rig: the carrier rig (Hotbar, HeldItem, seeded holders) with a belt, plus one flame item spawned
// as its own world item, and the steps that stow it, light it and snuff it. Each test asserts channels no other test uses,
// since tests share the world's driver.
UCLASS(Abstract)
class UMars_AutoTestRig_FlameItem : UMars_AutoTestRig_Carrier
{
    default _TimeoutSeconds = 30.0f;

    // Mounts and body setup outrun the default poll budget at lane frame rate.
    protected const int32 k_SlowPolls = 900;
    // A held-and-lit wait this long reports the flame's state and fails.
    private const int32 k_StatePolls = 360;

    protected FCk_Handle_WorldItem _FlameItem;
    // The flame's item, recorded by Check_FlameReady (its world item's holder empties once it is stowed).
    private FCk_Handle_Item _FlameItemItem;
    private int32 _HeldPolls = 0;

    // The test entity is the carrier, rooted at InLocation, with a Hand and a Belt node published as AttachPoint.Mars.Hand
    // and AttachPoint.Mars.Belt (a carried flame's carry point), as the player's are.
    protected void Add_CarrierBodyWithBelt(FCk_Handle InHandle, FVector InLocation)
    {
        auto Body = FMars_AutoTestHelper_CarrierBody(InLocation);
        Body.ExtraPoints.Add(FMars_AutoTestHelper_CarrierPoint(GameplayTags::AttachPoint_Mars_Belt, FVector(10.0, 20.0, 0.0)));

        _Carrier = InHandle;
        _HandNode = Build_CarrierBody(_Carrier, Body).Hand;
    }

    // _FlameItem once it is constructed.
    protected void SpawnFlameItem(FCk_Handle InHandle, FMars_AutoTestHelper_FlameItemSpawn InSpawn)
    {
        auto SpawnParams = UMars_WorldItem_EntityScript::Params();
        SpawnParams.Definition = InSpawn.Definition;
        SpawnParams.Mode = EMars_WorldItem_Mode::World;
        SpawnParams.SpawnTransform = FTransform(FRotator::ZeroRotator, InSpawn.Location);

        auto Pending = utils_entity_script::Request_SpawnEntity(InHandle, InSpawn.ScriptClass, SpawnParams);
        utils_pending_entity_script::Promise_OnConstructed(Pending, FCk_Delegate_EntityScript_Constructed(this, n"OnFlameItemConstructed"));
    }

    // A lantern of InDefinition (UMars_Lantern_EntityScript) at InLocation.
    protected void SpawnLantern(FCk_Handle InHandle, UCk_InventoryItem_Definition InDefinition, FVector InLocation)
    {
        SpawnFlameItem(InHandle, FMars_AutoTestHelper_FlameItemSpawn(InDefinition, UMars_Lantern_EntityScript, InLocation));
    }

    UFUNCTION()
    private void OnFlameItemConstructed(FCk_Handle_EntityScript InEntityScriptHandle)
    {
        _FlameItem = InEntityScriptHandle.As_WorldItem();
    }

    protected FCk_Handle_Flame Get_Flame() const
    {
        return _FlameItem.H().As_Flame(ECk_SanityCheck::UnChecked);
    }

    protected FCk_Handle_Item Get_FlameItem() const
    {
        return _FlameItemItem;
    }

    protected FMars_Fragment_Flame Get_FlameState() const
    {
        return Get_Flame().Get_Fragment(FMars_Fragment_Flame);
    }

    // The flame world item is constructed, composed the Flame feature and its holder holds its item.
    UFUNCTION()
    protected void Check_FlameReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsFlameReady());
    }

    // The flame world item is composed and seeded; records its item the first time it holds.
    protected bool Get_IsFlameReady()
    {
        const auto Ready = ck::IsValid(_FlameItem) && ck::IsValid(Get_Flame()) && ck::IsValid(_FlameItem.Get_HeldItem());
        if (Ready && ck::Is_NOT_Valid(_FlameItemItem))
        { _FlameItemItem = _FlameItem.Get_HeldItem(); }

        return Ready || ck::IsValid(_FlameItemItem);
    }

    // What the pickup task does for a Persistent item: the flame item's holder -> the hotbar's stow target.
    UFUNCTION()
    protected void Step_StowFlame(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Item = Get_FlameItem();
        auto Target = _Hotbar.TryGet_StowTarget(Item);
        if (ck::Is_NOT_Valid(Target))
        {
            FinishFailure("stow precondition: the flame item has a stow target");
            return;
        }

        auto Holder = _FlameItem.Get_Holder();
        Holder.Request_TransferItem_ToDataOnly(FCk_Request_Inventory_TransferItem_ToDataOnly(Item, Target),
            FCk_Delegate_Inventory_OnOperationResult_Transfer());
    }

    UFUNCTION()
    protected void Step_Light(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Flame = Get_Flame();
        Flame.Request_SetIgnition(FMars_Request_Flame_SetIgnition(EMars_Flame_Ignition::Lit));
    }

    UFUNCTION()
    protected void Step_Snuff(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Flame = Get_Flame();
        Flame.Request_SetIgnition(FMars_Request_Flame_SetIgnition(EMars_Flame_Ignition::Snuffed));
    }

    // Held on the carrier's Hand node, lit, its Held light probe shown. Fails with the flame's state past k_StatePolls.
    UFUNCTION()
    protected void Check_FlameHeldAndLit(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Flame = Get_Flame();
        const auto Shown = Flame.Get_ShownLightPool();
        const auto Held = _HeldItem.Get_CurrentItem() == Get_FlameItem() && _FlameItem.Get_Mount() == EMars_WorldItem_Mount::Held;
        const auto Ok = Held && Flame.Get_IsLit() && Shown.IsSet() && Shown.GetValue() == EMars_Flame_Pool::Held;

        ++_HeldPolls;
        if (Ok)
        { _HeldPolls = 0; }
        else if (_HeldPolls == k_StatePolls)
        { FinishFailure(f"the flame never reached the hand lit: {Get_FlameStateText()}"); }

        auto Res = OutResult;
        Res.Set(Ok);
    }

    protected FString Get_FlameStateText() const
    {
        const auto Flame = Get_Flame();
        const auto Shown = Flame.Get_ShownLightPool();
        const auto ShownText = Shown.IsSet() ? f"{Shown.GetValue() :n}" : "none";
        const auto HeldNow = _HeldItem.Get_CurrentItem();
        return f"held item [{HeldNow.ToString()}] vs flame item [{Get_FlameItem().ToString()}], selected [{_Hotbar.Get_SelectedIndex().IsSet()}], mount [{_FlameItem.Get_Mount() :n}], target mount [{_FlameItem.Get_TargetMount() :n}], lit [{Flame.Get_IsLit()}], ignition [{Flame.Get_Ignition() :n}], measures [{Flame.Get_MeasuresLeft()}], pool [{Flame.Get_LightPool() :n}], shown [{ShownText}], has probes [{Flame.Has_Fragment(FMars_Fragment_Flame_LightProbes)}]";
    }

    // InPool's probe is the shown one and the only enabled one among InFlame's probes.
    protected bool Get_OnlyProbeEnabled(EMars_Flame_Pool InPool) const
    {
        const auto Flame = Get_Flame();
        const auto Shown = Flame.Get_ShownLightPool();
        if (Shown.IsSet() == false || Shown.GetValue() != InPool)
        { return false; }

        auto Pools = TArray<EMars_Flame_Pool>();
        Pools.Add(EMars_Flame_Pool::Held);
        Pools.Add(EMars_Flame_Pool::Stowed);
        Pools.Add(EMars_Flame_Pool::World);
        for (const auto Pool : Pools)
        {
            const auto Probe = Flame.Get_LightProbe(Pool);
            if (ck::Is_NOT_Valid(Probe))
            {
                if (Pool == InPool)
                { return false; }

                continue;
            }

            const auto Want = Pool == InPool ? ECk_EnableDisable::Enable : ECk_EnableDisable::Disable;
            if (utils_probe::Get_IsEnabledDisabled(Probe) != Want)
            { return false; }
        }

        return true;
    }
}
