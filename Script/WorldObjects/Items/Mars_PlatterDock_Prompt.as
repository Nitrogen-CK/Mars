// A platter dock's prompt and reach hint: the words its station gives it (what the dock is called, why its Kind query
// refuses), the pass that keeps a focused dock's prompt and interact target in step with what its focuser could do
// (Get_ActionFor), and the gloves' hint for taking the docked tray.

// What the dock's prompt calls the dock and says when its Kind query refuses a piece; the other refusals have fixed texts.
struct FMars_PlatterDock_PromptWords
{
    // "input platter", "finished tray".
    UPROPERTY()
    FText Name;

    // "Meat only"; empty: "Not this food".
    UPROPERTY()
    FText KindRejectedText;

    FMars_PlatterDock_PromptWords() {}

    FMars_PlatterDock_PromptWords(FText InName, FText InKindRejectedText)
    {
        Name = InName;
        KindRejectedText = InKindRejectedText;
    }
}

// What a dock's prompt says to one focuser (utils_platter_dock::Get_PromptText).
struct FMars_PlatterDock_PromptQuery
{
    EMars_PlatterDock_Action Action = EMars_PlatterDock_Action::Blocked_NothingHeld;

    // Blocked_Policy: the policy's reason.
    TOptional<EMars_PlatterDock_Refusal> Refusal;

    // PlaceFood: the held food's name.
    FText FoodName;
}

// The dock's words (utils_platter_dock::Add_Prompt) and the action its prompt last showed (unset while not focused).
struct FMars_Fragment_PlatterDock_Prompt
{
    UPROPERTY()
    FMars_PlatterDock_PromptWords Words;

    UPROPERTY()
    TOptional<EMars_PlatterDock_Action> Shown;
}

// The docked platter's world item the dock last hinted for the gloves; invalid while it hints nothing.
struct FMars_Fragment_PlatterDock_ReachHintSource
{
    UPROPERTY()
    FCk_Handle_WorldItem WorldItem;
}

namespace utils_platter_dock
{
    // The Use prompt every dock starts with; UMars_Processor_PlatterDock_Prompt rewrites it while focused.
    FMars_InteractPrompt_Spec Make_PromptSpec()
    {
        return FMars_InteractPrompt_Spec(mars::Mars_IA_Interact_Use, FText::FromString("Dock"));
    }

    // Gives InDock its words; a dock without them keeps its placeholder prompt. A nameless dock ensures and gets none.
    void Add_Prompt(FCk_Handle_PlatterDock& InDock, const FMars_PlatterDock_PromptWords& InWords)
    {
        if (ck::EnsureIfNot(InWords.Name.IsEmpty() == false, f"[PlatterDock] [{InDock.ToString()}] has no Name for its prompt"))
        { return; }

        auto& Prompt = InDock.AddOrGet_Fragment(FMars_Fragment_PlatterDock_Prompt);
        Prompt.Words = InWords;
    }

    // The dock's Name for Place / Take, the food and the dock for PlaceFood; InQuery.Refusal is the policy's reason for
    // Blocked_Policy. Blocked_HandsFull has no words here: the prompt is blocked HandsFull and the prompt widget words it.
    FText Get_PromptText(const FMars_PlatterDock_PromptWords& InWords, const FMars_PlatterDock_PromptQuery& InQuery)
    {
        const auto Name = InWords.Name.ToString();
        const auto Action = InQuery.Action;

        if (Action == EMars_PlatterDock_Action::Place)
        { return FText::FromString(f"Place on {Name}"); }

        if (Action == EMars_PlatterDock_Action::PlaceFood)
        { return FText::FromString(f"Place {InQuery.FoodName.ToString()} on {Name}"); }

        if (Action == EMars_PlatterDock_Action::Take)
        { return FText::FromString(f"Take {Name}"); }

        if (Action == EMars_PlatterDock_Action::Blocked_NothingHeld)
        { return FText::FromString("Nothing to place"); }

        if (Action == EMars_PlatterDock_Action::Blocked_NotAPlatter)
        { return FText::FromString("Not a platter"); }

        if (Action == EMars_PlatterDock_Action::Blocked_HandsFull)
        { return FText(); }

        return Get_RefusalText(InWords, InQuery.Refusal);
    }

