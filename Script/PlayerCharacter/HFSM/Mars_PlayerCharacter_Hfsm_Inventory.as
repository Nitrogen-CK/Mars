// Alive-scoped inventory links. The features stay pure data + request processors; these tasks decide when they talk:
//
//   HotbarIntents          : Slot1..4 presses                             -> Hotbar::Select
//   HotbarDrivesHeldItem   : Hotbar selection / slot contents / eject     -> HeldItem::SetSlot, HeldItemUse::Drop
//   HeldItemDrivesUse      : HeldItem::OnHeldItemChanged                  -> HeldItemUse::RefreshFromHeldItem
//   DropThrowIntent        : Drop press / hold timer / release            -> HeldItemUse::Drop / Throw / SetThrowArmed
//   HeldItemHints          : OnHeldItemChanged + OnThrowArmedChanged      -> ActionHintDisplay rows
//
// Every task is EnterExitOnly and signal-driven; the two intent tasks derive from UMars_SmTask_IntentEdges.
// Tasks never call into each other; they meet only through the features' fragments and signals.
// Single-player: these run on the local pawn only. Multiplayer needs a local-controller gate on the hint and input tasks.

//--------------------------------------------------------------------------------------------------------------------------
// HotbarIntents
//--------------------------------------------------------------------------------------------------------------------------

// A press of SlotK selects index K-1; the key one past the last bag slot selects the overflow slot (Slot4 with 3 bag
// slots), and keys beyond it do nothing.
class UMars_SmTask_HotbarIntents : UMars_SmTask_IntentEdges
{
    private FCk_Handle_Hotbar _Hotbar;
    private TArray<FGameplayTag> _SlotIntents;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        auto Player = ck::Ctx(InHandle);
        _Hotbar = Player.As_Hotbar();

        _SlotIntents.Empty();
        _SlotIntents.Add(GameplayTags::Mars_Intent_Slot1);
        _SlotIntents.Add(GameplayTags::Mars_Intent_Slot2);
        _SlotIntents.Add(GameplayTags::Mars_Intent_Slot3);
        _SlotIntents.Add(GameplayTags::Mars_Intent_Slot4);

        Super::DoEnterTask(InHandle, InNetContext);
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        Super::DoExitTask(InHandle, InNetContext);

