// The prompt pass shared by the slot-like interactables whose kernels rule what a focuser could do (a cargo slot, a lock,
// a lantern hook, a platter dock): each prompt processor words its kernel's action and hands it here.

// One pass of a focused interactable's prompt. ActionChanged is set on the first pass of a new action (and on every new
// focus): only then are the targets enabled or disabled and the blocked reason written, so a pass that keeps its action
// never re-enables a target something else disabled.
struct FMars_InteractPrompt_ActionUpdate
{
    FCk_Handle_Interactable Interactable;

    FText Text;

    // Enable: the focuser can act and E does it. Disable: the prompt stays visible with the refusal and E does nothing
    // (utils_interact_target::Set_Enabled cancels the target's interactions).
    ECk_EnableDisable Action = ECk_EnableDisable::Disable;

    // A refusal the prompt widget words itself (Text is then not shown); None for every other refusal and every action.
    EMars_InteractPrompt_BlockedReason Blocked = EMars_InteractPrompt_BlockedReason::None;

    bool ActionChanged = false;
}

namespace utils_interact_prompt
{
    void Apply_Action(const FMars_InteractPrompt_ActionUpdate& InUpdate)
    {
        const auto Color = InUpdate.Action == ECk_EnableDisable::Enable
            ? constants_ui_colors::k_PromptText
            : constants_ui_colors::k_PromptText_Blocked;

        auto Interactable = InUpdate.Interactable;
        auto Targets = Interactable.Get_AllInteractTargets();
        for (auto& Target : Targets)
        {
            auto Prompt = Target.As_InteractPrompt();
            Prompt.Request_UpdateText(FMars_Request_InteractPrompt_UpdateText(InUpdate.Text, Color));

            if (InUpdate.ActionChanged == false)
            { continue; }

            Prompt.Request_SetBlocked(FMars_Request_InteractPrompt_SetBlocked(InUpdate.Blocked));
            utils_interact_target::Set_Enabled(Target, InUpdate.Action);
        }
    }
}

// The item's definition name; empty for an invalid item or an unresolved definition.
mixin FText Get_DisplayName(const FCk_Handle_Item& Self)
{
    if (ck::Is_NOT_Valid(Self))
    { return FText(); }

    const auto Definition = Self.Get_Definition();
    if (ck::Is_NOT_Valid(Definition))
    { return FText(); }

    return Definition.Get_CoreInfo().Get_Name();
}
