// Stateless accept predicate for every hook inventory, bound from the CDO: a lantern whose body is its Persistent world item.
UCLASS()
class UMars_LanternHook_AcceptPolicy : UObject
{
    UFUNCTION()
    void OnCanAccept(FCk_Handle_Inventory InInventory, FCk_Handle_Item InItem, bool& OutCanAccept)
    { OutCanAccept = utils_lantern_hook::Get_IsLantern(InItem); }
}

namespace utils_lantern_hook
{
    // A capacity-1 Inventory.Mars.LanternHook inventory (accept policy CDO) on InHandle whose lantern rides InHandle's
    // AttachPoint.Mars.Hook (the caller's HangNode) at HangOffset, the hook's feature on it, and the caller's Interactable
    // recorded for the prompt. InHandle is the carrier a hung lantern mounts on: it publishes no other attach point. A spec
    // that fails Validate() ensures and adds nothing.
    FCk_Handle_LanternHook Add(FCk_Handle& InHandle, FMars_LanternHook_Spec InSpec)
    {
        const auto Validation = InSpec.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[LanternHook] [{InHandle.ToString()}] rejected the spec: {Validation.Get_Error()}"))
        { return FCk_Handle_LanternHook(); }

        const auto HookPoint = GameplayTags::AttachPoint_Mars_Hook;
        const auto InventoryTag = GameplayTags::Inventory_Mars_LanternHook;

        TSubclassOf<UMars_LanternHook_AcceptPolicy> PolicyClass = UMars_LanternHook_AcceptPolicy;
        auto Policy = PolicyClass.GetDefaultObject();

        auto InventoryParams = utils_inventory_data_only::Make_Params_Bounded(InventoryTag, 1,
            FCk_Delegate_Inventory_CustomCanAcceptItem_Dynamic(Policy, n"OnCanAccept"),
            FCk_Delegate_Inventory_CustomCanStackItems_Dynamic());
        InventoryParams.Set_StackingPolicy(ECk_Inventory_StackingPolicy::NoStacking);
        InventoryParams.Set_PersistContents(ECk_EnableDisable::Disable);

        auto Inventory = utils_inventory_data_only::Add(InHandle, InventoryParams, ECk_Replication::DoesNotReplicate);
        utils_world_item::Add_MountedInventory(Inventory, FMars_Fragment_MountedInventory(EMars_WorldItem_MountRule::PointAtOffset,
            HookPoint, InSpec.HangOffset));

        auto AttachPointsSpec = FMars_AttachPoints_Spec();
        AttachPointsSpec.Points.Add(FMars_AttachPoint_Entry(HookPoint, InSpec.HangNode));
        utils_attach_points::Add(InHandle, AttachPointsSpec);

        auto State = FMars_Fragment_LanternHook();
        State.Inventory = Inventory;
        State.Interactable = InSpec.Interactable;
        State.HangNode = InSpec.HangNode;

        InHandle.Add_Fragment(FMars_Feature_LanternHook());
        InHandle.Add_Fragment(State);
        return InHandle.As_LanternHook();
    }

    // The hook's one interact target: Use with the caller's prompt (a placeholder the hook's prompt processor rewrites
    // while focused), and WhileLive: a hang or a take lives until the hook reports it.
    FMars_Interactable_TargetEntry Make_InteractTarget(FMars_InteractPrompt_Spec InPrompt)
    {
        auto Target = FMars_Interactable_TargetEntry();
        Target.InteractTargetSpec = FCk_InteractTarget_Spec(GameplayTags::InteractionChannel_Mars_Use);
        Target.InteractPromptSpec = InPrompt;
        Target.InteractionStateClass = UMars_SmState_LanternHook_Interact;
        Target.Work = EMars_Interactable_Work::WhileLive;
        return Target;
    }

    // The accept rule the hook's inventory enforces: an item with UMars_ItemTrait_Lantern whose body is its Persistent
    // world item.
    bool Get_IsLantern(const FCk_Handle_Item& InItem)
    {
        return ck::IsValid(InItem) && InItem.Has_LanternTrait() && InItem.Has_PersistentWorldItem();
    }

}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

mixin FCk_Handle_Inventory_DataOnly Get_Inventory(const FCk_Handle_LanternHook& Self)
{
    return Self.Get_Fragment(FMars_Fragment_LanternHook).Inventory;
}

mixin FCk_Handle_Interactable Get_Interactable(const FCk_Handle_LanternHook& Self)
{
    return Self.Get_Fragment(FMars_Fragment_LanternHook).Interactable;
}

mixin FCk_Handle_Transform Get_HangNode(const FCk_Handle_LanternHook& Self)
{
    return Self.Get_Fragment(FMars_Fragment_LanternHook).HangNode;
}

// The hung lantern's item; invalid while the hook is empty.
mixin FCk_Handle_Item Get_Item(const FCk_Handle_LanternHook& Self)
{
    const auto Inventory = Self.Get_Inventory();
    return Inventory.Get_SoleItem();
}

// The hung lantern's flame; invalid while the hook is empty.
mixin FCk_Handle_Flame Get_Flame(const FCk_Handle_LanternHook& Self)
{
    const auto Item = Self.Get_Item();
    if (ck::Is_NOT_Valid(Item))
    { return FCk_Handle_Flame(); }

    return Item.TryGet_Flame();
}