        _Hotbar = FCk_Handle_Hotbar();
    }

    protected void OnIntentPressed(FGameplayTag InIntent) override
    {
        const auto Index = _SlotIntents.FindIndex(InIntent);
        if (Index < 0 || ck::Is_NOT_Valid(_Hotbar) || Index > _Hotbar.Get_OverflowIndex())
        { return; }

        _Hotbar.Request_Select(FMars_Request_Hotbar_Select(Index));
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

// Drop pressed and released before ThrowHoldSeconds drops; held past it (a hold timer on the player) arms a throw, and
// the release throws. A press with empty hands does nothing, and the hands emptying mid-hold cancels the hold and
// disarms. A matcher swap that reads Drop Idle mid-hold is a release.
//
// Throw-vs-drop is decided from this task's own _Armed, set in the timer callback: the feature's ThrowArmed is written by
// a request drain, so a release in the frame the timer fires would still read it unarmed. SetThrowArmed is requested
// only so the hint task can show "release to throw".
class UMars_SmTask_DropThrowIntent : UMars_SmTask_IntentEdges
{
    private FCk_Handle _Player;
    private FCk_Handle_HeldItem _HeldItem;
    private FCk_Handle_HeldItemUse _Use;
    private float32 _ThrowHoldSeconds = 0.35f;

    // Valid from the press until the release or a cancel - including after it finishes (StopOnDone).
    private FCk_Handle_Timer _HoldTimer;

    // Set when the hold timer finishes, cleared by every cancel; what Release reads.
    private bool _Armed = false;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        _Player = ck::Ctx(InHandle);
        _HeldItem = _Player.As_HeldItem();
        _Use = _Player.As_HeldItemUse();

        auto Character = Cast<AMars_PlayerCharacter>(ck::ToActor(_Player, ECk_SanityCheck::UnChecked));
        if (ck::IsValid(Character) && ck::IsValid(Character.Config))
        { _ThrowHoldSeconds = Character.Config.ThrowHoldSeconds; }

        _HeldItem.BindTo_OnHeldItemChanged(FMars_Delegate_HeldItem_OnHeldItemChanged(this, n"OnHeldItemChanged"));

        Super::DoEnterTask(InHandle, InNetContext);
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        Super::DoExitTask(InHandle, InNetContext);

        if (ck::IsValid(_HeldItem))
        { _HeldItem.UnbindFrom_OnHeldItemChanged(FMars_Delegate_HeldItem_OnHeldItemChanged(this, n"OnHeldItemChanged")); }

        CancelHold();

        _Player = FCk_Handle();
        _HeldItem = FCk_Handle_HeldItem();
        _Use = FCk_Handle_HeldItemUse();
    }

    protected void OnMatcherRebound() override
    {
        if (ck::IsValid(_HoldTimer) && Get_IsRowActive(GameplayTags::Mars_Intent_Drop) == false)
        { Release(); }
    }

    protected void OnIntentPressed(FGameplayTag InIntent) override
    {
        if (InIntent != GameplayTags::Mars_Intent_Drop)
        { return; }

        CancelHold();

        if (ck::Is_NOT_Valid(_HeldItem) || ck::Is_NOT_Valid(_HeldItem.Get_CurrentItem()))
        { return; }

        auto TimerSpec = FCk_Timer_Spec(FCk_Time(_ThrowHoldSeconds));
        TimerSpec.Set_StartingState(ECk_Timer_State::Running)
                 .Set_Behavior(ECk_Timer_Behavior::StopOnDone);

        _HoldTimer = utils_timer::Add(_Player, TimerSpec);
        if (ck::IsValid(_HoldTimer))
        { _HoldTimer.BindTo_OnDone(FCk_Delegate_Timer(this, n"OnHoldTimerDone")); }
    }

    protected void OnIntentReleased(FGameplayTag InIntent) override
    {
        if (InIntent == GameplayTags::Mars_Intent_Drop)
        { Release(); }
    }

    UFUNCTION()
    private void OnHeldItemChanged(FCk_Handle_HeldItem InHeldItem, FCk_Handle_Item InPrev, FCk_Handle_Item InNew)
    {
        if (ck::Is_NOT_Valid(InNew))
        { CancelHold(); }
    }

    UFUNCTION()
    private void OnHoldTimerDone(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        // A cancelled timer can still finish in the frame it was destroyed.
        if ((FCk_Handle(_HoldTimer) == FCk_Handle(InTimer)) == false)
        { return; }

        _Armed = true;

        if (ck::IsValid(_Use))
        { _Use.Request_SetThrowArmed(FMars_Request_HeldItemUse_SetThrowArmed(true)); }
    }

    private void Release()
    {
        if (ck::Is_NOT_Valid(_HoldTimer))
        { return; }

        if (ck::IsValid(_Use) && ck::IsValid(_HeldItem) && ck::IsValid(_HeldItem.Get_CurrentItem()))
        {
            if (_Armed)
            { _Use.Request_Throw(); }
            else
            { _Use.Request_Drop(); }
        }

        CancelHold();
    }

    private void CancelHold()
    {
        if (ck::IsValid(_HoldTimer))
        {
            _HoldTimer.UnbindFrom_OnDone(FCk_Delegate_Timer(this, n"OnHoldTimerDone"));
            utils_timer::Request_Stop(_HoldTimer);
            utils_entity_lifetime::Request_DestroyEntity(FCk_Handle(_HoldTimer));
        }

        _HoldTimer = FCk_Handle_Timer();

        // Only this task arms the feature flag, so it is set exactly while _Armed is.
        const auto WasArmed = _Armed;
        _Armed = false;

        if (WasArmed && ck::IsValid(_Use))
        { _Use.Request_SetThrowArmed(FMars_Request_HeldItemUse_SetThrowArmed(false)); }
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// HeldItemHints
//--------------------------------------------------------------------------------------------------------------------------

// Owns every legend row keyed k_OwnerKey: the item's use verb (when it has a UseAction), drop, and throw (hold). The
// throw row reads "release to throw" while a throw is armed.
//
// A held-item change unregisters the previous rows by row handle, not by owner: the display drains registers before
// owner-unregisters, so an owner-unregister queued beside the new rows would remove them too. Exit, which registers
// nothing, removes by owner.
class UMars_SmTask_HeldItemHints : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::EnterExitOnly;

    private const FName k_OwnerKey = n"HeldItem";

    private FCk_Handle_HeldItem _HeldItem;
    private FCk_Handle_HeldItemUse _Use;
    private FCk_Handle_ActionHintDisplay _Display;

    private TArray<FCk_Handle_ActionHintRow> _Rows;
    private FCk_Handle_ActionHintRow _ThrowRow;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        auto Player = ck::Ctx(InHandle);
        _HeldItem = Player.As_HeldItem();
        _Use = Player.As_HeldItemUse();
        _Display = Player.As_ActionHintDisplay(ECk_SanityCheck::UnChecked);

        _HeldItem.BindTo_OnHeldItemChanged(FMars_Delegate_HeldItem_OnHeldItemChanged(this, n"OnHeldItemChanged"));
        _Use.BindTo_OnThrowArmedChanged(FMars_Delegate_HeldItemUse_OnThrowArmedChanged(this, n"OnThrowArmedChanged"));
        Refresh_Rows(_HeldItem.Get_CurrentItem());
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        if (ck::IsValid(_HeldItem))
        { _HeldItem.UnbindFrom_OnHeldItemChanged(FMars_Delegate_HeldItem_OnHeldItemChanged(this, n"OnHeldItemChanged")); }

        if (ck::IsValid(_Use))
        { _Use.UnbindFrom_OnThrowArmedChanged(FMars_Delegate_HeldItemUse_OnThrowArmedChanged(this, n"OnThrowArmedChanged")); }

        if (ck::IsValid(_Display))
        { _Display.Request_UnregisterHintsByOwner(FMars_Request_ActionHintDisplay_UnregisterByOwner(k_OwnerKey)); }

        _Rows.Empty();
        _ThrowRow = FCk_Handle_ActionHintRow();
        _HeldItem = FCk_Handle_HeldItem();
        _Use = FCk_Handle_HeldItemUse();
        _Display = FCk_Handle_ActionHintDisplay();
    }

    UFUNCTION()
    private void OnHeldItemChanged(FCk_Handle_HeldItem InHeldItem, FCk_Handle_Item InPrev, FCk_Handle_Item InNew)
    {
        Refresh_Rows(InNew);
    }

    UFUNCTION()
    private void OnThrowArmedChanged(FCk_Handle_HeldItemUse InUse, bool InArmed)
    {
        Update_ThrowRow(InArmed);
    }

    private void Update_ThrowRow(bool InArmed)
    {
        if (ck::Is_NOT_Valid(_Display) || ck::Is_NOT_Valid(_ThrowRow))
        { return; }

        const auto Text = InArmed ? FText::FromString("release to throw") : FText::FromString("throw");
        _Display.Request_UpdateHint(FMars_Request_ActionHintDisplay_Update(_ThrowRow, Text));
    }

    private void Refresh_Rows(FCk_Handle_Item InItem)
    {
        if (ck::Is_NOT_Valid(_Display))
        { return; }

        for (const auto& Row : _Rows)
        { _Display.Request_UnregisterHint(FMars_Request_ActionHintDisplay_Unregister(Row)); }

        _Rows.Empty();
        _ThrowRow = FCk_Handle_ActionHintRow();

        if (ck::Is_NOT_Valid(InItem))
        { return; }

        auto Item = InItem;
        if (Item.Has_UseAction())
        {
            const UMars_ItemTrait_UseAction UseAction = Item.Get_UseAction();
            if (UseAction.HintText.IsEmpty() == false)
            {
                _Rows.Add(_Display.Request_RegisterHint(
                    FMars_ActionHint_Spec(mars::Mars_IA_Interact_Primary, UseAction.HintText, 0, k_OwnerKey)));
            }
        }

        _Rows.Add(_Display.Request_RegisterHint(
            FMars_ActionHint_Spec(mars::Mars_IA_Drop, FText::FromString("drop"), 1, k_OwnerKey)));

        _ThrowRow = _Display.Request_RegisterHint(
            FMars_ActionHint_Spec(mars::Mars_IA_Drop, FText::FromString("throw"), FText::FromString("hold"), 2, k_OwnerKey));
        _Rows.Add(_ThrowRow);

        // A throw can stay armed across a swap to another item; the display drains Register before Update.
        if (ck::IsValid(_Use) && _Use.Get_ThrowArmed())
        { Update_ThrowRow(true); }
    }
}
