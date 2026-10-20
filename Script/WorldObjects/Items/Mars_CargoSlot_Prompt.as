// A cargo slot's prompt: its words for each EMars_CargoSlot_Action and the pass that keeps a focused slot's prompt and
// interact target in step with what its focuser could do (Get_ActionFor).

namespace utils_cargo_slot
{
    // The Use prompt every cargo slot starts with; UMars_Processor_CargoSlot_Prompt rewrites it while focused.
    FMars_InteractPrompt_Spec Make_PromptSpec()
    {
        return FMars_InteractPrompt_Spec(mars::Mars_IA_Interact_Use, FText::FromString("Cargo"));
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
}

// The action the slot's prompt last showed; unset while the slot is not focused.
struct FMars_Fragment_CargoSlot_PromptShown
{
    UPROPERTY()
    TOptional<EMars_CargoSlot_Action> Action;
}

// Polls: a focused slot depends on the focuser's held item AND the slot content, and at most a handful of slots are
// focused. Not focused: the shown action resets so the next focus re-evaluates.
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
        if (ck::EnsureIfNot(ck::IsValid(Interactable), f"[CargoSlot] [{InHandle.ToString()}] has no interactable"))
        { return; }

        auto& Shown = InHandle.AddOrGet_Fragment(FMars_Fragment_CargoSlot_PromptShown);
        if (Interactable.Get_IsFocused() == false)
        {
            Shown.Action.Reset();
            return;
        }

        const auto Slot = InHandle.As_CargoSlot();
        const auto Focuser = Interactable.Get_CurrentFocuser();
        const auto Action = Slot.Get_ActionFor(Focuser);
        const auto IsAction = Action == EMars_CargoSlot_Action::Stow || Action == EMars_CargoSlot_Action::Take;

        auto Item = FCk_Handle_Item();
        if (Action == EMars_CargoSlot_Action::Take)
        { Item = Slot.Get_Item(); }
        else if (Action == EMars_CargoSlot_Action::Stow)
        { Item = Focuser.As_HeldItem().Get_CurrentItem(); }

        auto Update = FMars_InteractPrompt_ActionUpdate();
        Update.Interactable = Interactable;
        Update.Text = utils_cargo_slot::Get_PromptText(Action, Item.Get_DisplayName());
        Update.Action = IsAction ? ECk_EnableDisable::Enable : ECk_EnableDisable::Disable;
        Update.ActionChanged = Shown.Action.IsSet() == false || Shown.Action.GetValue() != Action;
        Shown.Action = TOptional<EMars_CargoSlot_Action>(Action);

        utils_interact_prompt::Apply_Action(Update);
    }
}