mixin bool Get_IsOccupied(const FCk_Handle_LanternHook& Self)
{
    return ck::IsValid(Self.Get_Item());
}

// A lit lantern hangs on the hook: what its source asserts.
mixin bool Get_HoldsLitFlame(const FCk_Handle_LanternHook& Self)
{
    const auto Flame = Self.Get_Flame();
    return ck::IsValid(Flame) && Flame.Get_IsLit();
}

// The hung lantern has landed on the hook: its world item settled, Carried by this hook. False while empty or on its way.
mixin bool Get_HasArrived(const FCk_Handle_LanternHook& Self)
{
    const auto Flame = Self.Get_Flame();
    if (ck::Is_NOT_Valid(Flame))
    { return false; }

    const auto WorldItem = Flame.H().As_WorldItem(ECk_SanityCheck::UnChecked);
    const FCk_Handle HookEntity = Self;
    return ck::IsValid(WorldItem) && WorldItem.Get_Mount() == EMars_WorldItem_Mount::Carried
        && WorldItem.Get_Carrier() == HookEntity && WorldItem.Get_IsSettled();
}

// What interacting would do for InFocuser, first matching row wins:
//   no HeldItem + Hotbar on the focuser                         -> Blocked_NothingHeld
//   empty,     hands empty                                     -> Blocked_NothingHeld
//   empty,     holds a lantern                                 -> Hang
//   empty,     holds anything else                             -> Blocked_NotALantern
//   occupied,  holds tallow, the hung lantern has room         -> Refuel
//   occupied,  holds tallow, the hung lantern is full          -> Blocked_Full
//   occupied,  holds anything else                             -> Blocked_HandsFull
//   occupied,  hands empty, a hotbar take target               -> Take
//   occupied,  hands empty, no take target                     -> Blocked_NoRoom
mixin EMars_LanternHook_Action Get_ActionFor(const FCk_Handle_LanternHook& Self, FCk_Handle InFocuser)
{
    const auto HeldItem = InFocuser.As_HeldItem(ECk_SanityCheck::UnChecked);
    const auto Hotbar = InFocuser.As_Hotbar(ECk_SanityCheck::UnChecked);
    if (ck::Is_NOT_Valid(HeldItem) || ck::Is_NOT_Valid(Hotbar))
    { return EMars_LanternHook_Action::Blocked_NothingHeld; }

    const auto Held = HeldItem.Get_CurrentItem();
    const auto Hung = Self.Get_Item();

    if (ck::Is_NOT_Valid(Hung))
    {
        if (ck::Is_NOT_Valid(Held))
        { return EMars_LanternHook_Action::Blocked_NothingHeld; }

        return utils_lantern_hook::Get_IsLantern(Held) ? EMars_LanternHook_Action::Hang : EMars_LanternHook_Action::Blocked_NotALantern;
    }

    if (ck::IsValid(Held) && Held.Has_Tallow())
    {
        const auto Flame = Self.Get_Flame();
        return ck::IsValid(Flame) && Flame.Get_CanRefuel() ? EMars_LanternHook_Action::Refuel : EMars_LanternHook_Action::Blocked_Full;
    }

    if (ck::IsValid(Held))
    { return EMars_LanternHook_Action::Blocked_HandsFull; }

    return ck::IsValid(Hotbar.TryGet_TakeTarget(Hung)) ? EMars_LanternHook_Action::Take : EMars_LanternHook_Action::Blocked_NoRoom;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

mixin void Request_Hang(FCk_Handle_LanternHook& Self, const FMars_Request_LanternHook_Hang& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_LanternHook_Requests);
    Requests.HangRequests.Add(InRequest);
}

mixin void Request_Take(FCk_Handle_LanternHook& Self, const FMars_Request_LanternHook_Take& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_LanternHook_Requests);
    Requests.TakeRequests.Add(InRequest);
}

mixin void Request_Refuel(FCk_Handle_LanternHook& Self, const FMars_Request_LanternHook_Refuel& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_LanternHook_Requests);
    Requests.RefuelRequests.Add(InRequest);
}

//--------------------------------------------------------------------------------------------------------------------------
// Signal Binding
//--------------------------------------------------------------------------------------------------------------------------

mixin void BindTo_OnLanternChanged(FCk_Handle_LanternHook& Self, FMars_Delegate_LanternHook_OnLanternChanged InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_LanternHook_Signals);
    Fragment.OnLanternChanged.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnLanternChanged(FCk_Handle_LanternHook& Self, FMars_Delegate_LanternHook_OnLanternChanged InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_LanternHook_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_LanternHook_Signals).OnLanternChanged.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnRequestFailed(FCk_Handle_LanternHook& Self, FMars_Delegate_LanternHook_OnRequestFailed InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_LanternHook_Signals);
    Fragment.OnRequestFailed.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnRequestFailed(FCk_Handle_LanternHook& Self, FMars_Delegate_LanternHook_OnRequestFailed InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_LanternHook_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_LanternHook_Signals).OnRequestFailed.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}
