// What a platter's pickup offers its focuser.
enum EMars_Platter_PickupAction
{
    // Hands empty or holding something other than food: pick the platter up.
    PickUp,
    // Holding a food item: place it on the platter.
    Deposit,
    // Holding a food item, and the platter is full.
    Blocked_Full
}

// A World-mode, Persistent world item whose definition carries UMars_ItemTrait_Platter: the base WorldItem composition,
// then the Platter kernel on the same entity (its root is what the pile rides). Its pickup does two things
// (UMars_SmState_Platter_Interact): a focuser holding a food item places it on the platter, anyone else picks the platter
// up. The prompt follows the focuser: refreshed when the pickup is focused and whenever the focuser's hotbar changes a
// slot or its selection, never per frame. The small and the large platter items share this script.
class UMars_Platter_EntityScript : UMars_WorldItem_EntityScript
{
    // A placed platter resolves its item from here; a spawn sets it anyway.
    default Definition = mars_items::Platter();

    private FCk_Handle_Platter _Platter;

    // The focuser's hotbar the prompt follows; valid while the pickup is focused by an entity with a hotbar.
    private FCk_Handle_Hotbar _PromptHotbar;

    // Unset until the first refresh of a focus: the target's enable state changes only with the action.
    private TOptional<EMars_Platter_PickupAction> _LastAction;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        const auto Flow = Super::DoConstruct(InHandle);

        // Super destroyed itself (bad definition / no attach transform) - nothing to compose on.
        auto WorldItem = InHandle.As_WorldItem(ECk_SanityCheck::UnChecked);
        if (Flow != ECk_EntityScript_ConstructionFlow::Finished || ck::Is_NOT_Valid(WorldItem))
        { return Flow; }

        const auto IsWorld = Mode == EMars_WorldItem_Mode::World;
        const auto IsPersistent = WorldItem.Get_Persistence() == EMars_WorldItem_Persistence::Persistent;
        const UCk_InventoryItem_Definition ItemDefinition = Definition.Get();
        const UMars_ItemTrait_Platter PlatterTrait = ItemDefinition.Get_ItemTraitByClass(UMars_ItemTrait_Platter);

        const auto HasPlatterTrait = ck::IsValid(PlatterTrait);
        const auto IsPlatter = IsWorld && IsPersistent && HasPlatterTrait;
        if (ck::EnsureIfNot(IsPlatter,
            f"[Platter] [{InHandle.ToString()}] needs World mode and a Persistent definition with a Platter trait (mode [{Mode :n}], persistent [{IsPersistent}], platter trait [{HasPlatterTrait}])"))
        {
            utils_entity_lifetime::Request_DestroyEntity(InHandle);
            return ECk_EntityScript_ConstructionFlow::Finished;
        }

        // A rejected spec already ensured in utils_platter::Add.
        _Platter = utils_platter::Add(InHandle, PlatterTrait.Platter);
        if (ck::Is_NOT_Valid(_Platter))
        {
            utils_entity_lifetime::Request_DestroyEntity(InHandle);
            return ECk_EntityScript_ConstructionFlow::Finished;
        }

        auto Pickup = Get_Pickup();
        Pickup.BindTo_OnFocused(FMars_Delegate_Interactable_OnFocused(this, n"OnPlatterFocused"));
        Pickup.BindTo_OnUnfocused(FMars_Delegate_Interactable_OnUnfocused(this, n"OnPlatterUnfocused"));

