// A lantern whose tallow is down to one measure of four, so a hook test has room to refuel it. Otherwise Mars_ItemDef_Lantern.
asset Mars_TestItemDef_LowLantern of UCk_InventoryItem_Definition
{
    _CoreInfo = FCk_InventoryItem_CoreInfo(FText::FromString("Low Lantern"));

    auto Presentation = Cast<UMars_ItemTrait_Presentation>(NewObject(this, UMars_ItemTrait_Presentation));
    Presentation.Visual.Mesh = assets::CampLantern_Mars_SM();
    Presentation.Visual.MeshScale = FVector(constants_lantern_item::k_MeshScale, constants_lantern_item::k_MeshScale, constants_lantern_item::k_MeshScale);
    Presentation.Grip.Handedness = EMars_ItemPresentation_Handedness::OneHanded;
    Presentation.Mounting.Persistence = EMars_WorldItem_Persistence::Persistent;
    Presentation.Mounting.CarryPoint = constants_lantern_item::Get_BeltPoint();
    Presentation.WorldItem.ScriptClass = UMars_Lantern_EntityScript;
    _ItemTraits.Add(Presentation);

    auto Lantern = Cast<UMars_ItemTrait_Lantern>(NewObject(this, UMars_ItemTrait_Lantern));
    Lantern.Spec.StartMeasures = TOptional<int32>(1);
    _ItemTraits.Add(Lantern);
}

namespace mars_test_items
{
    // Assets are file-local: other test files reach this one through here.
    UCk_InventoryItem_Definition LowLantern() { return Mars_TestItemDef_LowLantern; }
}

// The lantern-hook tests' rig: the carrier rig (Hotbar, HeldItem, seeded holders) plus hooks built from the kernel the way
// UMars_LanternSconce_EntityScript composes them - a root, a hang node, an interactable with the hook's target, the hook
// and an optional source - without its meshes, and lanterns spawned as their own world items (UMars_Lantern_EntityScript).
// Each test asserts channels no other test uses, since tests share the world's driver.
UCLASS(Abstract)
class UMars_AutoTestRig_LanternHook : UMars_AutoTestRig_Carrier
{
    default _TimeoutSeconds = 30.0f;

    protected FCk_Handle_LanternHook _Hook;
    protected FCk_Handle_WorldItem _LanternItem;
    // The lantern's item, recorded by Check_LanternReady (its world item's holder empties once it is stowed).
    private FCk_Handle_Item _LanternItemItem;

    // The test entity is the carrier, rooted at InLocation, with a Hand and a Belt node published as AttachPoint.Mars.Hand
    // and AttachPoint.Mars.Belt (the lantern's carry point), as the player's are.
    protected void Add_CarrierBodyWithBelt(FCk_Handle InHandle, FVector InLocation)
    {
        _Carrier = InHandle;
        auto Root = utils_transform::Add(_Carrier, FTransform(FRotator::ZeroRotator, InLocation), ECk_Replication::DoesNotReplicate);

        _HandNode = utils_scene_node::Create(Root, FTransform(FRotator::ZeroRotator, FVector(40.0, 20.0, 60.0))).As_Transform();
        auto BeltNode = utils_scene_node::Create(Root, FTransform(FRotator::ZeroRotator, FVector(10.0, 20.0, 0.0))).As_Transform();

        auto AttachPointsSpec = FMars_AttachPoints_Spec();
        AttachPointsSpec.Points.Add(FMars_AttachPoint_Entry(GameplayTags::AttachPoint_Mars_Hand, _HandNode));
        AttachPointsSpec.Points.Add(FMars_AttachPoint_Entry(constants_lantern_item::Get_BeltPoint(), BeltNode));
        utils_attach_points::Add(_Carrier, AttachPointsSpec);
    }

