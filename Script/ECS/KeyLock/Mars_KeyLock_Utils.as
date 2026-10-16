// Stateless accept predicate for every lock inventory, bound from the CDO: the lock that owns the inventory decides.
UCLASS()
class UMars_KeyLock_AcceptPolicy : UObject
{
    UFUNCTION()
    void OnCanAccept(FCk_Handle_Inventory InInventory, FCk_Handle_Item InItem, bool& OutCanAccept)
    {
        const auto Lock = utils_entity_lifetime::Get_LifetimeOwner(InInventory).As_KeyLock(ECk_SanityCheck::UnChecked);
        OutCanAccept = ck::IsValid(Lock) && Lock.Get_Accepts(InItem);
    }
}

namespace utils_key_lock
{
    // A capacity-1 Inventory.Mars.KeyLock inventory (accept policy CDO) on InHandle, the lock's feature on it, and the
    // caller's KeyMount and Interactable recorded for the sync and the prompt. A spec that fails Validate() ensures and adds
    // nothing.
    FCk_Handle_KeyLock Add(FCk_Handle& InHandle, FMars_KeyLock_Spec InSpec)
    {
        const auto Validation = InSpec.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[KeyLock] [{InHandle.ToString()}] rejected the spec: {Validation.Get_Error()}"))
        { return FCk_Handle_KeyLock(); }

        TSubclassOf<UMars_KeyLock_AcceptPolicy> PolicyClass = UMars_KeyLock_AcceptPolicy;
        auto Policy = PolicyClass.GetDefaultObject();

        auto InventoryParams = utils_inventory_data_only::Make_Params_Bounded(
            GameplayTags::Inventory_Mars_KeyLock, 1,
            FCk_Delegate_Inventory_CustomCanAcceptItem_Dynamic(Policy, n"OnCanAccept"),
            FCk_Delegate_Inventory_CustomCanStackItems_Dynamic());
        InventoryParams.Set_StackingPolicy(ECk_Inventory_StackingPolicy::NoStacking);
        InventoryParams.Set_PersistContents(ECk_EnableDisable::Disable);

        auto Params = FMars_Fragment_KeyLock_Params();
        Params.AcceptedKey = InSpec.AcceptedKey;
        Params.Release = InSpec.Release;

        auto State = FMars_Fragment_KeyLock();
        State.Inventory = utils_inventory_data_only::Add(InHandle, InventoryParams, ECk_Replication::DoesNotReplicate);
        State.Interactable = InSpec.Interactable;
        State.KeyMount = InSpec.KeyMount;

        InHandle.Add_Fragment(FMars_Feature_KeyLock());
        InHandle.Add_Fragment(Params);
        InHandle.Add_Fragment(State);
        return InHandle.As_KeyLock();
    }

    // The lock's one interact target: Use, a placeholder prompt UMars_Processor_KeyLock_Prompt rewrites while focused, and
    // WhileLive: an insert or a removal lives until the lock reports it.
    FMars_Interactable_TargetEntry Make_InteractTarget()
    {
        auto Prompt = FMars_InteractPrompt_Spec();
        Prompt.InputAction = mars::Mars_IA_Interact_Use;
        Prompt.PromptText = FText::FromString("Keyhole");

        auto Target = FMars_Interactable_TargetEntry();
        Target.InteractTargetSpec = FCk_InteractTarget_Spec(GameplayTags::InteractionChannel_Mars_Use);
        Target.InteractPromptSpec = Prompt;
        Target.InteractionStateClass = UMars_SmState_KeyLock_Interact;
        Target.Work = EMars_Interactable_Work::WhileLive;
        return Target;
    }

    // "Red" for Key.Mars.Red: the tag's last segment.
    FString Get_KeyName(FGameplayTag InKeyId)
    {
        const auto TagName = InKeyId.ToString();
        FString Head;
        FString Leaf;
        if (TagName.Split(".", Head, Leaf, ESearchCase::IgnoreCase, ESearchDir::FromEnd))
        { return Leaf; }

        return TagName;
    }

