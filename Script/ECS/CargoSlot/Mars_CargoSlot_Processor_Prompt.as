// Keeps a focused slot's prompt and interact target in step with what its focuser could do (Get_ActionFor). Polls: a
// focused slot depends on the focuser's held item AND the slot content, and at most a handful of slots are focused.
//
// While focused: the prompt text/colour follow the action every pass (Request_UpdateText drops an unchanged text, so
// only a change is queued), and on an action change the framework target is enabled for Stow / Take and disabled
// otherwise (utils_interact_target::Set_Enabled: immediate, cancels the target's interactions, and the resolver then
// filters the target - the prompt stays visible with the reason and E does nothing). Not focused: LastPromptAction
// resets to Unset so the next focus re-evaluates; nothing else is written.
class UMars_Processor_CargoSlot_Prompt : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_CargoSlot);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_Fragment_CargoSlot& InState)
    {
        auto Interactable = InState.Interactable;
        if (ck::Is_NOT_Valid(Interactable) || Interactable.Get_IsFocused() == false)
        {
            InState.LastPromptAction = EMars_CargoSlot_Action::Unset;
            return;
        }

        const auto Slot = InHandle.As_CargoSlot();
        const auto Focuser = Interactable.Get_CurrentFocuser();
        const auto Action = Slot.Get_ActionFor(Focuser);
        const auto IsAction = Action == EMars_CargoSlot_Action::Stow || Action == EMars_CargoSlot_Action::Take;

        const auto Text = constants_cargo_slot::k_PromptTextFor(Action, DoGet_ItemName(Slot, Focuser, Action));
        const auto Color = IsAction ? constants_cargo_slot::k_ActionColor : constants_cargo_slot::k_BlockedColor;

        const auto ActionChanged = Action != InState.LastPromptAction;
        InState.LastPromptAction = Action;

        auto Targets = Interactable.Get_AllInteractTargets();
        for (auto& Target : Targets)
        {
            auto Prompt = FCk_Handle(Target).As_InteractPrompt(ECk_SanityCheck::UnChecked);
            if (ck::IsValid(Prompt))
            { Prompt.Request_UpdateText(FMars_Request_InteractPrompt_UpdateText(Text, Color)); }

            if (ActionChanged)
            { utils_interact_target::Set_Enabled(Target, IsAction ? ECk_EnableDisable::Enable : ECk_EnableDisable::Disable); }
        }
    }

    // The held item's name for Stow, the slot item's name for Take; empty otherwise.
    private FText DoGet_ItemName(const FCk_Handle_CargoSlot& InSlot, const FCk_Handle& InFocuser, EMars_CargoSlot_Action InAction) const
    {
        auto Item = FCk_Handle_Item();
        if (InAction == EMars_CargoSlot_Action::Take)
        { Item = InSlot.Get_Item(); }
        else if (InAction == EMars_CargoSlot_Action::Stow)
        {
            const auto HeldItem = InFocuser.As_HeldItem(ECk_SanityCheck::UnChecked);
            if (ck::IsValid(HeldItem))
            { Item = HeldItem.Get_CurrentItem(); }
        }

        if (ck::Is_NOT_Valid(Item))
        { return FText(); }

        const auto Definition = Item.Get_Definition();
        if (ck::Is_NOT_Valid(Definition))
        { return FText(); }

        return Definition.Get_CoreInfo().Get_Name();
    }
}
