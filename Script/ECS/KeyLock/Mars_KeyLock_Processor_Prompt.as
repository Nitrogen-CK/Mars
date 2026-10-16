// Keeps a focused lock's prompt and interact target in step with what its focuser could do (Get_ActionFor). Polls, as
// UMars_Processor_CargoSlot_Prompt does: a focused lock depends on the focuser's held item AND the lock's content.
//
// While focused, the prompt text/colour follow the action every pass, and on an action change the framework target is
// enabled for Insert / Take and disabled otherwise (the prompt stays visible with the reason and E does nothing). Not
// focused: LastPromptAction resets so the next focus re-evaluates.
class UMars_Processor_KeyLock_Prompt : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_KeyLock);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_Fragment_KeyLock& InState)
    {
        auto Interactable = InState.Interactable;
        if (ck::EnsureIfNot(ck::IsValid(Interactable), f"[KeyLock] [{InHandle.ToString()}] has no interactable"))
        { return; }

        if (Interactable.Get_IsFocused() == false)
        {
            InState.LastPromptAction.Reset();
            return;
        }

        const auto Lock = InHandle.As_KeyLock();
        const auto Focuser = Interactable.Get_CurrentFocuser();
        const auto Action = Lock.Get_ActionFor(Focuser);
        const auto IsAction = Action == EMars_KeyLock_Action::Insert || Action == EMars_KeyLock_Action::Take;

        const auto Text = utils_key_lock::Get_PromptText(Action, DoGet_ItemName(Lock, Focuser, Action), Lock.Get_AcceptedKey());
        const auto Color = IsAction ? constants_ui_colors::k_PromptText : constants_ui_colors::k_PromptText_Blocked;

        const auto ActionChanged = InState.LastPromptAction.IsSet() == false || InState.LastPromptAction.GetValue() != Action;
        InState.LastPromptAction = TOptional<EMars_KeyLock_Action>(Action);

        auto Targets = Interactable.Get_AllInteractTargets();
        for (auto& Target : Targets)
        {
            auto Prompt = Target.As_InteractPrompt();
            Prompt.Request_UpdateText(FMars_Request_InteractPrompt_UpdateText(Text, Color));

            if (ActionChanged)
            { utils_interact_target::Set_Enabled(Target, IsAction ? ECk_EnableDisable::Enable : ECk_EnableDisable::Disable); }
        }
    }

    // The held key's name for Insert, the inserted key's name for Take; empty otherwise.
    private FText DoGet_ItemName(const FCk_Handle_KeyLock& InLock, const FCk_Handle& InFocuser, EMars_KeyLock_Action InAction) const
    {
        auto Item = FCk_Handle_Item();
        if (InAction == EMars_KeyLock_Action::Take)
        { Item = InLock.Get_Key(); }
        else if (InAction == EMars_KeyLock_Action::Insert)
        { Item = InFocuser.As_HeldItem().Get_CurrentItem(); }

        if (ck::Is_NOT_Valid(Item))
        { return FText(); }

        const auto Definition = Item.Get_Definition();
        if (ck::Is_NOT_Valid(Definition))
        { return FText(); }

        return Definition.Get_CoreInfo().Get_Name();
    }
}
