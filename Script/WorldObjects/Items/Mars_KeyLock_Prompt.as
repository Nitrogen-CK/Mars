// A lock's prompt: its words for each EMars_KeyLock_Action and the pass that keeps a focused lock's prompt and interact
// target in step with what its focuser could do (Get_ActionFor).

namespace utils_key_lock
{
    // The lock's one interact target with the keyhole's placeholder prompt.
    FMars_Interactable_TargetEntry Make_InteractTarget()
    {
        return Make_InteractTarget(FMars_InteractPrompt_Spec(mars::Mars_IA_Interact_Use, FText::FromString("Keyhole")));
    }

    // "Red" for Key.Mars.Red: the tag's last segment.
    FString Get_KeyName(FGameplayTag InKeyId)
    {
        const auto TagName = InKeyId.ToString();
        FString Head;
        FString Leaf;
        if (TagName.Split(".", Head, Leaf, ESearchCase::IgnoreCase, ESearchDir::FromEnd))
        { return Leaf; }

        return TagName;
    }

    // InItemName is the held key for Insert and the inserted key for Take; InAcceptedKey names the key a Blocked_ lock
    // asks for. Blocked_HandsFull has no words here: the prompt is blocked HandsFull and the prompt widget words it.
    FText Get_PromptText(EMars_KeyLock_Action InAction, FText InItemName, FGameplayTag InAcceptedKey)
    {
        if (InAction == EMars_KeyLock_Action::Insert)
        { return FText::FromString(f"Insert {InItemName.ToString()}"); }

        if (InAction == EMars_KeyLock_Action::Take)
        { return FText::FromString(f"Take {InItemName.ToString()}"); }

        if (InAction == EMars_KeyLock_Action::Blocked_NothingHeld || InAction == EMars_KeyLock_Action::Blocked_WrongKey)
        { return FText::FromString(f"Needs {Get_KeyName(InAcceptedKey)} key"); }

        if (InAction == EMars_KeyLock_Action::Blocked_KeyKept)
        { return FText::FromString("Unlocked"); }

        if (InAction == EMars_KeyLock_Action::Blocked_NoRoom)
        { return FText::FromString("No room"); }

        return FText();
    }
}

// The action the lock's prompt last showed; unset while the lock is not focused.
struct FMars_Fragment_KeyLock_PromptShown
{
    UPROPERTY()
    TOptional<EMars_KeyLock_Action> Action;
}

// Polls, as UMars_Processor_CargoSlot_Prompt does: a focused lock depends on the focuser's held item AND the lock's
// content. Not focused: the shown action resets so the next focus re-evaluates.
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

        auto& Shown = InHandle.AddOrGet_Fragment(FMars_Fragment_KeyLock_PromptShown);
        if (Interactable.Get_IsFocused() == false)
        {
            Shown.Action.Reset();
            return;
        }

        const auto Lock = InHandle.As_KeyLock();
        const auto Focuser = Interactable.Get_CurrentFocuser();
        const auto Action = Lock.Get_ActionFor(Focuser);
        const auto IsAction = Action == EMars_KeyLock_Action::Insert || Action == EMars_KeyLock_Action::Take;

        auto Item = FCk_Handle_Item();
        if (Action == EMars_KeyLock_Action::Take)
        { Item = Lock.Get_Key(); }
        else if (Action == EMars_KeyLock_Action::Insert)
        { Item = Focuser.As_HeldItem().Get_CurrentItem(); }

        auto Update = FMars_InteractPrompt_ActionUpdate();
        Update.Interactable = Interactable;
        Update.Text = utils_key_lock::Get_PromptText(Action, Item.Get_DisplayName(), Lock.Get_AcceptedKey());
        Update.Action = IsAction ? ECk_EnableDisable::Enable : ECk_EnableDisable::Disable;
        Update.ActionChanged = Shown.Action.IsSet() == false || Shown.Action.GetValue() != Action;
        if (Action == EMars_KeyLock_Action::Blocked_HandsFull)
        { Update.Blocked = EMars_InteractPrompt_BlockedReason::HandsFull; }

        Shown.Action = TOptional<EMars_KeyLock_Action>(Action);

        utils_interact_prompt::Apply_Action(Update);
    }
}