        return ECk_EntityScript_ConstructionFlow::Finished;
    }

    UFUNCTION(BlueprintOverride)
    void DoEndPlay(FCk_Handle InHandle)
    {
        Super::DoEndPlay(InHandle);
        Stop_FollowingFocuser();
    }

    protected TSoftClassPtr<UCk_SmState_EntityScript> Get_PickupStateClass() const override
    {
        TSoftClassPtr<UCk_SmState_EntityScript> StateClass = UMars_SmState_Platter_Interact;
        return StateClass;
    }

    // A focuser holding a food item may have nowhere to stow the platter (food in the overflow slot) but can still place
    // the food.
    protected bool DoGet_CanStowSelf(FCk_Handle_Hotbar InHotbar) override
    {
        return Super::DoGet_CanStowSelf(InHotbar) || ck::IsValid(InHotbar.TryGet_SelectedFood());
    }

    UFUNCTION()
    private void OnPlatterFocused(FCk_Handle_Interactable InInteractable, FCk_Handle InFocusedBy)
    {
        Stop_FollowingFocuser();

        _PromptHotbar = InFocusedBy.As_Hotbar(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(_PromptHotbar))
        {
            _PromptHotbar.BindTo_OnSlotItemChanged(FMars_Delegate_Hotbar_OnSlotItemChanged(this, n"OnFocuserSlotItemChanged"));
            _PromptHotbar.BindTo_OnSelectionChanged(FMars_Delegate_Hotbar_OnSelectionChanged(this, n"OnFocuserSelectionChanged"));
        }

        Refresh_Prompt();
    }

    UFUNCTION()
    private void OnPlatterUnfocused(FCk_Handle_Interactable InInteractable, FCk_Handle InUnfocusedBy)
    {
        Stop_FollowingFocuser();
    }

    UFUNCTION()
    private void OnFocuserSlotItemChanged(FCk_Handle_Hotbar InHotbar, int32 InIndex, FCk_Handle_Item InMaybeItem)
    {
        Refresh_Prompt();
    }

    UFUNCTION()
    private void OnFocuserSelectionChanged(FCk_Handle_Hotbar InHotbar)
    {
        Refresh_Prompt();
    }

    private void Stop_FollowingFocuser()
    {
        if (ck::IsValid(_PromptHotbar))
        {
            _PromptHotbar.UnbindFrom_OnSlotItemChanged(FMars_Delegate_Hotbar_OnSlotItemChanged(this, n"OnFocuserSlotItemChanged"));
            _PromptHotbar.UnbindFrom_OnSelectionChanged(FMars_Delegate_Hotbar_OnSelectionChanged(this, n"OnFocuserSelectionChanged"));
        }

        _PromptHotbar = FCk_Handle_Hotbar();
        _LastAction.Reset();
    }

    // The prompt's text and colour every refresh; the target is enabled for PickUp / Deposit and disabled for a blocked
    // action, only when the action changes (utils_interact_target::Set_Enabled cancels the target's interactions).
    private void Refresh_Prompt()
    {
        auto Pickup = Get_Pickup();
        if (ck::Is_NOT_Valid(Pickup) || ck::Is_NOT_Valid(_Platter))
        { return; }

        const auto Food = ck::IsValid(_PromptHotbar) ? _PromptHotbar.TryGet_SelectedFood() : FCk_Handle_Item();
        auto Action = EMars_Platter_PickupAction::PickUp;
        auto Text = FText::FromString(f"Pick up {Get_ItemName()}");
        if (ck::IsValid(Food))
        {
            Action = _Platter.Get_IsFull() ? EMars_Platter_PickupAction::Blocked_Full : EMars_Platter_PickupAction::Deposit;
            Text = Action == EMars_Platter_PickupAction::Blocked_Full
                ? FText::FromString("Platter full")
                : FText::FromString(f"Place {Food.Get_Definition().Get_CoreInfo().Get_Name().ToString()} on platter");
        }

        const auto IsBlocked = Action == EMars_Platter_PickupAction::Blocked_Full;
        const auto Color = IsBlocked ? constants_ui_colors::k_PromptText_Blocked : constants_ui_colors::k_PromptText;
        const auto ActionChanged = _LastAction.IsSet() == false || _LastAction.GetValue() != Action;
        _LastAction = TOptional<EMars_Platter_PickupAction>(Action);

        auto Target = Pickup.Get_InteractTarget(GameplayTags::InteractionChannel_Mars_Use);
        auto Prompt = Target.As_InteractPrompt();
        Prompt.Request_UpdateText(FMars_Request_InteractPrompt_UpdateText(Text, Color));

        if (ActionChanged)
        { utils_interact_target::Set_Enabled(Target, IsBlocked ? ECk_EnableDisable::Disable : ECk_EnableDisable::Enable); }
    }
}

// A placed large platter (the sandbox's): a placed entity resolves its definition from a class default.
class UMars_Platter_Large_EntityScript : UMars_Platter_EntityScript
{
    default Definition = mars_items::Platter_Large();
}
