// An interaction state that replaces UMars_SmState_InteractTarget_Enter: it runs TaskClass and ends the interaction with
// the tasks' outcome (a WhileLive target's live interaction ends with it; an AfterCompletion one had ended already).
// Subclasses only set TaskClass.
UCLASS(Abstract)
class UMars_SmState_InteractTarget_RunTask : UCk_SmState_EntityScript
{
    protected TSubclassOf<UCk_SmTask_EntityScript> TaskClass;

    UFUNCTION(BlueprintOverride)
    TArray<FGameplayTag> DoGet_StatesToOverride() const
    {
        return GameplayTag::MakeGameplayTagArrayFromTag(
            UCk_SmState_EntityScript::Get_StateTagForClass(UMars_SmState_InteractTarget_Enter));
    }

    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        AddTask(InHandle, TaskClass);

        auto OnSuccess = AddTransition(InHandle, UMars_SmState_InteractTarget_Succeeded);
        AddCondition(OnSuccess, UMars_SmCondition_AllTasksSucceeded);

        auto OnFailure = AddTransition(InHandle, UMars_SmState_InteractTarget_Failed);
        AddCondition(OnFailure, UMars_SmCondition_AnyTaskFailed);
    }
}

// What picking up a World-mode item does: stow it into the initiator's hotbar.
class UMars_SmState_WorldItem_PickUp : UMars_SmState_InteractTarget_RunTask
{
    default TaskClass = UMars_SmTask_WorldItem_StowIntoInitiator;
}

// The base of every interaction task that moves an item at the gloves' Grip (UMars_SmTask_ActAtGrip): a pickup, a lock,
// a cargo slot, a hook, a dock. It answers the two questions those share so no task answers them its own way: where the
// moving item visually is (the pose a container's next visual of it arrives from), and how an item taken into the hand
// rides the gloves home, the same for an item whose body is its own Persistent world item and for one whose held visual
// is spawned for it.
UCLASS(Abstract)
class UMars_SmTask_MoveItemAtGrip : UMars_SmTask_ActAtGrip
{
    // Where InInitiator's held item visually is now: its held visual's root, else the hand attach point.
    protected FTransform Get_HeldVisualWorld(FCk_Handle InInitiator) const
    {
        auto HeldItem = InInitiator.As_HeldItem();
        return utils_world_item::Get_WorldOf(HeldItem.Get_PresentationEntity(), HeldItem.Get_HandAttachPoint());
    }

    // InItem, taken at this task's Grip and bound for InInitiator's hand, rides the gloves home from InFromWorld: still for
    // what is left of their Grip, then over their return (TryGet_RideHome). A Persistent item's own body arrives on its
    // next mount with that timing; any other item's next held visual starts at InFromWorld and arrives with it. Gloves that
    // are not gripping (none, a refused reach): the held visual still starts at InFromWorld and arrives on its Presentation's
    // ArriveSeconds; a body arrives as its mount does.
    protected void Ride_IntoHand(FCk_Handle InInitiator, FCk_Handle_Item InItem, const FTransform& InFromWorld)
    {
        const auto Ride = TryGet_RideHome();
        if (InItem.Has_PersistentWorldItem())
        {
            auto WorldItem = InItem.Get_PersistentWorldItem();
            if (Ride.IsSet() && ck::IsValid(WorldItem))
            { WorldItem.Request_ArriveNextMount(FMars_Request_WorldItem_ArriveNextMount(Ride.GetValue())); }

            return;
        }

        auto HeldItem = InInitiator.As_HeldItem(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(HeldItem))
        { return; }

        HeldItem.Request_SetNextArrival(FMars_Request_HeldItem_SetNextArrival(InItem, InFromWorld, Ride));
    }
}

