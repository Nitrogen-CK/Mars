// A lantern hook's prompt: its words for each EMars_LanternHook_Action and the pass that keeps a focused hook's prompt and
// interact target in step with what its focuser could do (Get_ActionFor).

namespace utils_lantern_hook
{
    // The hook's one interact target with the hook's placeholder prompt.
    FMars_Interactable_TargetEntry Make_InteractTarget()
    {
        return Make_InteractTarget(FMars_InteractPrompt_Spec(mars::Mars_IA_Interact_Use, FText::FromString("Lantern hook")));
    }

    // InItemName is the held lantern for Hang, the hung one for Take, Refuel and Blocked_Full. Blocked_HandsFull has no
    // words here: the prompt is blocked HandsFull and the prompt widget words it.
    FText Get_PromptText(EMars_LanternHook_Action InAction, FText InItemName)
    {
        const auto Name = InItemName.ToString();
        if (InAction == EMars_LanternHook_Action::Hang)
        { return FText::FromString(f"Hang {Name}"); }

        if (InAction == EMars_LanternHook_Action::Take)
        { return FText::FromString(f"Take {Name}"); }

        if (InAction == EMars_LanternHook_Action::Refuel)
        { return FText::FromString(f"Refuel {Name}"); }

        if (InAction == EMars_LanternHook_Action::Blocked_NotALantern)
        { return FText::FromString("Lanterns only"); }

        if (InAction == EMars_LanternHook_Action::Blocked_NoRoom)
        { return FText::FromString("No room"); }

        if (InAction == EMars_LanternHook_Action::Blocked_Full)
        { return FText::FromString(f"{Name} is full"); }

        if (InAction == EMars_LanternHook_Action::Blocked_HandsFull)
        { return FText(); }

        return FText::FromString("Lantern hook");
    }
}

// The action the hook's prompt last showed; unset while the hook is not focused.
struct FMars_Fragment_LanternHook_PromptShown
{
    UPROPERTY()
    TOptional<EMars_LanternHook_Action> Action;
}

// Polls, as UMars_Processor_KeyLock_Prompt does: a focused hook depends on the focuser's held item AND the hook's
// content. Not focused: the shown action resets so the next focus re-evaluates.
class UMars_Processor_LanternHook_Prompt : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_LanternHook);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_Fragment_LanternHook& InState)
    {
        auto Interactable = InState.Interactable;
        if (ck::EnsureIfNot(ck::IsValid(Interactable), f"[LanternHook] [{InHandle.ToString()}] has no interactable"))
        { return; }

        auto& Shown = InHandle.AddOrGet_Fragment(FMars_Fragment_LanternHook_PromptShown);
        if (Interactable.Get_IsFocused() == false)
        {
            Shown.Action.Reset();
            return;
        }

        const auto Hook = InHandle.As_LanternHook();
        const auto Focuser = Interactable.Get_CurrentFocuser();
        const auto Action = Hook.Get_ActionFor(Focuser);
        const auto IsAction = Action == EMars_LanternHook_Action::Hang || Action == EMars_LanternHook_Action::Take
            || Action == EMars_LanternHook_Action::Refuel;

        auto Item = Hook.Get_Item();
        if (Action == EMars_LanternHook_Action::Hang)
        { Item = Focuser.As_HeldItem().Get_CurrentItem(); }

        auto Update = FMars_InteractPrompt_ActionUpdate();
        Update.Interactable = Interactable;
        Update.Text = utils_lantern_hook::Get_PromptText(Action, Item.Get_DisplayName());
        Update.Action = IsAction ? ECk_EnableDisable::Enable : ECk_EnableDisable::Disable;
        Update.ActionChanged = Shown.Action.IsSet() == false || Shown.Action.GetValue() != Action;
        if (Action == EMars_LanternHook_Action::Blocked_HandsFull)
        { Update.Blocked = EMars_InteractPrompt_BlockedReason::HandsFull; }

        Shown.Action = TOptional<EMars_LanternHook_Action>(Action);

        utils_interact_prompt::Apply_Action(Update);
    }
}