    // A hook at InLocation whose source asserts InChannel (unset = no source).
    protected FCk_Handle_LanternHook MakeHook(FCk_Handle InHandle, FVector InLocation, FGameplayTag InChannel)
    {
        auto HookEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto Root = utils_transform::Add(HookEntity, FTransform(FRotator::ZeroRotator, InLocation), ECk_Replication::DoesNotReplicate);
        auto HangNode = utils_scene_node::Create(Root, FTransform(FRotator::ZeroRotator, FVector(30.0, 0.0, 0.0))).As_Transform();

        auto Probe = FMars_Interactable_ProbeInfo();
        Probe.ProbeSpec = FCk_Probe_Spec(GameplayTags::Probe_Mars_Interact);
        Probe.ProbeShape = utils_shapes::Make_Box(FCk_ShapeBox_Dimensions(FVector(14.0, 14.0, 22.0)));

        auto InteractableSpec = FMars_Interactable_Spec();
        InteractableSpec.ProbeInfo = Probe;
        InteractableSpec.Targets.Add(utils_lantern_hook::Make_InteractTarget());

        auto Spec = FMars_LanternHook_Spec();
        Spec.HangNode = HangNode;
        Spec.HangOffset = FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, -constants_lantern_item::k_BailHeight));
        Spec.Interactable = utils_interactable::Create(Root, InteractableSpec);

        FCk_Handle HookHandle = HookEntity;
        auto Hook = utils_lantern_hook::Add(HookHandle, Spec);

        if (InChannel.IsValid())
        {
            auto SourceSpec = FMars_MechanismSource_Spec();
            SourceSpec.OutputChannel = InChannel;
            utils_mechanism_source::Add(HookHandle, SourceSpec);
        }

        return Hook;
    }

    // A World-mode lantern world item of InDefinition at InLocation; _LanternItem once it is constructed.
    protected void SpawnLantern(FCk_Handle InHandle, UCk_InventoryItem_Definition InDefinition, FVector InLocation)
    {
        auto SpawnParams = UMars_Lantern_EntityScript::Params();
        SpawnParams.Definition = InDefinition;
        SpawnParams.Mode = EMars_WorldItem_Mode::World;
        SpawnParams.SpawnTransform = FTransform(FRotator::ZeroRotator, InLocation);

        auto Pending = utils_entity_script::Request_SpawnEntity(InHandle, UMars_Lantern_EntityScript, SpawnParams);
        utils_pending_entity_script::Promise_OnConstructed(Pending, FCk_Delegate_EntityScript_Constructed(this, n"OnLanternConstructed"));
    }

    UFUNCTION()
    private void OnLanternConstructed(FCk_Handle_EntityScript InEntityScriptHandle)
    {
        _LanternItem = InEntityScriptHandle.As_WorldItem();
    }

    protected FCk_Handle_Lantern Get_Lantern() const
    {
        return _LanternItem.H().As_Lantern(ECk_SanityCheck::UnChecked);
    }

    protected FCk_Handle_Item Get_LanternItem() const
    {
        return _LanternItemItem;
    }

    // InHook's source is asserted; false when it has none.
    protected bool Get_IsSourceAsserted(const FCk_Handle_LanternHook& InHook) const
    {
        const auto Source = InHook.As_MechanismSource(ECk_SanityCheck::UnChecked);
        return ck::IsValid(Source) && Source.Get_IsAsserted();
    }

    // The lantern world item is constructed, composed the Lantern feature and its holder holds its item.
    UFUNCTION()
    protected void Check_LanternReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsLanternReady());
    }

    // The lantern world item is composed and seeded; records its item the first time it holds.
    protected bool Get_IsLanternReady()
    {
        const auto Ready = ck::IsValid(_LanternItem) && ck::IsValid(Get_Lantern()) && ck::IsValid(_LanternItem.Get_HeldItem());
        if (Ready && ck::Is_NOT_Valid(_LanternItemItem))
        { _LanternItemItem = _LanternItem.Get_HeldItem(); }

        return Ready || ck::IsValid(_LanternItemItem);
    }

    // What the pickup task does for a Persistent item: the lantern's holder -> the hotbar's stow target.
    UFUNCTION()
    protected void Step_StowLantern(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Item = Get_LanternItem();
        auto Target = _Hotbar.TryGet_StowTarget(Item);
        if (ck::Is_NOT_Valid(Target))
        {
            FinishFailure("stow precondition: the lantern has a stow target");
            return;
        }

        auto Holder = _LanternItem.Get_Holder();
        Holder.Request_TransferItem_ToDataOnly(FCk_Request_Inventory_TransferItem_ToDataOnly(Item, Target),
            FCk_Delegate_Inventory_OnOperationResult_Transfer());
    }

    UFUNCTION()
    protected void Step_OpenShutter(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Lantern = Get_Lantern();
        Lantern.Request_SetShutter(FMars_Request_Lantern_SetShutter(EMars_Lantern_Shutter::Open));
    }

    UFUNCTION()
    protected void Step_CloseShutter(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Lantern = Get_Lantern();
        Lantern.Request_SetShutter(FMars_Request_Lantern_SetShutter(EMars_Lantern_Shutter::Shuttered));
    }

    // Mounts and body setup outrun the default poll budget at lane frame rate.
    protected const int32 k_SlowPolls = 900;
    // A held-and-lit wait this long reports the lantern's state and fails.
    private const int32 k_StatePolls = 360;
    private int32 _HeldPolls = 0;

    // Held on the carrier's Hand node, lit, its Held light probe shown. Fails with the lantern's state past k_SlowPolls.
    UFUNCTION()
    protected void Check_LanternHeldAndLit(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Lantern = Get_Lantern();
        const auto Shown = Lantern.Get_ShownLightPool();
        const auto Held = _HeldItem.Get_CurrentItem() == Get_LanternItem() && _LanternItem.Get_Mount() == EMars_WorldItem_Mount::Held;
        const auto Ok = Held && Lantern.Get_IsLit() && Shown.IsSet() && Shown.GetValue() == EMars_Lantern_Pool::Held;

        ++_HeldPolls;
        if (Ok)
        { _HeldPolls = 0; }
        else if (_HeldPolls == k_StatePolls)
        { FinishFailure(f"the lantern never reached the hand lit: {Get_LanternState()}"); }

        auto Res = OutResult;
        Res.Set(Ok);
    }

    protected FString Get_LanternState() const
    {
        const auto Lantern = Get_Lantern();
        const auto Shown = Lantern.Get_ShownLightPool();
        const auto ShownText = Shown.IsSet() ? f"{Shown.GetValue() :n}" : "none";
        const auto HeldNow = _HeldItem.Get_CurrentItem();
        return f"held item [{HeldNow.ToString()}] vs lantern item [{Get_LanternItem().ToString()}], selected [{_Hotbar.Get_SelectedIndex().IsSet()}], mount [{_LanternItem.Get_Mount() :n}], target mount [{_LanternItem.Get_TargetMount() :n}], lit [{Lantern.Get_IsLit()}], shutter [{Lantern.Get_Shutter() :n}], measures [{Lantern.Get_MeasuresLeft()}], pool [{Lantern.Get_LightPool() :n}], shown [{ShownText}], has probes [{Lantern.Has_Fragment(FMars_Fragment_Lantern_LightProbes)}]";
    }

    UFUNCTION()
    protected void Step_Hang(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Action = _Hook.Get_ActionFor(_Carrier);
        Assert_True(Action == EMars_LanternHook_Action::Hang, f"a carrier holding a lantern reads Hang on an empty hook (got [{Action :n}])");
        _Hook.Request_Hang(FMars_Request_LanternHook_Hang(Get_LanternItem()));
    }

    // On the hook, settled on it, Carried by the hook entity.
    UFUNCTION()
    protected void Check_Hung(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Hook.Get_Item() == Get_LanternItem() && _Hook.Get_HasArrived());
    }
}