    // The Blocked_Policy reason.
    FText Get_RefusalText(const FMars_PlatterDock_PromptWords& InWords, TOptional<EMars_PlatterDock_Refusal> InRefusal)
    {
        if (InRefusal == EMars_PlatterDock_Refusal::KindRejected)
        { return InWords.KindRejectedText.IsEmpty() ? FText::FromString("Not this food") : InWords.KindRejectedText; }

        if (InRefusal == EMars_PlatterDock_Refusal::NotWhole)
        { return FText::FromString("Whole pieces only"); }

        if (InRefusal == EMars_PlatterDock_Refusal::MustBeEmpty)
        { return FText::FromString("Must be empty"); }

        if (InRefusal == EMars_PlatterDock_Refusal::PlatterFull)
        { return FText::FromString("Platter full"); }

        return FText::FromString("Can't place that");
    }
}

// The words Add_Prompt gave the dock; empty words for a dock that has none.
mixin FMars_PlatterDock_PromptWords Get_PromptWords(const FCk_Handle_PlatterDock& Self)
{
    if (Self.Has_Fragment(FMars_Fragment_PlatterDock_Prompt) == false)
    { return FMars_PlatterDock_PromptWords(); }

    return Self.Get_Fragment(FMars_Fragment_PlatterDock_Prompt).Words;
}

// Every dock: the gloves' reach hint follows the docked tray (Sync_ReachHint). A dock with words (Add_Prompt) also keeps its
// prompt in step; it polls: a focused dock depends on the focuser's hands AND the dock content, and at most a handful of
// docks are focused. Not focused: the shown action resets so the next focus re-evaluates. Follows the dock's sync, which
// records the docked world item.
class UMars_Processor_PlatterDock_Prompt : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _RunAfter.Add(n"/Script/Angelscript.Mars_Processor_PlatterDock_Sync");

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

        Sync_ReachHint(InHandle, InState);

        if (InHandle.Has_Fragment(FMars_Fragment_PlatterDock_Prompt) == false)
        { return; }

        auto& Prompt = InHandle.Get_Fragment(FMars_Fragment_PlatterDock_Prompt);
        if (Interactable.Get_IsFocused() == false)
        {
            Prompt.Shown.Reset();
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
        { Query.FoodName = Focuser.As_Hotbar().TryGet_SelectedFood().Get_DisplayName(); }

        auto Update = FMars_InteractPrompt_ActionUpdate();
        Update.Interactable = Interactable;
        Update.Text = utils_platter_dock::Get_PromptText(Prompt.Words, Query);
        Update.Action = IsAction ? ECk_EnableDisable::Enable : ECk_EnableDisable::Disable;
        Update.ActionChanged = Prompt.Shown.IsSet() == false || Prompt.Shown.GetValue() != Action;
        if (Action == EMars_PlatterDock_Action::Blocked_HandsFull)
        { Update.Blocked = EMars_InteractPrompt_BlockedReason::HandsFull; }

        Prompt.Shown = TOptional<EMars_PlatterDock_Action>(Action);

        utils_interact_prompt::Apply_Action(Update);
    }

    // A docked platter is what a Take reaches for: the dock (the interactable's owner) hints the platter's own fit and
    // handedness, so both gloves take the tray. The platter's root sits on the dock's node, so its fit holds in the dock's
    // frame as is. An empty dock hints nothing (its Place is a Place reach at a spot). Written only when the hinted tray
    // changes.
    private void Sync_ReachHint(FCk_Handle& InHandle, const FMars_Fragment_PlatterDock& InState)
    {
        const FCk_Handle WorldItemEntity = ck::IsValid(InState.Platter) ? InState.WorldItem : FCk_Handle_WorldItem();
        const auto HasHint = ck::IsValid(WorldItemEntity) && WorldItemEntity.Has_ReachHint();
        const auto Hinted = HasHint ? InState.WorldItem : FCk_Handle_WorldItem();

        auto& Source = InHandle.AddOrGet_Fragment(FMars_Fragment_PlatterDock_ReachHintSource);
        if (Source.WorldItem == Hinted)
        { return; }

        Source.WorldItem = Hinted;
        if (ck::IsValid(Hinted))
        {
            utils_reach_hint::Set(InHandle, WorldItemEntity.Get_ReachHint());
            return;
        }

        utils_reach_hint::Remove(InHandle);
    }
}