    // InItemName is the held key for Insert and the inserted key for Take; InAcceptedKey names the key a Blocked_ lock
    // asks for.
    FText Get_PromptText(EMars_KeyLock_Action InAction, FText InItemName, FGameplayTag InAcceptedKey)
    {
        if (InAction == EMars_KeyLock_Action::Insert)
        { return FText::FromString(f"Insert {InItemName.ToString()}"); }

        if (InAction == EMars_KeyLock_Action::Take)
        { return FText::FromString(f"Take {InItemName.ToString()}"); }

        if (InAction == EMars_KeyLock_Action::Blocked_NothingHeld || InAction == EMars_KeyLock_Action::Blocked_WrongKey)
        { return FText::FromString(f"Needs {Get_KeyName(InAcceptedKey)} key"); }

        if (InAction == EMars_KeyLock_Action::Blocked_KeyKept)
        { return FText::FromString("Unlocked"); }

        if (InAction == EMars_KeyLock_Action::Blocked_HandsFull)
        { return FText::FromString("Hands full"); }

        return FText::FromString("No room");
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

mixin FGameplayTag Get_AcceptedKey(const FCk_Handle_KeyLock& Self)
{
    return Self.Get_Fragment(FMars_Fragment_KeyLock_Params).AcceptedKey;
}

mixin EMars_KeyLock_Release Get_Release(const FCk_Handle_KeyLock& Self)
{
    return Self.Get_Fragment(FMars_Fragment_KeyLock_Params).Release;
}

mixin FCk_Handle_Inventory_DataOnly Get_Inventory(const FCk_Handle_KeyLock& Self)
{
    return Self.Get_Fragment(FMars_Fragment_KeyLock).Inventory;
}

// The inserted key; invalid while the lock is locked.
mixin FCk_Handle_Item Get_Key(const FCk_Handle_KeyLock& Self)
{
    const auto Inventory = Self.Get_Inventory();
    return Inventory.Get_SoleItem();
}

mixin bool Get_IsUnlocked(const FCk_Handle_KeyLock& Self)
{
    return ck::IsValid(Self.Get_Key());
}

mixin FCk_Handle_Interactable Get_Interactable(const FCk_Handle_KeyLock& Self)
{
    return Self.Get_Fragment(FMars_Fragment_KeyLock).Interactable;
}

mixin FCk_Handle_Transform Get_KeyMount(const FCk_Handle_KeyLock& Self)
{
    return Self.Get_Fragment(FMars_Fragment_KeyLock).KeyMount;
}

// The inserted key's Visual-mode world item; invalid while the lock is empty (as of the last sync pass).
mixin FCk_Handle Get_Visual(const FCk_Handle_KeyLock& Self)
{
    return Self.Get_Fragment(FMars_Fragment_KeyLock).Visual;
}

// The accept rule the lock's inventory enforces (and Get_ActionFor previews): a key whose KeyId is AcceptedKey.
mixin bool Get_Accepts(const FCk_Handle_KeyLock& Self, const FCk_Handle_Item& InItem)
{
    if (ck::Is_NOT_Valid(InItem))
    { return false; }

    return InItem.Get_KeyId() == Self.Get_AcceptedKey();
}

// What interacting would do for InFocuser, first matching row wins:
//   empty,     holds the lock's key                           -> Insert
//   empty,     holds anything else                            -> Blocked_WrongKey
//   empty,     hands empty                                    -> Blocked_NothingHeld
//   occupied,  Kept                                           -> Blocked_KeyKept
//   occupied,  Removable, holds anything                      -> Blocked_HandsFull
//   occupied,  Removable, hands empty, a hotbar take target   -> Remove
//   occupied,  Removable, hands empty, no take target         -> Blocked_NoRoom
// A focuser without HeldItem + Hotbar -> Blocked_NothingHeld.
mixin EMars_KeyLock_Action Get_ActionFor(const FCk_Handle_KeyLock& Self, FCk_Handle InFocuser)
{
    const auto HeldItem = InFocuser.As_HeldItem(ECk_SanityCheck::UnChecked);
    const auto Hotbar = InFocuser.As_Hotbar(ECk_SanityCheck::UnChecked);
    if (ck::Is_NOT_Valid(HeldItem) || ck::Is_NOT_Valid(Hotbar))
    { return EMars_KeyLock_Action::Blocked_NothingHeld; }

    const auto Held = HeldItem.Get_CurrentItem();
    const auto Key = Self.Get_Key();

    if (ck::Is_NOT_Valid(Key))
    {
        if (ck::Is_NOT_Valid(Held))
        { return EMars_KeyLock_Action::Blocked_NothingHeld; }

        return Self.Get_Accepts(Held) ? EMars_KeyLock_Action::Insert : EMars_KeyLock_Action::Blocked_WrongKey;
    }

    if (Self.Get_Release() == EMars_KeyLock_Release::Kept)
    { return EMars_KeyLock_Action::Blocked_KeyKept; }

    if (ck::IsValid(Held))
    { return EMars_KeyLock_Action::Blocked_HandsFull; }

    return ck::IsValid(Hotbar.TryGet_TakeTarget(Key)) ? EMars_KeyLock_Action::Take : EMars_KeyLock_Action::Blocked_NoRoom;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

mixin void Request_Insert(FCk_Handle_KeyLock& Self, const FMars_Request_KeyLock_Insert& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_KeyLock_Requests);
    Requests.InsertRequests.Add(InRequest);
}

mixin void Request_Take(FCk_Handle_KeyLock& Self, const FMars_Request_KeyLock_Take& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_KeyLock_Requests);
    Requests.TakeRequests.Add(InRequest);
}

//--------------------------------------------------------------------------------------------------------------------------
// Signal Binding
//--------------------------------------------------------------------------------------------------------------------------

mixin void BindTo_OnKeyChanged(FCk_Handle_KeyLock& Self, FMars_Delegate_KeyLock_OnKeyChanged InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_KeyLock_Signals);
    Fragment.OnKeyChanged.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnKeyChanged(FCk_Handle_KeyLock& Self, FMars_Delegate_KeyLock_OnKeyChanged InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_KeyLock_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_KeyLock_Signals).OnKeyChanged.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnTransferFailed(FCk_Handle_KeyLock& Self, FMars_Delegate_KeyLock_OnTransferFailed InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_KeyLock_Signals);
    Fragment.OnTransferFailed.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnTransferFailed(FCk_Handle_KeyLock& Self, FMars_Delegate_KeyLock_OnTransferFailed InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_KeyLock_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_KeyLock_Signals).OnTransferFailed.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}
