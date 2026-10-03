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
    // A scene-node child of the pack root at MountOffset carrying the slot: a capacity-1 Inventory.Mars.Cargo.<Index>
    // inventory (accept policy CDO) and a probe interactable with one Use target running UMars_SmState_CargoSlot_Interact.
    // The slot entity is owned by the pack, so it dies with it.
    FCk_Handle_CargoSlot Create(FCk_Handle_Transform& InPackRoot, FMars_CargoSlot_Spec InSpec)
    {
        const auto Validation = InSpec.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[CargoSlot] [{InPackRoot.ToString()}] rejected the spec: {Validation.Get_Error()}"))
        { return FCk_Handle_CargoSlot(); }

        auto SlotNode = utils_scene_node::Create(InPackRoot, InSpec.MountOffset).As_Transform();

        TSubclassOf<UMars_CargoSlot_AcceptPolicy> PolicyClass = UMars_CargoSlot_AcceptPolicy;
        auto Policy = PolicyClass.GetDefaultObject();

        auto InventoryParams = utils_inventory_data_only::Make_Params_Bounded(
            utils_gameplay_tag::ResolveGameplayTag(FName(f"Inventory.Mars.Cargo.{InSpec.Index}")), 1,
            FCk_Delegate_Inventory_CustomCanAcceptItem_Dynamic(Policy, n"OnCanAccept"),
            FCk_Delegate_Inventory_CustomCanStackItems_Dynamic());
        InventoryParams.Set_StackingPolicy(ECk_Inventory_StackingPolicy::NoStacking);
        InventoryParams.Set_PersistContents(ECk_EnableDisable::Disable);

        FCk_Handle SlotEntity = SlotNode;
        auto Inventory = utils_inventory_data_only::Add(SlotEntity, InventoryParams, ECk_Replication::DoesNotReplicate);

        auto Params = FMars_Fragment_CargoSlot_Params();
        Params.Backpack = InSpec.Backpack;

        auto State = FMars_Fragment_CargoSlot();
        State.Inventory = Inventory;
        State.Interactable = DoCreate_Interactable(SlotNode, InSpec.ProbeRadius);

        SlotNode.Add_Fragment(FMars_Feature_CargoSlot());
        SlotNode.Add_Fragment(Params);
        SlotNode.Add_Fragment(State);
        return SlotEntity.As_CargoSlot();
    }

    // The accept rule every cargo slot enforces (and Get_ActionFor previews): no backpack, no persistent item.
    bool Get_CanAccept(const FCk_Handle_Item& InItem)
    {
        if (ck::Is_NOT_Valid(InItem))
        { return false; }

        return InItem.Has_Backpack() == false && InItem.Has_PersistentWorldItem() == false;
    }

    // InItemName is the held item for Stow and the slot's item for Take; the Blocked_ texts ignore it.
    FText Get_PromptText(EMars_CargoSlot_Action InAction, FText InItemName)
    {
        if (InAction == EMars_CargoSlot_Action::Stow)
        { return FText::FromString(f"Stow {InItemName.ToString()}"); }

        if (InAction == EMars_CargoSlot_Action::Take)
        { return FText::FromString(f"Take {InItemName.ToString()}"); }

        if (InAction == EMars_CargoSlot_Action::Blocked_NothingHeld)
        { return FText::FromString("Nothing to stow"); }

        if (InAction == EMars_CargoSlot_Action::Blocked_NotStowable)
        { return FText::FromString("Can't stow that"); }

        if (InAction == EMars_CargoSlot_Action::Blocked_SlotOccupied)
        { return FText::FromString("Slot occupied"); }

        if (InAction == EMars_CargoSlot_Action::Blocked_NoRoom)
        { return FText::FromString("No room"); }

        return FText::FromString("Put the pack down");
    }

    // The probe carries Probe.Mars.Interact (the player's interaction trace only sees probes under that tag) and is
    // Kinematic: it follows the pack. The prompt text is a placeholder until UMars_Processor_CargoSlot_Prompt writes
    // the focuser's action.
    FCk_Handle_Interactable DoCreate_Interactable(FCk_Handle_Transform& InSlotNode, float32 InProbeRadius)
    {
        auto Probe = FMars_Interactable_ProbeInfo();
        Probe.ProbeSpec = FCk_Probe_Spec(GameplayTags::Probe_Mars_Interact);
        Probe.ProbeSpec.Set_MotionType(ECk_MotionType::Kinematic);
        Probe.ProbeShape = utils_shapes::Make_Sphere(FCk_ShapeSphere_Dimensions(InProbeRadius));
        Probe.ProbeOffset = FTransform::Identity;

        auto TargetSpec = FCk_InteractTarget_Spec(GameplayTags::InteractionChannel_Mars_Use);
        TargetSpec.Set_CompletionPolicy(ECk_Interaction_CompletionPolicy::Instant);

        auto Prompt = FMars_InteractPrompt_Spec();
        Prompt.InputAction = mars::Mars_IA_Interact_Use;
        Prompt.PromptText = FText::FromString("Cargo");

        auto Target = FMars_Interactable_TargetEntry();
        Target.InteractTargetSpec = TargetSpec;
        Target.InteractPromptSpec = Prompt;
        Target.InteractionStateClass = UMars_SmState_CargoSlot_Interact;

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
