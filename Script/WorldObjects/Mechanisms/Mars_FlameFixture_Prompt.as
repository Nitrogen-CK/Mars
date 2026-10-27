// A flame fixture's prompt: its words for each EMars_Flame_Action and the pass that keeps a focused fixture's ignite row in
// step with what its focuser holds (Get_ActionFor).

namespace utils_flame_fixture
{
    // InFixtureName names the fixture (Light, None); InHeldName the focuser's held item (TakeLight, Blocked_Spent).
    FText Get_PromptText(EMars_Flame_Action InAction, FText InFixtureName, FText InHeldName)
    {
        const auto Fixture = InFixtureName.ToString();
        const auto Held = InHeldName.ToString();
        if (InAction == EMars_Flame_Action::Light)
        { return FText::FromString(f"Light {Fixture}"); }

        if (InAction == EMars_Flame_Action::TakeLight)
        { return FText::FromString(f"Light {Held}"); }

        if (InAction == EMars_Flame_Action::Blocked_NeedsAFlame)
        { return FText::FromString("Needs a flame"); }

        if (InAction == EMars_Flame_Action::Blocked_Enclosed)
        { return FText::FromString("Needs an open flame"); }

        if (InAction == EMars_Flame_Action::Blocked_Spent)
        { return FText::FromString(f"{Held} is burnt out"); }

        return InFixtureName;
    }
}

// The fixture's name for its prompt, added by its assembly: the prompt's own text is rewritten while focused, so it cannot
// keep the name.
struct FMars_Fragment_FlameFixture_Name
{
    UPROPERTY()
    FText Name;
}

// The action the fixture's prompt last showed; unset while the fixture is not focused.
struct FMars_Fragment_FlameFixture_PromptShown
{
    UPROPERTY()
    TOptional<EMars_Flame_Action> Action;
}

// Polls, as UMars_Processor_LanternHook_Prompt does: a focused fixture depends on the focuser's held flame AND its own.
// Not focused: the shown action resets so the next focus re-evaluates. Only Light and TakeLight enable the row. Runs only
// on fixtures: the name fragment it reads is a fixture's.
class UMars_Processor_FlameFixture_Prompt : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Flame);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_Fragment_FlameFixture_Name& InName)
    {
        const auto Flame = InHandle.As_Flame();
        auto Interactable = Flame.Get_Interactable();
        if (ck::Is_NOT_Valid(Interactable))
        { return; }

        auto& Shown = InHandle.AddOrGet_Fragment(FMars_Fragment_FlameFixture_PromptShown);
        if (Interactable.Get_IsFocused() == false)
        {
            Shown.Action.Reset();
            return;
        }

        const auto Focuser = Interactable.Get_CurrentFocuser();
        const auto Action = Flame.Get_ActionFor(Focuser);

        auto HeldName = FText();
        const auto HeldItem = Focuser.As_HeldItem(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(HeldItem))
        { HeldName = HeldItem.Get_CurrentItem().Get_DisplayName(); }

        auto Update = FMars_InteractPrompt_ActionUpdate();
        Update.Interactable = Interactable;
        Update.Text = utils_flame_fixture::Get_PromptText(Action, InName.Name, HeldName);
        Update.Action = Action == EMars_Flame_Action::Light || Action == EMars_Flame_Action::TakeLight
            ? ECk_EnableDisable::Enable
            : ECk_EnableDisable::Disable;
        Update.ActionChanged = Shown.Action.IsSet() == false || Shown.Action.GetValue() != Action;

        Shown.Action = TOptional<EMars_Flame_Action>(Action);

        utils_interact_prompt::Apply_Action(Update);
    }
}
