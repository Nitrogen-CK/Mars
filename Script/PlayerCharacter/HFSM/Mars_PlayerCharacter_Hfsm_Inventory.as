// Alive-scoped inventory links. The features stay pure data + request processors; these tasks decide when they talk:
//
//   HotbarIntents          : Slot1..4 level rows                          -> Hotbar::Select
//   HotbarDrivesHeldItem   : Hotbar selection / slot contents / eject     -> HeldItem::SetSlot, HeldItemUse::Drop
//   HeldItemDrivesUse      : HeldItem::OnHeldItemChanged                  -> HeldItemUse::RefreshFromHeldItem
//   DropThrowIntent        : Drop level row (tap / hold-release)          -> HeldItemUse::Drop / Throw
//   HeldItemHints          : HeldItem::OnHeldItemChanged + ThrowArmed     -> ActionHintDisplay rows
//
// Tasks never call into each other; they meet only through the features' fragments.
// Single-player: these run on the local pawn only. Multiplayer needs a local-controller gate on the hint and input tasks.

//--------------------------------------------------------------------------------------------------------------------------
// HotbarIntents
//--------------------------------------------------------------------------------------------------------------------------

// Rising edge of SlotK selects index K-1; the key one past the last bag slot selects the overflow slot (Slot4 with 3 bag
// slots), and keys beyond it do nothing.
class UMars_SmTask_HotbarIntents : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::Tick;

    private FCk_Handle_InputIntents _Intents;
    private FCk_Handle_Hotbar _Hotbar;
    private TArray<FGameplayTag> _SlotIntents;
    private TArray<bool> _WasActive;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        auto Player = ck::Ctx(InHandle);
        _Intents = Player.As_InputIntents();
        _Hotbar = Player.As_Hotbar();

        _SlotIntents.Empty();
        _SlotIntents.Add(GameplayTags::Mars_Intent_Slot1);
        _SlotIntents.Add(GameplayTags::Mars_Intent_Slot2);
        _SlotIntents.Add(GameplayTags::Mars_Intent_Slot3);
        _SlotIntents.Add(GameplayTags::Mars_Intent_Slot4);

        // Seeded from the current rows so a key already held on enter is not a press.
        _WasActive.Empty();
        for (const auto& Intent : _SlotIntents)
        { _WasActive.Add(_Intents.Get_IsIntentActive(Intent)); }
    }

    UFUNCTION(BlueprintOverride)
    ECk_SmTaskResult DoTick(FCk_Handle_SmTask InHandle, FCk_Time InDeltaT, ECk_Sm_NetContext InNetContext)
    {
        const auto OverflowIndex = _Hotbar.Get_OverflowIndex();

        for (int32 Index = 0; Index < _SlotIntents.Num(); ++Index)
        {
            const auto IsActive = _Intents.Get_IsIntentActive(_SlotIntents[Index]);
            const auto IsRisingEdge = IsActive && _WasActive[Index] == false;
            _WasActive[Index] = IsActive;

            if (IsRisingEdge == false || Index > OverflowIndex)
            { continue; }

            _Hotbar.Request_Select(FMars_Request_Hotbar_Select(Index));
        }

        return ECk_SmTaskResult::Running;
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// HotbarDrivesHeldItem
//--------------------------------------------------------------------------------------------------------------------------

// Pushes (selected slot, its item) into HeldItem on every selection or slot-content change, and answers an overflow eject
// with a drop (the hotbar applies the parked selection once the overflow slot reads empty).
class UMars_SmTask_HotbarDrivesHeldItem : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::EnterExitOnly;

    private FCk_Handle_Hotbar _Hotbar;
    private FCk_Handle_HeldItem _HeldItem;
    private FCk_Handle_HeldItemUse _Use;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        auto Player = ck::Ctx(InHandle);
        _Hotbar = Player.As_Hotbar();
        _HeldItem = Player.As_HeldItem();
        _Use = Player.As_HeldItemUse();

        _Hotbar.BindTo_OnSelectionChanged(FMars_Delegate_Hotbar_OnSelectionChanged(this, n"OnSelectionChanged"));
        _Hotbar.BindTo_OnSlotItemChanged(FMars_Delegate_Hotbar_OnSlotItemChanged(this, n"OnSlotItemChanged"));
        _Hotbar.BindTo_OnOverflowEjectRequested(FMars_Delegate_Hotbar_OnOverflowEjectRequested(this, n"OnOverflowEjectRequested"));

        PushSelection();
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        if (ck::IsValid(_Hotbar))
        {
            _Hotbar.UnbindFrom_OnSelectionChanged(FMars_Delegate_Hotbar_OnSelectionChanged(this, n"OnSelectionChanged"));
            _Hotbar.UnbindFrom_OnSlotItemChanged(FMars_Delegate_Hotbar_OnSlotItemChanged(this, n"OnSlotItemChanged"));
            _Hotbar.UnbindFrom_OnOverflowEjectRequested(FMars_Delegate_Hotbar_OnOverflowEjectRequested(this, n"OnOverflowEjectRequested"));
        }

        _Hotbar = FCk_Handle_Hotbar();
        _HeldItem = FCk_Handle_HeldItem();
        _Use = FCk_Handle_HeldItemUse();
    }

    UFUNCTION()
    private void OnSelectionChanged(FCk_Handle_Hotbar InHotbar, int32 InPrevIndex, int32 InNewIndex)
    {
        PushSelection();
    }

    UFUNCTION()
    private void OnSlotItemChanged(FCk_Handle_Hotbar InHotbar, int32 InIndex, FCk_Handle_Item InMaybeItem)
    {
        PushSelection();
    }

    UFUNCTION()
    private void OnOverflowEjectRequested(FCk_Handle_Hotbar InHotbar, FCk_Handle_Item InItem, int32 InPendingIndex)
    {
        if (ck::IsValid(_Use))
        { _Use.Request_Drop(); }
    }

    private void PushSelection()
    {
        if (ck::Is_NOT_Valid(_Hotbar) || ck::Is_NOT_Valid(_HeldItem))
        { return; }

        _HeldItem.Request_SetSlot(FMars_Request_HeldItem_SetSlot(_Hotbar.Get_SelectedSlot(), _Hotbar.Get_SelectedItem()));
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// HeldItemDrivesUse
//--------------------------------------------------------------------------------------------------------------------------

class UMars_SmTask_HeldItemDrivesUse : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::EnterExitOnly;

    private FCk_Handle_HeldItem _HeldItem;
    private FCk_Handle_HeldItemUse _Use;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        auto Player = ck::Ctx(InHandle);
        _HeldItem = Player.As_HeldItem();
        _Use = Player.As_HeldItemUse();

        _HeldItem.BindTo_OnHeldItemChanged(FMars_Delegate_HeldItem_OnHeldItemChanged(this, n"OnHeldItemChanged"));
        _Use.Request_RefreshFromHeldItem();
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        if (ck::IsValid(_HeldItem))
        { _HeldItem.UnbindFrom_OnHeldItemChanged(FMars_Delegate_HeldItem_OnHeldItemChanged(this, n"OnHeldItemChanged")); }

        _HeldItem = FCk_Handle_HeldItem();
        _Use = FCk_Handle_HeldItemUse();
    }

    UFUNCTION()
    private void OnHeldItemChanged(FCk_Handle_HeldItem InHeldItem, FCk_Handle_Item InPrev, FCk_Handle_Item InNew)
    {
        if (ck::IsValid(_Use))
        { _Use.Request_RefreshFromHeldItem(); }
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// DropThrowIntent
//--------------------------------------------------------------------------------------------------------------------------

// Drop pressed and released before ThrowHoldSeconds drops; held past it arms a throw (ThrowArmed, for the hint), and the
// release throws. Does nothing, and disarms, while the hands are empty.
class UMars_SmTask_DropThrowIntent : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::Tick;

    private FCk_Handle_InputIntents _Intents;
    private FCk_Handle_HeldItem _HeldItem;
    private FCk_Handle_HeldItemUse _Use;
    private float32 _ThrowHoldSeconds = 0.35f;

    private bool _WasActive = false;
    private bool _Holding = false;
    private float64 _HeldSeconds = 0.0;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        auto Player = ck::Ctx(InHandle);
        _Intents = Player.As_InputIntents();
        _HeldItem = Player.As_HeldItem();
        _Use = Player.As_HeldItemUse();

        auto Character = Cast<AMars_PlayerCharacter>(ck::ToActor(Player, ECk_SanityCheck::UnChecked));
        if (ck::IsValid(Character) && ck::IsValid(Character.Config))
        { _ThrowHoldSeconds = Character.Config.ThrowHoldSeconds; }

        // A Drop already held on enter is not a press.
        _WasActive = _Intents.Get_IsIntentActive(GameplayTags::Mars_Intent_Drop);
        _Holding = false;
        _HeldSeconds = 0.0;
    }

    UFUNCTION(BlueprintOverride)
    ECk_SmTaskResult DoTick(FCk_Handle_SmTask InHandle, FCk_Time InDeltaT, ECk_Sm_NetContext InNetContext)
    {
        const auto IsActive = _Intents.Get_IsIntentActive(GameplayTags::Mars_Intent_Drop);
        const auto WasActive = _WasActive;
        _WasActive = IsActive;

        if (ck::Is_NOT_Valid(_HeldItem.Get_CurrentItem()))
        {
            Disarm();
            return ECk_SmTaskResult::Running;
        }

        if (IsActive && WasActive == false)
        {
            _Holding = true;
            _HeldSeconds = 0.0;
            return ECk_SmTaskResult::Running;
        }

        if (_Holding == false)
        { return ECk_SmTaskResult::Running; }

        if (IsActive)
        {
            _HeldSeconds += InDeltaT.Get_Seconds();
            if (_HeldSeconds >= _ThrowHoldSeconds && _Use.Get_ThrowArmed() == false)
            { _Use.Set_ThrowArmed(true); }

            return ECk_SmTaskResult::Running;
        }

        if (_Use.Get_ThrowArmed())
        { _Use.Request_Throw(); }
        else
        { _Use.Request_Drop(); }

        Disarm();
        return ECk_SmTaskResult::Running;
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        Disarm();
    }

    private void Disarm()
    {
        _Holding = false;
        _HeldSeconds = 0.0;

        if (ck::IsValid(_Use) && _Use.Get_ThrowArmed())
        { _Use.Set_ThrowArmed(false); }
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// HeldItemHints
//--------------------------------------------------------------------------------------------------------------------------

// Owns every legend row keyed k_OwnerKey: the item's use verb (when it has a UseAction), drop, and throw (hold). The
// throw row reads "release to throw" while a throw is armed.
//
// A held-item change unregisters the previous rows by id, not by owner: the display drains registers before
// owner-unregisters, so an owner-unregister queued beside the new rows would remove them too. Exit, which registers
// nothing, removes by owner.
class UMars_SmTask_HeldItemHints : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::Tick;

    private const FName k_OwnerKey = n"HeldItem";

    private FCk_Handle_HeldItem _HeldItem;
    private FCk_Handle_HeldItemUse _Use;
    private FCk_Handle_ActionHintDisplay _Display;

    private TArray<FMars_ActionHint_ID> _RowIds;
    private FMars_ActionHint_ID _ThrowRowId;
    private bool _LastArmed = false;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        auto Player = ck::Ctx(InHandle);
        _HeldItem = Player.As_HeldItem();
        _Use = Player.As_HeldItemUse();
        _Display = Player.As_ActionHintDisplay(ECk_SanityCheck::UnChecked);

        _HeldItem.BindTo_OnHeldItemChanged(FMars_Delegate_HeldItem_OnHeldItemChanged(this, n"OnHeldItemChanged"));
        Refresh_Rows(_HeldItem.Get_CurrentItem());
    }

    UFUNCTION(BlueprintOverride)
    ECk_SmTaskResult DoTick(FCk_Handle_SmTask InHandle, FCk_Time InDeltaT, ECk_Sm_NetContext InNetContext)
    {
        const auto IsArmed = _Use.Get_ThrowArmed();
        if (IsArmed == _LastArmed)
        { return ECk_SmTaskResult::Running; }

        _LastArmed = IsArmed;

        if (ck::IsValid(_Display) && _ThrowRowId.Value >= 0)
        {
            const auto Text = IsArmed ? FText::FromString("release to throw") : FText::FromString("throw");
            _Display.Request_UpdateHint(FMars_Request_ActionHintDisplay_Update(_ThrowRowId, Text));
        }

        return ECk_SmTaskResult::Running;
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        if (ck::IsValid(_HeldItem))
        { _HeldItem.UnbindFrom_OnHeldItemChanged(FMars_Delegate_HeldItem_OnHeldItemChanged(this, n"OnHeldItemChanged")); }

        if (ck::IsValid(_Display))
        { _Display.Request_UnregisterHintsByOwner(FMars_Request_ActionHintDisplay_UnregisterByOwner(k_OwnerKey)); }

        _RowIds.Empty();
        _ThrowRowId = FMars_ActionHint_ID();
        _LastArmed = false;
        _HeldItem = FCk_Handle_HeldItem();
        _Use = FCk_Handle_HeldItemUse();
        _Display = FCk_Handle_ActionHintDisplay();
    }

    UFUNCTION()
    private void OnHeldItemChanged(FCk_Handle_HeldItem InHeldItem, FCk_Handle_Item InPrev, FCk_Handle_Item InNew)
    {
        Refresh_Rows(InNew);
    }

    private void Refresh_Rows(FCk_Handle_Item InItem)
    {
        if (ck::Is_NOT_Valid(_Display))
        { return; }

        for (const auto& RowId : _RowIds)
        { _Display.Request_UnregisterHint(FMars_Request_ActionHintDisplay_Unregister(RowId)); }

        _RowIds.Empty();
        _ThrowRowId = FMars_ActionHint_ID();
        _LastArmed = false;

        if (ck::Is_NOT_Valid(InItem))
        { return; }

        auto Item = InItem;
        if (Item.Has_UseAction())
        {
            const UMars_ItemTrait_UseAction UseAction = Item.Get_UseAction();
            if (UseAction.HintText.IsEmpty() == false)
            {
                _RowIds.Add(_Display.Request_RegisterHint(FMars_Request_ActionHintDisplay_Register(
                    FMars_ActionHint_Spec(mars::Mars_IA_Interact_Primary, UseAction.HintText, 0, k_OwnerKey))));
            }
        }

        _RowIds.Add(_Display.Request_RegisterHint(FMars_Request_ActionHintDisplay_Register(
            FMars_ActionHint_Spec(mars::Mars_IA_Drop, FText::FromString("drop"), 1, k_OwnerKey))));

        _ThrowRowId = _Display.Request_RegisterHint(FMars_Request_ActionHintDisplay_Register(
            FMars_ActionHint_Spec(mars::Mars_IA_Drop, FText::FromString("throw"), FText::FromString("hold"), 2, k_OwnerKey)));
        _RowIds.Add(_ThrowRowId);
    }
}
