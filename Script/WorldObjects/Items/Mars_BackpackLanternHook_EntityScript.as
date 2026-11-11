// UMars_BackpackLanternHook_EntityScript's spawn params: the hook reads everything from its pack.
struct FMars_BackpackLanternHook_SpawnParams
{
    UPROPERTY()
    bool Requested = true;
}

// A backpack's lantern hook: a lifetime child of the pack (so it dies with the pack, and a lantern hung on it with it),
// attached under the pack root at the definition's LanternHookOffset, carrying the hook and its interactable; the lantern
// hangs by its bail. Spawned only by UMars_Backpack_EntityScript; a hook whose owner is no backpack with a hook offset
// ensures and is destroyed. Its interactable shares the cargo's HolderHeld claim. A client's copy can arrive before its
// pack has composed there: it then waits for the pack before it composes (Continue flow).
class UMars_BackpackLanternHook_EntityScript : UCk_GenericEntityScript_UE
{
    // Stance A: replicates with its pack; the authority builds it and a client's request is the placeholder it resolves
    // to, so the hook's inventory and refusal ledger replicate through a driver of its own. Its transform is local: every
    // machine attaches it under its own copy of the pack root, and a hung lantern mounts on each machine's own hook.
    default _Replication = ECk_Replication::Replicates;

    UPROPERTY(ExposeOnSpawn)
    bool Requested = true;

    private const float32 k_ProbeRadius = 14.0f;

    private FCk_Handle _Self;
    private FCk_Handle_Timer _WaitTimer;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        _Self = InHandle;
        const auto Owner = utils_entity_lifetime::Get_LifetimeOwner(InHandle);
        if (Get_IsPackComposed(Owner))
        {
            Compose(InHandle);
            return ECk_EntityScript_ConstructionFlow::Finished;
        }

        if (ck::EnsureIfNot(utils_net::Get_HasAuthority(InHandle) == false,
            f"[Backpack] Lantern hook [{InHandle.ToString()}] is under [{Owner.ToString()}], which is no backpack. Destroyed."))
        {
            utils_entity_lifetime::Request_DestroyEntity(InHandle);
            return ECk_EntityScript_ConstructionFlow::Finished;
        }

        _WaitTimer = utils_timer::Create_Tick(InHandle, FCk_Delegate_Timer(this, n"OnWaitForPack"));
        return ECk_EntityScript_ConstructionFlow::Continue;
    }

    // A client's copy: composes once its pack has; a pack that ends first takes the hook with it.
    UFUNCTION()
    private void OnWaitForPack(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Owner = utils_entity_lifetime::Get_LifetimeOwner(_Self);
        const auto PackComposed = Get_IsPackComposed(Owner);
        if (ck::IsValid(Owner) && PackComposed == false)
        { return; }

        utils_timer::UnbindFrom_OnUpdate(_WaitTimer, FCk_Delegate_Timer(this, n"OnWaitForPack"));
        utils_entity_lifetime::Request_DestroyEntity(_WaitTimer.H());
        _WaitTimer = FCk_Handle_Timer();

        if (PackComposed == false)
        {
            utils_entity_lifetime::Request_DestroyEntity(_Self);
            return;
        }

        if (Compose(_Self))
        { DoFinishConstruction(); }
    }

    private bool Get_IsPackComposed(const FCk_Handle& InOwner) const
    {
        return ck::IsValid(InOwner) && InOwner.Is_Backpack() && InOwner.Is_WorldItem();
    }

    // False when the hook could not compose; it is then destroyed.
    private bool Compose(FCk_Handle& InHandle)
    {
        const auto Owner = utils_entity_lifetime::Get_LifetimeOwner(InHandle);
        const auto PackItem = Owner.As_WorldItem();

        auto Offset = TOptional<FTransform>();
        const UCk_InventoryItem_Definition Definition = PackItem.Get_Definition();
        if (ck::IsValid(Definition))
        {
            const UMars_ItemTrait_Backpack Trait = Definition.Get_ItemTraitByClass(UMars_ItemTrait_Backpack);
            if (ck::IsValid(Trait))
            { Offset = Trait.LanternHookOffset; }
        }

        if (ck::EnsureIfNot(Offset.IsSet(),
            f"[Backpack] Lantern hook [{InHandle.ToString()}]: its pack [{Owner.ToString()}] has no definition naming a "
            + "LanternHookOffset. Destroyed."))
        {
            utils_entity_lifetime::Request_DestroyEntity(InHandle);
            return false;
        }

        auto PackRoot = Owner.As_Transform();
        const auto PackWorld = utils_transform::Get_EntityCurrentTransform(PackRoot);
        auto Root = utils_transform::Add(InHandle, Offset.GetValue() * PackWorld, ECk_Replication::DoesNotReplicate);
        utils_scene_node::Add(Root, PackRoot, Offset.GetValue());
        utils_handle::Set_DebugName(InHandle, n"Backpack.LanternHook");
        utils_entity_tag::Add(InHandle, n"TAG_MarsBackpackLanternHook");

        auto Probe = FMars_Interactable_ProbeInfo();
        Probe.ProbeSpec = FCk_Probe_Spec(GameplayTags::Probe_Mars_Interact);
        Probe.ProbeSpec.Set_MotionType(ECk_MotionType::Kinematic);
        Probe.ProbeShape = utils_shapes::Make_Sphere(FCk_ShapeSphere_Dimensions(k_ProbeRadius));
        Probe.ProbeOffset = FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, -k_ProbeRadius));

        auto InteractableSpec = FMars_Interactable_Spec();
        InteractableSpec.ProbeInfo = Probe;
        InteractableSpec.Targets.Add(utils_lantern_hook::Make_InteractTarget());
        InteractableSpec.FocusPriority = constants_lantern_hook::k_FocusPriority;

        auto Spec = FMars_LanternHook_Spec();
        Spec.HangNode = Root;
        Spec.HangOffset = FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, -constants_lantern_item::k_BailHeight));
        Spec.Interactable = utils_interactable::Create(Root, InteractableSpec);
        Spec.Replication = _Replication;

        auto Hook = utils_lantern_hook::Add(InHandle, Spec);
        if (ck::Is_NOT_Valid(Hook))
        {
            utils_entity_lifetime::Request_DestroyEntity(InHandle);
            return false;
        }

        // The pack may already be Held when this hook composes: its claim applies from the start.
        auto Interactable = Hook.Get_Interactable();
        utils_backpack::Request_ApplyHolderHeld(Interactable, PackItem.Get_Mount());
        return true;
    }
}
