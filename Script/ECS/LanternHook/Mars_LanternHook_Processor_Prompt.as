// Keeps a focused hook's prompt and interact target in step with what its focuser could do (Get_ActionFor). Polls, as
// UMars_Processor_KeyLock_Prompt does: a focused hook depends on the focuser's held item AND the hook's content.
//
// While focused, the prompt text/colour follow the action every pass, and on an action change the framework target is
// enabled for Hang / Take / Refuel and disabled otherwise (the prompt stays visible with the reason and E does nothing).
// Not focused: LastPromptAction resets so the next focus re-evaluates.
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

        if (Interactable.Get_IsFocused() == false)
        {
            InState.LastPromptAction.Reset();
            return;
        }

        const auto Hook = InHandle.As_LanternHook();
        const auto Focuser = Interactable.Get_CurrentFocuser();
        const auto Action = Hook.Get_ActionFor(Focuser);
        const auto IsAction = Action == EMars_LanternHook_Action::Hang || Action == EMars_LanternHook_Action::Take
            || Action == EMars_LanternHook_Action::Refuel;

        const auto Text = utils_lantern_hook::Get_PromptText(Action, DoGet_ItemName(Hook, Focuser, Action));
        const auto Color = IsAction ? constants_ui_colors::k_PromptText : constants_ui_colors::k_PromptText_Blocked;

        const auto ActionChanged = InState.LastPromptAction.IsSet() == false || InState.LastPromptAction.GetValue() != Action;
        InState.LastPromptAction = TOptional<EMars_LanternHook_Action>(Action);

        auto Targets = Interactable.Get_AllInteractTargets();
        for (auto& Target : Targets)
        {
            auto Prompt = Target.As_InteractPrompt();
            Prompt.Request_UpdateText(FMars_Request_InteractPrompt_UpdateText(Text, Color));

            if (ActionChanged)
            { utils_interact_target::Set_Enabled(Target, IsAction ? ECk_EnableDisable::Enable : ECk_EnableDisable::Disable); }
        }
    }

    // The held lantern's name for Hang, the hung lantern's name otherwise; empty when neither exists.
    private FText DoGet_ItemName(const FCk_Handle_LanternHook& InHook, const FCk_Handle& InFocuser, EMars_LanternHook_Action InAction) const
    {
        auto Item = InHook.Get_Item();
        if (InAction == EMars_LanternHook_Action::Hang)
        { Item = InFocuser.As_HeldItem().Get_CurrentItem(); }

        if (ck::Is_NOT_Valid(Item))
        { return FText(); }

        const auto Definition = Item.Get_Definition();
        if (ck::Is_NOT_Valid(Definition))
        { return FText(); }

        return Definition.Get_CoreInfo().Get_Name();
    }
}
