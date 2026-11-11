// Stateless accept predicate for every cargo slot inventory, bound from the CDO (the Hotbar policy's shape).
UCLASS()
class UMars_CargoSlot_AcceptPolicy : UObject
{
    UFUNCTION()
    void OnCanAccept(FCk_Handle_Inventory InInventory, FCk_Handle_Item InItem, bool& OutCanAccept)
    { OutCanAccept = utils_cargo_slot::Get_CanAccept(InItem); }
}

namespace utils_cargo_slot
{
    // The slot on InHandle, an entity with a transform already placed at its mount (the slot's script attaches it under
    // the pack root): a capacity-1 Inventory.Mars.Cargo.<Index> inventory (accept policy CDO, InSpec.Replication) whose
    // Persistent item rides the slot's node at its CargoOffset, the slot's replicated refusal ledger, and a probe
    // interactable with one Use target running UMars_SmState_CargoSlot_Interact. A spec that fails Validate() ensures and
    // adds nothing.
    FCk_Handle_CargoSlot Add(FCk_Handle& InHandle, FMars_CargoSlot_Spec InSpec)
    {
        const auto Validation = InSpec.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[CargoSlot] [{InHandle.ToString()}] rejected the spec: {Validation.Get_Error()}"))
        { return FCk_Handle_CargoSlot(); }

        auto SlotNode = InHandle.As_Transform();

        TSubclassOf<UMars_CargoSlot_AcceptPolicy> PolicyClass = UMars_CargoSlot_AcceptPolicy;
        auto Policy = PolicyClass.GetDefaultObject();

        auto InventoryParams = utils_inventory_data_only::Make_Params_Bounded(
            utils_gameplay_tag::ResolveGameplayTag(FName(f"Inventory.Mars.Cargo.{InSpec.Index}")), 1,
            FCk_Delegate_Inventory_CustomCanAcceptItem_Dynamic(Policy, n"OnCanAccept"),
            FCk_Delegate_Inventory_CustomCanStackItems_Dynamic());
        InventoryParams.Set_StackingPolicy(ECk_Inventory_StackingPolicy::NoStacking);
        InventoryParams.Set_PersistContents(ECk_EnableDisable::Disable);

        auto Inventory = utils_inventory_data_only::Add(InHandle, InventoryParams, InSpec.Replication);
        utils_world_item::Add_MountedInventory(Inventory, FMars_Fragment_MountedInventory(EMars_WorldItem_MountRule::PointAtCargoOffset,
            constants_cargo_slot::Get_MountPoint(), FTransform::Identity));

        auto AttachPointsSpec = FMars_AttachPoints_Spec();
        AttachPointsSpec.Points.Add(FMars_AttachPoint_Entry(constants_cargo_slot::Get_MountPoint(), SlotNode));
        utils_attach_points::Add(InHandle, AttachPointsSpec);

        auto Params = FMars_Fragment_CargoSlot_Params();
        Params.Index = InSpec.Index;
        Params.Backpack = InSpec.Backpack;

        auto State = FMars_Fragment_CargoSlot();
        State.Inventory = Inventory;
        State.Interactable = DoCreate_Interactable(SlotNode, InSpec);

        InHandle.Add_Fragment(FMars_Feature_CargoSlot());
        InHandle.Add_Fragment(Params);
        InHandle.Add_Fragment(State);

        // A client's copy can receive the replicated ledger before it composes: it is already there then.
        if (InHandle.Has_Fragment(FMars_Fragment_CargoSlot_Net) == false)
        { InHandle.Add_Fragment(FMars_Fragment_CargoSlot_Net(), ECk_Replication::Replicates); }

        return InHandle.As_CargoSlot();
    }

    // InInitiator's interaction asks InSlot for InAction. A slot with a replication driver is reached through
    // Cue.Mars.CargoSlot.Act, which only its authority applies; a local slot has no other machine to reach and takes the
    // Act request directly. Either way the effect, or the refusal in the slot's ledger, is what the caller waits on.
    void Request_ActFor(FCk_Handle_CargoSlot& InSlot, FCk_Handle InInitiator, EMars_CargoSlot_Action InAction)
    {
        const auto Request = FMars_Request_CargoSlot_Act(InInitiator, InAction);
        if (utils_entity_replication_driver::Has(InSlot))
        {
            utils_cue_generic::Request_ExecuteCue(InSlot, GameplayTags::Cue_Mars_CargoSlot_Act, Request,
                ECk_Cue_ReliabilityPolicy::Reliable, ECk_Cue_MulticastPolicy::ServerOnly);
            return;
        }

        InSlot.Request_Act(Request);
    }

