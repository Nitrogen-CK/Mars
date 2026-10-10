// Keeps a focused dock's prompt and interact target in step with what its focuser could do (Get_ActionFor). Polls: a
// focused dock depends on the focuser's hands AND the dock content, and at most a handful of docks are focused.
//
// While focused, the prompt text/colour follow the action every pass, and on an action change the framework target is
// enabled for Place / Take / PlaceFood and disabled otherwise (utils_interact_target::Set_Enabled cancels the target's interactions;
// the prompt stays visible with the reason and E does nothing). Not focused: LastPromptAction resets so the next focus
// re-evaluates.
class UMars_Processor_PlatterDock_Prompt : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_PlatterDock);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_Fragment_PlatterDock& InState)
    {
        auto Interactable = InState.Interactable;
        if (ck::EnsureIfNot(ck::IsValid(Interactable), f"[PlatterDock] [{InHandle.ToString()}] has no interactable"))
        { return; }

        if (Interactable.Get_IsFocused() == false)
        {
            InState.LastPromptAction.Reset();
            return;
        }

        const auto Dock = InHandle.As_PlatterDock();
        const auto Focuser = Interactable.Get_CurrentFocuser();
        const auto Action = Dock.Get_ActionFor(Focuser);
        const auto IsAction = Action == EMars_PlatterDock_Action::Place || Action == EMars_PlatterDock_Action::Take
            || Action == EMars_PlatterDock_Action::PlaceFood;

        auto Query = FMars_PlatterDock_PromptQuery();
        Query.Action = Action;
        if (Action == EMars_PlatterDock_Action::Blocked_Policy)
        { Query.Refusal = Dock.TryGet_Refusal(Focuser); }

        if (Action == EMars_PlatterDock_Action::PlaceFood)
        { Query.FoodName = Focuser.As_Hotbar().TryGet_SelectedFood().Get_Definition().Get_CoreInfo().Get_Name(); }

        const auto Text = utils_platter_dock::Get_PromptText(Dock.Get_Spec(), Query);
        const auto Color = IsAction ? constants_ui_colors::k_PromptText : constants_ui_colors::k_PromptText_Blocked;

        const auto ActionChanged = InState.LastPromptAction.IsSet() == false || InState.LastPromptAction.GetValue() != Action;
        InState.LastPromptAction = TOptional<EMars_PlatterDock_Action>(Action);

        auto Targets = Interactable.Get_AllInteractTargets();
        for (auto& Target : Targets)
        {
            auto Prompt = Target.As_InteractPrompt();
            Prompt.Request_UpdateText(FMars_Request_InteractPrompt_UpdateText(Text, Color));

            if (ActionChanged)
            { utils_interact_target::Set_Enabled(Target, IsAction ? ECk_EnableDisable::Enable : ECk_EnableDisable::Disable); }
        }
    }
}
