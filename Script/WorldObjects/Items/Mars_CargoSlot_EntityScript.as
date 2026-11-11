// One cargo slot of a backpack: a lifetime child of the pack, attached under the pack root at the slot's mount, composing
// the whole slot on itself (utils_cargo_slot::Add) from the spec its pack keeps at Index. Spawned only by
// UMars_Processor_Backpack_SpawnSlots; a slot whose owner is no backpack, or whose index the pack's layout does not have,
// ensures and is destroyed. A client's copy can arrive before its pack has composed there: it then waits for the pack
// before it composes (Continue flow).
class UMars_CargoSlot_EntityScript : UCk_GenericEntityScript_UE
{
    // Stance A: replicates with its pack; the authority builds it and a client's request is the placeholder it resolves
    // to, so its inventory and refusal ledger replicate through a driver of its own. Its transform is local: every machine
    // attaches it under its own copy of the pack root.
    default _Replication = ECk_Replication::Replicates;

    UPROPERTY(ExposeOnSpawn)
    int32 Index = 0;

    private FCk_Handle _Self;
    private FCk_Handle_Timer _WaitTimer;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        _Self = InHandle;
        const auto Owner = utils_entity_lifetime::Get_LifetimeOwner(InHandle);
        if (ck::IsValid(Owner) && Owner.Is_Backpack())
        {
            Compose(InHandle);
            return ECk_EntityScript_ConstructionFlow::Finished;
        }

        if (ck::EnsureIfNot(utils_net::Get_HasAuthority(InHandle) == false,
            f"[CargoSlot] Slot [{Index}] [{InHandle.ToString()}] is under [{Owner.ToString()}], which is not a backpack: spawn "
            + "slots through utils_backpack::Add. Destroyed."))
        {
            utils_entity_lifetime::Request_DestroyEntity(InHandle);
            return ECk_EntityScript_ConstructionFlow::Finished;
        }

        _WaitTimer = utils_timer::Create_Tick(InHandle, FCk_Delegate_Timer(this, n"OnWaitForPack"));
        return ECk_EntityScript_ConstructionFlow::Continue;
    }

    // A client's copy: composes once its pack has; a pack that ends first takes the slot with it.
    UFUNCTION()
    private void OnWaitForPack(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Owner = utils_entity_lifetime::Get_LifetimeOwner(_Self);
        const auto PackComposed = ck::IsValid(Owner) && Owner.Is_Backpack();
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

    // False when the slot could not compose; it is then destroyed.
    private bool Compose(FCk_Handle& InHandle)
    {
        const auto Pack = utils_entity_lifetime::Get_LifetimeOwner(InHandle).As_Backpack();
        const auto MaybeSpec = Pack.TryGet_SlotSpec(Index);
        if (ck::EnsureIfNot(MaybeSpec.IsSet(),
            f"[CargoSlot] Slot [{Index}] [{InHandle.ToString()}] has no entry in the layout of its pack [{Pack.ToString()}]. Destroyed."))
        {
            utils_entity_lifetime::Request_DestroyEntity(InHandle);
            return false;
        }

        auto Spec = MaybeSpec.GetValue();
        Spec.Replication = _Replication;

        FCk_Handle PackEntity = Pack;
        auto PackRoot = PackEntity.As_Transform();
        const auto PackWorld = utils_transform::Get_EntityCurrentTransform(PackRoot);
        auto Root = utils_transform::Add(InHandle, Spec.MountOffset * PackWorld, ECk_Replication::DoesNotReplicate);
        utils_scene_node::Add(Root, PackRoot, Spec.MountOffset);
        utils_handle::Set_DebugName(InHandle, FName(f"Backpack.CargoSlot.{Index}"));
        utils_entity_tag::Add(InHandle, n"TAG_MarsCargoSlot");

        auto Slot = utils_cargo_slot::Add(InHandle, Spec);
        if (ck::Is_NOT_Valid(Slot))
        {
            utils_entity_lifetime::Request_DestroyEntity(InHandle);
            return false;
        }

        // The pack may already be Held when this slot composes: its claim applies from the start.
        auto Interactable = Slot.Get_Interactable();
        utils_backpack::Request_ApplyHolderHeld(Interactable, Spec.Backpack.Get_Mount());
        return true;
    }
}