    // The accept rule every cargo slot enforces (and Get_ActionFor previews): no backpack, no hands-only item, and no
    // Persistent item but a food (its own world item rides the slot's node).
    bool Get_CanAccept(const FCk_Handle_Item& InItem)
    {
        if (ck::Is_NOT_Valid(InItem) || InItem.Has_Backpack() || InItem.Has_HandsOnly())
        { return false; }

        return Get_IsPersistent(InItem) == false || InItem.Has_Food();
    }

    // InItem's definition gives it a Persistent world item. Read from the presentation, which every machine has the same,
    // rather than from the body's link, which a client makes only once the body has arrived.
    bool Get_IsPersistent(const FCk_Handle_Item& InItem)
    {
        if (ck::Is_NOT_Valid(InItem) || InItem.Has_Presentation() == false)
        { return false; }

        const UMars_ItemTrait_Presentation Presentation = InItem.Get_Presentation();
        return Presentation.Mounting.Persistence == EMars_WorldItem_Persistence::Persistent;
    }

    // The probe carries Probe.Mars.Interact (the player's interaction trace only sees probes under that tag) and is
    // Kinematic: it follows the pack. The spec's prompt is a placeholder until the slot's prompt processor
    // (UMars_Processor_CargoSlot_Prompt) words the focuser's action. The target is WhileLive: a stow or a take lives until
    // the slot reports it.
    FCk_Handle_Interactable DoCreate_Interactable(FCk_Handle_Transform& InSlotNode, const FMars_CargoSlot_Spec& InSpec)
    {
        auto Probe = FMars_Interactable_ProbeInfo();
        Probe.ProbeSpec = FCk_Probe_Spec(GameplayTags::Probe_Mars_Interact);
        Probe.ProbeSpec.Set_MotionType(ECk_MotionType::Kinematic);
        Probe.ProbeShape = utils_shapes::Make_Sphere(FCk_ShapeSphere_Dimensions(InSpec.ProbeRadius));
        Probe.ProbeOffset = FTransform::Identity;

        auto TargetSpec = FCk_InteractTarget_Spec(GameplayTags::InteractionChannel_Mars_Use);

        auto Target = FMars_Interactable_TargetEntry();
        Target.InteractTargetSpec = TargetSpec;
        Target.InteractPromptSpec = InSpec.Prompt;
        Target.InteractionStateClass = UMars_SmState_CargoSlot_Interact;
        Target.Work = EMars_Interactable_Work::WhileLive;

        auto Spec = FMars_Interactable_Spec();
        Spec.ProbeInfo = Probe;
        Spec.Targets.Add(Target);
        Spec.FocusPriority = constants_cargo_slot::k_FocusPriority;

        return utils_interactable::Create(InSlotNode, Spec);
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

mixin FCk_Handle_WorldItem Get_Backpack(const FCk_Handle_CargoSlot& Self)
{
    return Self.Get_Fragment(FMars_Fragment_CargoSlot_Params).Backpack;
}

mixin int32 Get_Index(const FCk_Handle_CargoSlot& Self)
{
    return Self.Get_Fragment(FMars_Fragment_CargoSlot_Params).Index;
}

mixin FCk_Handle_Inventory_DataOnly Get_Inventory(const FCk_Handle_CargoSlot& Self)
{
    return Self.Get_Fragment(FMars_Fragment_CargoSlot).Inventory;
}

// Invalid while the slot is empty.
mixin FCk_Handle_Item Get_Item(const FCk_Handle_CargoSlot& Self)
{
    const auto Inventory = Self.Get_Inventory();
    return Inventory.Get_SoleItem();
}

mixin bool Get_IsOccupied(const FCk_Handle_CargoSlot& Self)
{
    return ck::IsValid(Self.Get_Item());
}

mixin FCk_Handle_Interactable Get_Interactable(const FCk_Handle_CargoSlot& Self)
{
    return Self.Get_Fragment(FMars_Fragment_CargoSlot).Interactable;
}

// The stowed item's Visual-mode world item; invalid while the slot is empty (as of the last sync pass).
mixin FCk_Handle Get_Visual(const FCk_Handle_CargoSlot& Self)
{
    return Self.Get_Fragment(FMars_Fragment_CargoSlot).Visual;
}

// The Acts the authority has refused, as this machine last received it.
mixin int32 Get_RefusalSerial(const FCk_Handle_CargoSlot& Self)
{
    return Self.Get_Fragment(FMars_Fragment_CargoSlot_Net).RefusalSerial;
}

// Why the latest refused Act was refused; meaningful once Get_RefusalSerial is above 0.
mixin EMars_Interaction_FailReason Get_LastRefusal(const FCk_Handle_CargoSlot& Self)
{
    return Self.Get_Fragment(FMars_Fragment_CargoSlot_Net).LastRefusal;
}

// Whose Act was refused last; invalid before any, and on a client while that entity is not resolved there.
mixin FCk_Handle Get_LastRefused(const FCk_Handle_CargoSlot& Self)
{
    return Self.Get_Fragment(FMars_Fragment_CargoSlot_Net).LastRefused;
}

// What interacting would do for InFocuser, first matching row wins:
//   any slot,  the pack is Held                          -> Blocked_PackHeld
//   empty,     holds an item the slot accepts             -> Stow
//   empty,     holds an item the slot rejects             -> Blocked_NotStowable
//   empty,     hands empty                                -> Blocked_NothingHeld
//   occupied,  hands empty, the hotbar has a take target  -> Take
//   occupied,  hands empty, no take target                -> Blocked_NoRoom
//   occupied,  holds anything                             -> Blocked_SlotOccupied
// "Hands empty" = the focuser's HeldItem has no current item. A focuser without HeldItem + Hotbar -> Blocked_NothingHeld.
mixin EMars_CargoSlot_Action Get_ActionFor(const FCk_Handle_CargoSlot& Self, FCk_Handle InFocuser)
{
    const auto Backpack = Self.Get_Backpack();
    if (ck::IsValid(Backpack) && Backpack.Get_Mount() == EMars_WorldItem_Mount::Held)
    { return EMars_CargoSlot_Action::Blocked_PackHeld; }

    const auto HeldItem = InFocuser.As_HeldItem(ECk_SanityCheck::UnChecked);
    const auto Hotbar = InFocuser.As_Hotbar(ECk_SanityCheck::UnChecked);
    if (ck::Is_NOT_Valid(HeldItem) || ck::Is_NOT_Valid(Hotbar))
    { return EMars_CargoSlot_Action::Blocked_NothingHeld; }

    const auto Held = HeldItem.Get_CurrentItem();
    const auto SlotItem = Self.Get_Item();

    if (ck::Is_NOT_Valid(SlotItem))
    {
        if (ck::Is_NOT_Valid(Held))
        { return EMars_CargoSlot_Action::Blocked_NothingHeld; }

        return utils_cargo_slot::Get_CanAccept(Held) ? EMars_CargoSlot_Action::Stow : EMars_CargoSlot_Action::Blocked_NotStowable;
    }

    if (ck::IsValid(Held))
    { return EMars_CargoSlot_Action::Blocked_SlotOccupied; }

    return ck::IsValid(Hotbar.TryGet_TakeTarget(SlotItem)) ? EMars_CargoSlot_Action::Take : EMars_CargoSlot_Action::Blocked_NoRoom;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

mixin void Request_Stow(FCk_Handle_CargoSlot& Self, const FMars_Request_CargoSlot_Stow& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_CargoSlot_Requests);
    Requests.StowRequests.Add(InRequest);
}

mixin void Request_Take(FCk_Handle_CargoSlot& Self, const FMars_Request_CargoSlot_Take& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_CargoSlot_Requests);
    Requests.TakeRequests.Add(InRequest);
}

mixin void Request_ExpectArrival(FCk_Handle_CargoSlot& Self, const FMars_Request_CargoSlot_ExpectArrival& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_CargoSlot_Requests);
    Requests.ExpectArrivalRequests.Add(InRequest);
}

// The authority-side Act; a machine acting for a player goes through utils_cargo_slot::Request_ActFor.
mixin void Request_Act(FCk_Handle_CargoSlot& Self, const FMars_Request_CargoSlot_Act& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_CargoSlot_Requests);
    Requests.ActRequests.Add(InRequest);
}

//--------------------------------------------------------------------------------------------------------------------------
// Signal Binding
//--------------------------------------------------------------------------------------------------------------------------

mixin void BindTo_OnItemChanged(FCk_Handle_CargoSlot& Self, FMars_Delegate_CargoSlot_OnItemChanged InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_CargoSlot_Signals);
    Fragment.OnItemChanged.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnItemChanged(FCk_Handle_CargoSlot& Self, FMars_Delegate_CargoSlot_OnItemChanged InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_CargoSlot_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_CargoSlot_Signals).OnItemChanged.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnTransferFailed(FCk_Handle_CargoSlot& Self, FMars_Delegate_CargoSlot_OnTransferFailed InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_CargoSlot_Signals);
    Fragment.OnTransferFailed.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnTransferFailed(FCk_Handle_CargoSlot& Self, FMars_Delegate_CargoSlot_OnTransferFailed InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_CargoSlot_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_CargoSlot_Signals).OnTransferFailed.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}