// Stows the world item's held item into the initiator's hotbar at the Grip of the initiator's gloves on it
// (UMars_SmTask_ActAtGrip: at once without gloves, or when they do not reach for it): the item leaves the floor when the
// gloves close on it, never before they get there. The task runs on the initiating machine; the stow is the authority's,
// so at the Grip it fires Cue.Mars.WorldItem.PickUp at the world item's root and waits for the effect to replicate back
// (the holder empty, or the world item gone) or for the authority's refusal (FMars_Fragment_WorldItem_Net naming this
// initiator), which fails it with that reason. On the listen host and in standalone the cue runs the same frame. A
// Transient world item destroys itself once its holder empties; a Persistent one mounts on the initiator from where its
// item lands (UMars_Processor_WorldItem_Reconcile), riding the gloves home when they took it. A full hotbar fails (the
// pickup is normally disabled before it gets here); so do gloves that return or lose it before their Grip.
// Interim (until the hotbar replicates): a client's pickup leaves the floor on every machine, but the item lands in that
// chef's hotbar on the host only, so the client's own hotbar stays empty; its local stow check reads that empty copy.
class UMars_SmTask_WorldItem_StowIntoInitiator : UMars_SmTask_MoveItemAtGrip
{
    private FCk_Handle _Initiator;
    private FCk_Handle_WorldItem _WorldItem;
    // The world item's refusal serial when this task fired its cue: only a later refusal is about it.
    private int32 _RefusalSerialAtCue = 0;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        _Outcome = ECk_SmTaskResult::Running;
        _Initiator = FCk_Handle();
        _WorldItem = FCk_Handle_WorldItem();

        FCk_Handle Owner;
        FCk_Handle Initiator;
        if (TryGet_InteractionEnds(Owner, Initiator) == false)
        { return; }

        // The pickup state runs only on a world item's own target, for an initiator that stows into a hotbar.
        auto WorldItem = Owner.As_WorldItem(ECk_SanityCheck::UnChecked);
        auto Hotbar = Initiator.As_Hotbar(ECk_SanityCheck::UnChecked);
        if (ck::EnsureIfNot(ck::IsValid(WorldItem) && ck::IsValid(Hotbar),
            f"[WorldItem] Pickup ran for world item [{WorldItem.ToString()}] and hotbar [{Hotbar.ToString()}]: one is invalid"))
        {
            _Outcome = ECk_SmTaskResult::Failed;
            return;
        }

        auto Item = WorldItem.Get_HeldItem();
        if (ck::Is_NOT_Valid(Item) || ck::Is_NOT_Valid(Hotbar.TryGet_StowTarget(Item)))
        {
            DoFail(EMars_Interaction_FailReason::NowhereToStow);
            return;
        }

        _Initiator = Initiator;
        _WorldItem = WorldItem;
        Await_Grip(Initiator);
    }

    // The hotbar is asked again: its slots may have changed while the gloves reached.
    protected void DoAtGrip() override
    {
        auto Item = _WorldItem.Get_HeldItem();
        const auto Hotbar = _Initiator.As_Hotbar(ECk_SanityCheck::UnChecked);
        auto Target = ck::IsValid(Hotbar) ? Hotbar.TryGet_StowTarget(Item) : FCk_Handle_Inventory_DataOnly();
        if (ck::Is_NOT_Valid(Item) || ck::Is_NOT_Valid(Target))
        {
            DoFail(EMars_Interaction_FailReason::NowhereToStow);
            return;
        }

        // Taken at the grip, the item rides the gloves home from where it lies (a Persistent body on its next mount; a held
        // visual from here, unless the gloves' own carry already starts it there - the carry wins).
        FCk_Handle LyingEntity = _WorldItem;
        Ride_IntoHand(_Initiator, Item, utils_transform::Get_EntityCurrentTransform(LyingEntity.As_Transform()));

        _RefusalSerialAtCue = _WorldItem.Get_RefusalSerial();
        utils_cue_generic::Request_ExecuteCue(_WorldItem, GameplayTags::Cue_Mars_WorldItem_PickUp,
            FMars_Request_WorldItem_PickUp(_Initiator), ECk_Cue_ReliabilityPolicy::Reliable, ECk_Cue_MulticastPolicy::ServerOnly);
        Await_ReplicatedEffect();
    }

    // A stowed Transient item's world item ends; a Persistent one's holder empties and it stays as the item's body.
    protected bool DoGet_EffectLanded() override
    {
        if (ck::Is_NOT_Valid(_WorldItem))
        { return true; }

        auto Holder = _WorldItem.Get_Holder();
        return ck::Is_NOT_Valid(Holder) || Holder.Get_NumItems() == 0;
    }

    protected bool DoTryGet_Refusal(EMars_Interaction_FailReason& OutReason) override
    {
        if (ck::Is_NOT_Valid(_WorldItem) || _WorldItem.Get_RefusalSerial() <= _RefusalSerialAtCue)
        { return false; }

        if (_WorldItem.Get_LastRefused() != _Initiator)
        { return false; }

        OutReason = _WorldItem.Get_LastRefusal();
        return true;
    }
}
